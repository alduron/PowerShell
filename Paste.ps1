Function Get-FlatPropsCount($Object,$Parent="GPO",$Collection=$null,$Count=$null){
    if($Null -eq $Collection){
        $Collection = [System.Collections.Generic.List[Object]]::new()
    }
    if($Object.GetType().Name -match "Object"){
        $Props = $Object.PSObject.Properties
        if($Parent.Split(".")[-1] -match "SyncRoot"){
            $Parent = $Parent -replace ".SyncRoot","[{0}]"
            if(!$Count){
                $Count = 0
            }
            $IsObjectChild = $true
        } else {
            $IsObjectChild = $false
        }
        Foreach($Prop in $Props){
            #Write-Host ""
            if( ($Prop.Value.GetType().Name -match "Object") -and ($Prop.MemberType -match "^NoteProperty$") ){
                $Parent = $Parent -f $Count
                $SubProps = Get-FlatPropsCount -Object $Prop.Value -Parent "$Parent.$($Prop.Name)" -Collection $Collection
            } elseif(($Prop.Value.GetType().Name -match "Object") -and ($Prop.MemberType -match "^Property$")){
                foreach($Element in $Prop.Value){
                    $Parent = $Parent -f $Count
                    $SubProps = Get-FlatPropsCount -Object $Element -Parent "$Parent.$($Prop.Name)" -Collection $Collection -Count $Count
                    $Count++
                }
            } elseif(!($Prop.MemberType -match "^Property$")) {
                $Parent = $Parent -f $Count
                $Record = [PSCustomObject]@{
                    Name = "$Parent.$($Prop.Name)"
                    Value = $Prop.Value
                }
                $Collection.Add($Record)
            }
        }
    } else {
        $Record = [PSCustomObject]@{
            Name = "$Parent.$($Prop.Name)"
            Value = $Prop.Value
        }
        $Collection.Add($Record)
    }
    $Collection
}
