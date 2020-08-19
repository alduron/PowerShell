function Convert-GPOToPSObject ($Node){
    $Collection = [PSCustomObject]@{}
    foreach($Attribute in $Node.attributes){
        $Collection | Add-Member -MemberType NoteProperty -Name $Attribute.Name -Value $Attribute.value
    }
    $ChildNodesList = ($Node.childnodes | ?{$_ -ne $Null}).LocalName
    foreach($ChildNode in ($Node.ChildNodes | ?{$_ -ne $null})){
        if(($ChildNodesList | ?{$_ -eq $ChildNode.LocalName}).count -gt 1){
            if(!($Collection.$($ChildNode.LocalName))){
                $Children = [System.Collections.Generic.List[Object]]::new()
                $Collection | Add-Member -MemberType NoteProperty -Name $ChildNode.LocalName -Value $Children
            }
            if ($ChildNode.'#text' -ne $null) {
                $Collection | Add-Member -MemberType NoteProperty -Name $ChildNode.LocalName -Value $ChildNode.'#text'
            }
            $Data = Convert-GPOToPSObject -Node $ChildNode
            $Collection.$($ChildNode.LocalName).Add($Data)
        }else{
            if($ChildNode.ChildNodes.Name -match "#cdata-section"){
                Write-Host ""
            }
            if($ChildNode.gettype().Name -match "XmlDeclaration"){
                Write-Host ""
            }
            if ($ChildNode.'#text' -ne $null) {
                $Collection | Add-Member -MemberType NoteProperty -Name $ChildNode.LocalName -Value $ChildNode.'#text'
            }elseif(!($ChildNode.gettype().Name -match "XmlDeclaration") -and ($ChildNode.ChildNodes -ne $null)){
                $Data = Convert-GPOToPSObject -Node $ChildNode
                $Collection | Add-Member -MemberType NoteProperty -Name $ChildNode.LocalName -Value $Data
            } elseif($ChildNode.Value -ne $Null) {
                $Collection | Add-Member -MemberType NoteProperty -Name $ChildNode.LocalName -Value $ChildNode.Value
            } else {
                $Collection | Add-Member -MemberType NoteProperty -Name $ChildNode.LocalName -Value $ChildNode.ChildNodes.Name
            }
        }  
    }
    return $Collection
}

Function Get-FlatPropsCount($Object,$Parent="Root",$Collection=$null,$Count=$null){
    if($Null -eq $Collection){
        $Collection = [System.Collections.Generic.List[Object]]::new()
    }
    if($Object.GetType().Name -match "Object|List"){
        $Props = $Object.PSObject.Properties
        if($Parent.Split(".")[-1] -match "SyncRoot"){
            $Parent = $Parent -replace ".SyncRoot","[{0}]"
            if(!$Count){
                $Count = 0
            }
        }
        Foreach($Prop in $Props){
            if($Null -ne $Prop.Value){
                if( ($Prop.Value.GetType().Name -match "Object|List") -and ($Prop.MemberType -match "^NoteProperty$") ){
                    $Parent = $Parent -f $Count
                    $SubProps = Get-FlatPropsCount -Object $Prop.Value -Parent "$Parent.$($Prop.Name)" -Collection $Collection
                } elseif(($Prop.Value.GetType().Name -match "Object|List") -and ($Prop.MemberType -match "^Property$")){
                    if($Prop.Value -match "System.Object"){
                        $ChildProps = $Object
                    } else {
                        $ChildProps = $Prop.Value
                    }
                    foreach($Element in $ChildProps){
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
            } else {
                $Parent = $Parent -f $Count
                $Record = [PSCustomObject]@{
                    Name = "$Parent.$($Prop.Name)"
                    Value = $Prop.Value
                }
                $Collection.Add($Record)
            }
        }
    } else {
        $Parent = $Parent -f $Count
        $Record = [PSCustomObject]@{
            Name = "$Parent.$($Prop.Name)"
            Value = $Prop.Value
        }
        $Collection.Add($Record)
    }
    $Collection
}
