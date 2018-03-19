Function Get-Config{
    <#
    .SYNOPSIS
        Ingests the configuration file
    .DESCRIPTION
        This function will ingest the JSON configuration file. This should be the only location where the file path is hard-coded. The 
        fucntion will perform the folllowing tasks:
            1) Get the contents of the file and convert it from JSON document
            2) Return the contents
    .EXAMPLE
        $Config = Get-OTConfig
    #>
    [CmdletBinding()]
    param(
    )
    BEGIN{
        $LogPath = '.\Config.json'
    }
    PROCESS{
        #Convert config file from JSON
        if(Test-Path $LogPath){
            $config = Get-Content $LogPath | ConvertFrom-Json
        } else {
            $config = @{}
            $config['Globals'] = @{}
            $config['Modules'] = @{}
            $config['Scripts'] = @{}
            $config.Globals['LogRoot'] = 'C:\users\rob\desktop\Logs\'
            $config.Globals['ScriptLogRoot'] = 'Scripts\'
            $config.Globals['ModuleLogRoot'] = 'Modules\'
            $Config.Globals['APIRoot'] = "localhost/autopatch/public/api/"
        }
        
    }
    END{
        #Return it
        return $config
    }
}

Function Write-ToConsole{
    <#
    .SYNOPSIS
        Formats and writes the contents of a message and error to the console
    .DESCRIPTION
        This function format and print the given message and error into the console using write-host. I'm aware of the problems with
        Write-Host, but there are some wonky issues with streams that I've yet to iron out The function will perform the following
        tasks:
            1) Determine Write-Host color based on type
            2) Detect error message and format message
            3) Print to console
    .PARAMETER Message
        String that will be published to the console
    .PARAMETER Type
        The type header the log line should be represented as
    .PARAMETER ErrorMessage
        String provided from PowerShell Error Exception. This should be attained by catching "$_.Exception.Message" within the calling script
    .EXAMPLE
        Write-ToConsole "Message to be written" -Type ERR -ErrorMessage $_.Exception.Message
    .EXAMPLE
        Write-ToConsole "Message to be written" -Type INF
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
        $PipeData,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [String] $Message,
        [ValidateSet("INF","WRN","ERR","HDR","CON","DIS","RES")]
        [String] $Type,
        [Switch] $Stack
    )
 
    Begin{
        if($Type){$Type = $Type.ToUpper()}
    }
    Process{
        $Content = $PipeData | Format-Message -Message $Message -Type $Type

        #Color picker
        $Flag = "-ForegroundColor"
        Switch($Content.Type){
            "INF" {$Color = "White"}
            "WRN" {$Color = "Yellow"}
            "ERR" {$Color = "Red"}
            "HDR" {$Color = "White"}
            "CON" {$Color = "Green"}
            "DIS" {$Color = "DarkYellow"}
            "RES" {$Color = "White"}
        }
        $Suffix = $Flag + " $Color"

        #Print to console
        Invoke-Expression "Write-Host `"$($Content.Type) | $(get-date -Format "MM/dd/yy HH:mm:ss") | $($Content.Message)`" $Suffix"

    }
    End{
        
    }
}

Function Format-Message{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
        $PipeData,
        [String]$Message,
        [ValidateSet("INF","WRN","ERR","HDR","CON","DIS","RES","")]
        [String]$Type
    )
    Begin{
        $Content = @{}
        $Content['Type'] = ''
        $Content['Message'] = ''
        if($Type){$Content.Type = $Type} else {$Content.Type = 'INF'}
    }
    Process{
        if($PipeData){
            if($PipeData.GetType().ToString() -match 'Exception'){
                if(!$Type){$Content.Type = 'ERR'}
                $PipeMessage = "Exception was thrown in [$($PipeData.Data.Values.MethodName)] at line [$($PipeData.Line)], position [$($PipeData.Offset)]. The message given was [$($PipeData.Message.TrimEnd('.'))]" -replace "`n|`r|`t",""
                if($Stack){
                    $PipeMessage += ". Stack Trace [$($PipeData.StackTrace)]" -replace "`n|`r|`t",""
                }
            } else {
                if(!$Type){
                    $Content.Type = "INF"
                } else {
                    $Content.Type = $Type
                }
                $PipeMessage = $PipeData
            }
            if($Message){
                $Content.Message = $Message + ". " + $PipeMessage
            } else {
                $Content.Message = $PipeMessage
            }
        } else {
            $Content.Message = $Message
            $Content.Type = $Type
        }
    }
    End{
        return $Content
    }
}

