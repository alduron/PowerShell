Function Get-FlatProps($Object,$Parent="GPO",$Collection=$null){
    if($Null -eq $Collection){
        $Collection = [System.Collections.Generic.List[Object]]::new()
    }
    if($Object.GetType().Name -match "Object"){
        $Props = $Object.PSObject.Properties
        Foreach($Prop in $Props){
            if( ($Prop.Value.GetType().Name -match "Object") -and ($Prop.MemberType -match "^NoteProperty$") ){
                $SubProps = Get-FlatProps -Object $Prop.Value -Parent "$Parent.$($Prop.Name)" -Collection $Collection -Count $Count
            } elseif(($Prop.Value.GetType().Name -match "Object") -and ($Prop.MemberType -match "^Property$")){
                foreach($Element in $Prop.Value){
                    $SubProps = Get-FlatProps -Object $Element -Parent "$Parent.$($Prop.Name)" -Collection $Collection -Count $Count
                }
            } elseif(!($Prop.MemberType -match "^Property$")) {
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
