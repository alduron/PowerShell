Function Invoke-ScheduledTask{
    <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER ComputerName
    .PARAMETER ErrorLog
    .EXAMPLE
    .LINK
    .NOTES
    #>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
    [String]$Server,
    [String]$TaskName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
    [switch]$Wait
    )
    BEGIN{
    }
    PROCESS{
        #Create CIM Session
        try{
            $Session = New-CimSession $Server
        } catch {
            Write-ToConsole "Could not create new CIM Session" -ErrorMessage $_.Exception.Message -Type ERR
        }
        
        #Kick off scheduled task
        try{
            Write-ToConsole "Starting $TaskName on $Server" -Type INF
            Start-ScheduledTask -CimSession $Session -TaskName $TaskName -ErrorAction Stop
        } catch {
            Write-ToConsole "Could not start $TaskName" -ErrorMessage $_.Exception.Message -Type ERR
        }

        #Wait for task to complete
        if($Wait){
            Write-ToConsole "Waiting for task to complete..." -Type INF
            Start-Sleep -Seconds 3

            #Get results every 5 seconds
            try{
                While ((Get-ScheduledTask -CimSession $Session -TaskName $TaskName -ErrorAction Stop).State -ne "Ready"){
                    Start-Sleep 5
                }
            } catch {
                Write-ToConsole "Could not wait for task to complete" -ErrorMessage $_.Exception.Message -Type ERR
            }
            Write-ToConsole "$TaskName has completed" -Type INF
        }
    }
    END{
    }
}