Function Write-ToLog{
    <#
    .SYNOPSIS
        Adds log message to the log file provided with an option to pass through to the console
    .DESCRIPTION
        This function will format the given message and error information into a uniform log style. This function
        will execute the following steps:
            1) Detect if a error message is given and format
            2) Append formatted message to log supplied
            3) Pass message to console if required
    .PARAMETER Path
        UNC path to .log file. This file should be pulled from config within the calling module
    .PARAMETER Message
        String that will be published to the log
    .PARAMETER Type
        The type header the log line should be represented as
    .PARAMETER ErrorMessage
        String provided from PowerShell Error Exception. This should be attained by catching "$_.Exception.Message" within the calling script
    .PARAMETER Console
        Switch used for passing log context through to Write-ToConsole function
    .EXAMPLE
        Add-ToLog $Log "Message to pass" -Type ERR -ErrorMessage $_.Exception.Message -Console
    .EXAMPLE
        Add-ToLog $Log "Message to pass" -Type INF
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
        $PipeData,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelineByPropertyName = $False)]
        [String] $Message,
        [ValidateSet("INF","WRN","ERR","HDR","CON","DIS","RES")]
        [String] $Type,
 	    [String] $Path,
        [Switch] $Console
    )
    Begin{
        #Get logging path
        if(!$Path){$Path = Get-LogPath}
        Resolve-LogFile $Path
    }
    Process{
        #Format for error message
        $Content = $PipeData | Format-Message -Message $Message -Type $Type

        #Write to log
        Add-Content $Path "$($Content.Type) | $(get-date -Format "MM/dd/yy HH:mm:ss") | $($Content.Message)"
        
        #Print to console
        if($Console){
            Write-ToConsole -Message $Content.Message -Type $Content.Type
        }
    }
    End{
        
    }
}

Function Write-ToEventLog{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True)]
        $PipeData,
        [Parameter(Mandatory=$False,ValueFromPipeline=$False)]
        [String] $Message,
        [ValidateSet("INF","WRN","ERR","HDR","CON","DIS","RES")]
        [String] $Type,
        [ValidateNotNullOrEmpty()]
        [Int] $EventID,
        [ValidateNotNullOrEmpty()]
        [String] $Source
    ) Begin{
        $EntryType = 'Information'
    }
    Process{
        $Content = $PipeData | Format-Message -Message $Message -Type $Type
        Switch($Content.Type){
            "INF" {$EntryType = "Information"}
            "WRN" {$EntryType = "Warning"}
            "ERR" {$EntryType = "Error"}
            "HDR" {$EntryType = "Information"}
            "CON" {$EntryType = "SuccessAudit"}
            "DIS" {$EntryType = "SuccessAudit"}
            "RES" {$EntryType = "Information"}
        }

        if(Test-Elevation){
            if((Get-ChildItem HKLM:\SYSTEM\CurrentControlSet\Services\EventLog\Application | Select -ExpandProperty Name | Split-Path -Leaf) -notcontains $Source){
                New-EventLog -LogName Application -Source $Source
            }
            Write-EventLog -LogName 'Application' -Source $Source -EventId $EventID -EntryType $EntryType -Message $Content.Message
        } else {
            Write-ToConsole -Message 'You must have administrator rights to write to the Event Log' -Type WRN
        }
    }
    End{
    
    }
}

Function Write-Log{
    [CmdletBinding(DefaultParameterSetName='Console')]
    Param(
        [parameter(ParameterSetName="Console",Mandatory=$False)]
        [parameter(ParameterSetName="Log",Mandatory=$False)]
        [parameter(ParameterSetName="Event",Mandatory=$False)]
        [Switch] $Console,
        [parameter(ParameterSetName="Console",Mandatory=$False)]
        [parameter(ParameterSetName="Log",Mandatory=$False)]
        [parameter(ParameterSetName="Event",Mandatory=$False)]
        [Switch] $Log,
        [parameter(ParameterSetName="Console",Mandatory=$False)]
        [parameter(ParameterSetName="Log",Mandatory=$False)]
        [parameter(ParameterSetName="Event",Mandatory=$False)]
        [Switch] $Event,
        [parameter(ParameterSetName="Console",Mandatory=$False)]
        [parameter(ParameterSetName="Log",Mandatory=$False)]
        [parameter(ParameterSetName="Event",Mandatory=$False)]
        [String] $Message,
        [parameter(ParameterSetName="Console",Mandatory=$True)]
        [parameter(ParameterSetName="Log",Mandatory=$True)]
        [parameter(ParameterSetName="Event",Mandatory=$True)]
        [ValidateSet("INF","WRN","ERR","HDR","CON","DIS","RES")]
        [String] $Type,
        [parameter(ParameterSetName="Log",Mandatory=$False)]
        [String] $Path,
        [parameter(ParameterSetName="Event",Mandatory=$False)]
        [Int] $EventID,
        [parameter(ParameterSetName="Event",Mandatory=$True)]
        [String] $Source,
        [parameter(ParameterSetName="Event",Mandatory=$False)]
        [Switch] $Throw,
        [parameter(ParameterSetName="Console",Mandatory=$False,ValueFromPipeline=$True)]
        [parameter(ParameterSetName="Log",Mandatory=$False,ValueFromPipeline=$True)]
        [parameter(ParameterSetName="Event",Mandatory=$False,ValueFromPipeline=$True)]
        $PipeData
    )
    Begin{
    }
    Process{
        if($Log){
            $PipeData | Write-ToLog -Message $Message -Type $Type -Path $Path
        }
        if($Event){
            $PipeData | Write-ToEventLog -Message $Message -Type $Type -EventID $EventID -Source $Source
        }
        if($Console){
            $PipeData | Write-ToConsole -Message $Message -Type $Type
            $PSBoundParameters.GetEnumerator()
        }
    }
    End{
        if($Throw){
            Throw $PipeData
        }
    }
}

