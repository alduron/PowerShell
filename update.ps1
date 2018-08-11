##TESTING
Remove-Variable CanDownload -Force -ErrorAction SilentlyContinue
Remove-Variable CanShowPhoto -Force -ErrorAction SilentlyContinue
Remove-Variable Links -Force -ErrorAction SilentlyContinue
Remove-Variable Link -Force -ErrorAction SilentlyContinue
Remove-Variable FileTypesO -Force -ErrorAction SilentlyContinue
Remove-Variable PhotoLinks -Force -ErrorAction SilentlyContinue
Remove-Variable VideoLinks -Force -ErrorAction SilentlyContinue
Remove-Variable WebLinks -Force -ErrorAction SilentlyContinue
Remove-Variable RandPool -Force -ErrorAction SilentlyContinue
Remove-Variable UpdatePath -Force -ErrorAction SilentlyContinue
Remove-Variable MediaPathO -Force -ErrorAction SilentlyContinue

$MediaPath = "C:\Users\aldur\Pictures\Thumbs"

##WEBREQUEST
$Web = Invoke-webrequest http://digitalinjections.com/stinatroll/
$Variables = ($Web.ParsedHtml.body.getElementsByClassName('entry-content'))[0].innertext -split "`r`n"

##PROCESS WEB
Foreach ($Var in $Variables){
    $Name = $Var.split('=',2)[0]
    $Data = $Var.split('=',2)[1]
    
    if(($Data -match " ") -and ($Name -notmatch "Path")){
        Write-Host "$Data matched Array"
        $Array = $Data -split ' +(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)'
        New-Variable -Name $Name -Value $Array
    } elseif($Data -match 'True') {
        Write-Host "True"
        Invoke-Expression ("`$$($Name) = `$True")
    } elseif($Data -match 'False') {
        Write-Host "False"
        Invoke-Expression ("`$$($Name) = `$False")
    } else {
        Write-Host "Default"
        New-Variable -Name $Name -Value $Data
    } 
}

##CHECK FOR OVERRIDES
if($MediaPathO){$MediaPath = $MediaPathO}
if($FileTypesO){$FileTypes = $FileTypesO}

##DEFAULTS
$WC = New-Object System.Net.WebClient

$PhotoFolder = "$MediaRoot\Photos"
$VideoFolder = "$MediaRoot\Video"
$UpdateFolder = "$MediaRoot\UpdateFile"

##PROCESS DOWNLOADS
if($CanDownload){
    New-Item -ItemType Directory -Force -Path "$PhotoFolder" | Out-Null
    New-Item -ItemType Directory -Force -Path "$VideoFolder" | Out-Null
    foreach ($Link in $PhotoLinks){
        $SystemName = Split-Path $Link -Leaf
        $Path = "$PhotoFolder\$SystemName"
        if(!(Get-ChildItem -Path $Path -ErrorAction SilentlyContinue)){
            $WC.DownloadFile($Link,$Path)
        }
    }

    foreach($Link in $VideoLinks){
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
Write-Host "DO $DoingIndex"
if($DoOn -contains $DoingIndex){
    Write-Host "Doing"
    $Index = Get-Random -Maximum 3
    Write-Host "INDEX $Index"

    switch($Index){
        0 {
            if($CanShowPhoto){
                Write-Host "Photos"
                $Pictures = Get-ChildItem -Path $PhotoFolder | ?{$FileTypes -match $_.Extension}
                $Rand = Get-Random -Minimum 0 -Maximum ($Pictures.Count - 1)
                $Picture = $Pictures[$Rand].FullName
                & "$Picture"
            }
          }
        1 {
            if($CanShowVideo){
                Write-Host "Video"
                $Videos = Get-ChildItem -Path $VideoFolder | ?{$FileTypes -match $_.Extension}
                $Rand = Get-Random -Minimum 0 -Maximum $Videos.Count
                $Video = $Videos[$Rand].FullName
                & "$Video"
            }
          }
        2 {
            if($CanShowWeb){
                Write-Host "Website"
                $Rand = Get-Random -Minimum 0 -Maximum $WebLinks.Count
                $Website = $WebLinks[$Rand]
                Start-Process -FilePath $Website  
            }
          }
    }
} else {
    Write-Host "Not Doing"
}

##PROCESS UPDATE
If($UpdatePath){
    $Script = $MyInvocation.InvocationName
    $File = $WC.DownloadFile($UpdatePath,$env:TEMP)
}