Function Get-PendingReboot
{
<#
.SYNOPSIS
    Gets the pending reboot status on a local or remote computer.

.DESCRIPTION
    This function will query the registry on a local or remote computer and determine if the
    system is pending a reboot, from either Microsoft Patching or a Software Installation.
    For Windows 2008+ the function will query the CBS registry key as another factor in determining
    pending reboot state.  "PendingFileRenameOperations" and "Auto Update\RebootRequired" are observed
    as being consistant across Windows Server 2003 & 2008.
	
    CBServicing = Component Based Servicing (Windows 2008)
    WindowsUpdate = Windows Update / Auto Update (Windows 2003 / 2008)
    CCMClientSDK = SCCM 2012 Clients only (DetermineIfRebootPending method) otherwise $null value
    PendFileRename = PendingFileRenameOperations (Windows 2003 / 2008)

.PARAMETER ComputerName
    A single Computer or an array of computer names.  The default is localhost ($env:COMPUTERNAME).

.PARAMETER ErrorLog
    A single path to send error data to a log file.

.EXAMPLE
    PS C:\> Get-PendingReboot -ComputerName (Get-Content C:\ServerList.txt) | Format-Table -AutoSize
	
    Computer CBServicing WindowsUpdate CCMClientSDK PendFileRename PendFileRenVal RebootPending
    -------- ----------- ------------- ------------ -------------- -------------- -------------
    DC01           False         False                       False                        False
    DC02           False         False                       False                        False
    FS01           False         False                       False                        False

    This example will capture the contents of C:\ServerList.txt and query the pending reboot
    information from the systems contained in the file and display the output in a table. The
    null values are by design, since these systems do not have the SCCM 2012 client installed,
    nor was the PendingFileRenameOperations value populated.

.EXAMPLE
    PS C:\> Get-PendingReboot
	
    Computer       : WKS01
    CBServicing    : False
    WindowsUpdate  : True
    CCMClient      : False
    PendFileRename : False
    PendFileRenVal : 
    RebootPending  : True
	
    This example will query the local machine for pending reboot information.
	
.EXAMPLE
    PS C:\> $Servers = Get-Content C:\Servers.txt
    PS C:\> Get-PendingReboot -Computer $Servers | Export-Csv C:\PendingRebootReport.csv -NoTypeInformation
	
    This example will create a report that contains pending reboot information.

.LINK
    Component-Based Servicing:
    http://technet.microsoft.com/en-us/library/cc756291(v=WS.10).aspx
	
    PendingFileRename/Auto Update:
    http://support.microsoft.com/kb/2723674
    http://technet.microsoft.com/en-us/library/cc960241.aspx
    http://blogs.msdn.com/b/hansr/archive/2006/02/17/patchreboot.aspx

    SCCM 2012/CCM_ClientSDK:
    http://msdn.microsoft.com/en-us/library/jj902723.aspx

.NOTES

#>
    [CmdletBinding()]
    param(
    [Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias("CN","Computer")]
    [String[]]$ComputerName="$env:COMPUTERNAME",
    [String]$ErrorLog
    )
    
    Begin{
        # Adjusting ErrorActionPreference to stop on all errors, since using [Microsoft.Win32.RegistryKey]
        # does not have a native ErrorAction Parameter, this may need to be changed if used within another
        # function.
        $TempErrAct = $ErrorActionPreference
        $ErrorActionPreference = "Stop"
    }#End Begin Script Block
    Process{
        foreach ($Computer in $ComputerName){
            Try{
                # Setting pending values to false to cut down on the number of else statements
                $PendFileRename,$Pending,$SCCM = $false,$false,$false
                
                # Setting CBSRebootPend to null since not all versions of Windows has this value
                $CBSRebootPend = $null
                
                # Querying WMI for build version
                $WMI_OS = Get-WmiObject -Class Win32_OperatingSystem -Property BuildNumber, CSName -ComputerName $Computer
                
                # Making registry connection to the local/remote computer
                $RegCon = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]"LocalMachine",$Computer)
                
                # If Vista/2008 & Above query the CBS Reg Key
                If ($WMI_OS.BuildNumber -ge 6001){
                    $RegSubKeysCBS = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\").GetSubKeyNames()
                    $CBSRebootPend = $RegSubKeysCBS -contains "RebootPending"
                    	
                }#End If ($WMI_OS.BuildNumber -ge 6001)
                
                # Query WUAU from the registry
                $RegWUAU = $RegCon.OpenSubKey("SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\")
                $RegWUAURebootReq = $RegWUAU.GetSubKeyNames()
                $WUAURebootReq = $RegWUAURebootReq -contains "RebootRequired"
                
                # Query PendingFileRenameOperations from the registry
                $RegSubKeySM = $RegCon.OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\")
                $RegValuePFRO = $RegSubKeySM.GetValue("PendingFileRenameOperations",$null)
                
                # Closing registry connection
                $RegCon.Close()
                
                # If PendingFileRenameOperations has a value set $RegValuePFRO variable to $true
                If ($RegValuePFRO){
                    $PendFileRename = $true
                }#End If ($RegValuePFRO)
                
                # Determine SCCM 2012 Client Reboot Pending Status
                # To avoid nested 'if' statements and unneeded WMI calls to determine if the CCM_ClientUtilities class exist, setting EA = 0
                $CCMClientSDK = $null
                $CCMSplat = @{
                    NameSpace='ROOT\ccm\ClientSDK'
                    Class='CCM_ClientUtilities'
                    Name='DetermineIfRebootPending'
                    ComputerName=$Computer
                    ErrorAction='SilentlyContinue'
                }
                $CCMClientSDK = Invoke-WmiMethod @CCMSplat
                If($CCMClientSDK){
                    If($CCMClientSDK.ReturnValue -ne 0){
                        Write-ToConsole "DetermineIfRebootPending returned error code $($CCMClientSDK.ReturnValue)" -Type ERR
                              
                    }#End If ($CCMClientSDK -and $CCMClientSDK.ReturnValue -ne 0)
                
                    If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending){
                        $SCCM = $true
                
                    }#End If ($CCMClientSDK.IsHardRebootPending -or $CCMClientSDK.RebootPending)
                
                } Else {
                    $SCCM = $null
                }                        
                
                # If any of the variables are true, set $Pending variable to $true
                If ($CBSRebootPend -or $WUAURebootReq -or $SCCM -or $PendFileRename){
                    $Pending = $true
                }#End If ($CBS -or $WUAU -or $PendFileRename)
                
                # Creating Custom PSObject and Select-Object Splat
                $SelectSplat = @{
                    Property=('Computer','CBServicing','WindowsUpdate','CCMClientSDK','PendFileRename','PendFileRenVal','RebootPending')
                }
                New-Object -TypeName PSObject -Property @{
                    Computer=$WMI_OS.CSName
                    CBServicing=$CBSRebootPend
                    WindowsUpdate=$WUAURebootReq
                    CCMClientSDK=$SCCM
                    PendFileRename=$PendFileRename
                    PendFileRenVal=$RegValuePFRO
                    RebootPending=$Pending
                } | Select-Object @SelectSplat
                
            } Catch {
                Write-ToConsole "$Computer`: $_" -Type ERR
            
                # If $ErrorLog, log the file to a user specified location/path
                If ($ErrorLog){
                    Add-ToLog $ErrorLog "$Computer`,$_" -Type ERR -Console
                }#End If ($ErrorLog)
                
            }#End Catch
        
        }#End Foreach ($Computer in $ComputerName)

    }#End Process
	
    End
    {
        # Resetting ErrorActionPref
        $ErrorActionPreference = $TempErrAct
    }#End End
    
}#End Function