function Test-Elevation {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal -ArgumentList $identity
        return $principal.IsInRole( [Security.Principal.WindowsBuiltInRole]::Administrator )
    } catch {
        throw "Failed to determine if the current user has elevated privileges. The error was: '{0}'." -f $_
    }
}

Function Resolve-LogFile{
    <#
    .SYNOPSIS
        Resolves the log path based on the configuration file supplied
    .DESCRIPTION
        This function will automatically create the log file given the supplied path if it doesn not already exist. 
        The fucntion will perform the folllowing tasks:
            1) Check if the folder exists, creating it if required
            2) Check if the file exists, creating it if required
    .PARAMETER Path
        The UNC path that the function will be checking for
    .EXAMPLE
        Resolve-LogFile $Path
    #>
    [CmdletBinding()]
    Param(
 	    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelineByPropertyName = $False)]
        [ValidatePattern("[a-z]\w+(?=\.log)")]
 	    [String]$Path=""
    )
    Begin{
        $Folder = Split-Path $Path
        $File = Split-Path $Path -Leaf
    }
    Process{
        #Check if file exists, create file if it doesn't
        if(!(Test-Path $Path -PathType Leaf)){
            if(!(Test-Path -Path $Folder -PathType Container)){
                Write-ToConsole "Folder not detected, creating new folder [$Folder]" -Type WRN
                New-Item -Path $Folder -ItemType Directory | Out-Null
            }
            Write-ToConsole "File not detected, creating new file [$File]" -Type WRN
            New-Item $Folder -Name $File -ItemType File | Out-Null
        }
    }
    End{
        
    }
}

Function Get-LogPath{
    <#
    .SYNOPSIS
        Automatically determines the log that should be used for the calling function
    .DESCRIPTION
        This function will look at which module, script, or function is calling for a log write and determine which file and folder it should be writing to based
        off of the configuration file. The fucntion will perform the folllowing tasks:
            1) Get the Call Stack
            2) Parse the Call Stack to determine if it is being called by a script or module
            3) Search for a configuration for the specific function of the module, if one is not defined it will direct the log message to defaults
            4) Search for a configuration for the script, if one is not defined it will direct the log message to defaults
            5) Determine log UNC path and return it
    .EXAMPLE
        $Path = Get-LogPath
    .NOTES
        The automatic resolution assumes the last calling module is the owner of the log message. The function will ignore calls made within the logging module, but it
        may encounter strange behavior with nested modules. For best results each function should be logging its own messages. Do not pass log messages down the pipe.
    #>
    [CmdletBinding()]
    param(
    )
    BEGIN{
        #Get Config file and CallStack for processing
        $config = Get-Config
        $Stack = Get-PSCallStack
    }
    PROCESS{
        #Determine position in callstack, ignoring calls from within this module
        #$Self = $MyInvocation.PSScriptRoot.Split("\")[-1]
        $Self = $MyInvocation.InvocationName
        $ModuleMatch = $Stack | ?{($_.Location -notmatch $Self) -and ($_.Location -notmatch "<No file>") -and ($_.Location -match ".psm1")}
        $ScriptMatch = $Stack | ?{($_.Location -notmatch $Self) -and ($_.Location -notmatch "<No file>") -and ($_.Location -match ".ps1")}
        
        #Check for Module matches first since it's designed specifically for modules
        if($ModuleMatch){
            #Populate the name of the calling function and the module it lives in
            $Module = $ModuleMatch[0].Location.Split(".")[0]
            $Function = $ModuleMatch[0].Command.Split(".")[0]

            #Search config for specific log path requirements
            $LogData = $config.Modules | ? Name -match $Module | Select -Expand Functions | ? Name -Match $Function | Select -Expand Log
            
            #Format appropriately, selecting defaults if needed
            if($LogData){
                $LogFile = $config.Globals.LogRoot + $LogData
            } else {
                $LogDefault = $config.Modules | ? Name -match "Default" | Select -Expand LogDefault
                $LogFile = $config.Globals.LogRoot + $LogDefault + "$Function.Log"
            }

        #Check if the calling function is actually part of a script
        } elseif($ScriptMatch) {
            #Assign the script and function name. These may be the same name
            $Script = $ScriptMatch[0].Location.Split(".")[0]
            $Name = $ScriptMatch[0].Command.Split(".")[0]

            #Search the config file for matching script log data. If not exist, select the default
            $LogData = $config.Scripts | ? Name -Match $Script | Select -Expand Log
            if($LogData){
                $LogFile = $config.Globals.LogRoot + $config.Globals.ScriptLogRoot + $LogData
            } else {
                $LogFile = $config.Globals.LogRoot + $config.Globals.ScriptLogRoot + "$Name.log"
            }
        } else {
            $LogFile = $config.Globals.LogRoot + $config.Globals.ScriptLogRoot + "Orphaned.log"
        }
    }
    END{
        #Return the UNC log path
        Return $LogFile
    }
}