Function Remove-UserSessions{
    <#
    .SYNOPSIS
        A function to detect and remove sessions from a given list of server names
    .DESCRIPTION
        This function will run through the provided CSV of server names and parse QWINSTA for an ID of the provided username. It will remove any sessions it identifies by ID
    .EXAMPLE
        Remove-UserSessions -ServerList <$PathToCSV> -User <$LogonNameOfUser> -Verbose
    .PARAMETER ServerList
        This input must be a CSV. A1 must be "Name" and A2 down must be server names
    .PARAMETER User
        The AD logon name of the user to search for
    #>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False)]
    [String]$ServerList,
    [String]$User
    )
    BEGIN{
        #Import server list
        Write-ToConsole "Starting search for user sessions from CSV located at $ServerList" -Type INF
        $Servers = Import-Csv $ServerList
    }
    PROCESS{
        #Run through each server in list provided
        ForEach($Server in $Servers){
            Try{
                Write-ToConsole "Searching $($Server.Name)" -Type INF

                #Perform the search via QWINSTA and format the results into a parsable table
                $Session = (qwinsta /server:$($Server.Name) | foreach { (($_.trim() -replace “\s+”,”,”))}) | ConvertFrom-Csv | Where-Object {$_.Username -eq $User} | Select ID,Username

                #Detect session
                if($Session){
                    #Assign username to variable for reporting
                    $SessionUser = $Session.Username
                    Write-ToConsole "User located with session ID of $($Session.ID). Attempting removal" -Type INF
                    try{
                        #Perform the removal
                        rwinsta /server:$($Server.Name) $Session.ID
                    } Catch {
						Write-ToConsole "Could not remove $User from $($Server.Name)" -ErrorMessage $_.Exception.Message -Type INF
                        Write-ToConsole "The following session was not removed: $Session" -Type INF
                    }
                    Write-ToConsole "Session $($Session.ID) was removed with a username of $SessionUser" -Type INF
                } else {
                    Write-ToConsole "No user was detected on $($Server.Name)" -Type INF
                }
            } Catch {$
				Write-ToConsole "Could not connect to $($Server.Name)" -ErrorMessage $_.Exception.Message -Type INF
            }
        }
    }
    END{
        Write-ToConsole "All servers in the provided list have been checked" -Type INF
    }
}

Function New-SecureString{
    <#
    .SYNOPSIS
    .DESCRIPTION
    .PARAMETER ComputerName
    .PARAMETER ErrorLog
    .EXAMPLE
    .LINK
    .NOTES
    #>
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$false,ValueFromPipeline=$False)]
    [switch]$AsVariable,
    [switch]$AsOutput
    )
    BEGIN{
        #Warn for use
        Write-ToConsole "Ensure you're running this cmdlet from the machine the secure string will be used on" -Type WRN
    }
    PROCESS{
        #Read and convert string
        $EnterPass = Read-Host -AsSecureString -Prompt "Enter password to be converted into secure string"
        $String = ConvertFrom-SecureString $EnterPass
    }
    END{
        if($AsVariable){
            return $String
        } elseif ($AsOutput) {
            Write-Output $String
        } else {
            Write-ToConsole "Generated string: $String" -Type INF
        }
        
    }
}

Function Invoke-APICall{
    [CmdletBinding()]
    Param(
        [parameter(ParameterSetName="Default",Mandatory=$True)]
        [parameter(ParameterSetName="Explicite",Mandatory=$True)]
 	    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName = $False)]
 	    [String] $Command = "",
         [parameter(ParameterSetName="Default",Mandatory=$False)]
         [parameter(ParameterSetName="Explicite",Mandatory=$False)]
        [String] $Token = "",
        [parameter(ParameterSetName="Default",Mandatory=$False)]
        [String] $Username = "",
        [parameter(ParameterSetName="Default",Mandatory=$False)]
        [String] $Password = "",
        [parameter(ParameterSetName="Default",Mandatory=$False)]
        [parameter(ParameterSetName="Explicite",Mandatory=$False)]
        [Switch] $POST,
        [parameter(ParameterSetName="Explicite",Mandatory=$False)]
        [System.Collections.Hashtable] $BodyPayload
    )
    BEGIN{
        $Method = "GET"

        $Headers = @{}
        if($Token){
            $Headers['token'] = $Token
        }
        if(!$BodyPayload){
            $Body = @{}
            if($Username){
                $Body['username'] = $Username
            }
            if($Password){
                $Body['password'] = $Password
            }
        } else {
            $Body = $BodyPayload
        }

        if($POST){
            $Method = "POST"
        }

        $URI = "http://" + $Global:Config.APIRoot + $Command
        Write-Log -Event -Message "The URI request made was $URI as a $Method method" -Type INF -Source "AutoPatch" -EventID 100
    }
    PROCESS{
        Try{
            $Data = Invoke-WebRequest -Uri $URI -Headers $Headers -Body $Body -Method $Method
            $Response = ConvertFrom-Json -InputObject $Data.Content
            if($Response.success -eq "True"){
                Write-Log -Event -Message "The URI request was successful" -Type INF -Source "AutoPatch" -EventID 101
            } else {
                Write-Log -Event -Message "The URI request failed with the following error messages[$(ForEach-Object{$Response.Errors})]" -Type ERR -Source "AutoPatch" -EventID 102
            }
        } catch{
            Write-log -Event -Message "The URI request operation failed with the following error[$($_.Exception.Message)]" -Type ERR -Source "AutoPatch" -EventID 103
        }
    }
    END{
        return $Response
    }

}
