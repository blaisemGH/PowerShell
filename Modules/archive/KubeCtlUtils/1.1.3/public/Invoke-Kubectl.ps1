using namespace System.Management.Automation
function Invoke-Kubectl {
    Param(
        [Parameter(Mandatory, Position=0)]
        [KubeCommandTransform()]
        [KubeCommandCompleter()]
        [string]$Command,
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$RemainingArgs,
        [KubeNamespaceCompleter()]
        [string]$Namespace
    )
    
    DynamicParam {
        $dynParams = [RuntimeDefinedParameterDictionary]::new()

        $standardResourceCommands = 'get','edit','scale','describe','delete'
        $exceptionalResourceCommands = 'logs', 'port-forward', 'rollout'

        if ( $Command -in ($standardResourceCommands + $exceptionalResourceCommands) ) {
            $attribute = [ParameterAttribute]::new()
            $resourceTransformer = [KubeResourceTransform]::new()
            $resourceCompleter = [KubeResourceCompletionsAttribute]::new()
            $attributeCollection1 = [Collections.ObjectModel.Collection[System.Attribute]]::new()
            $attributeCollection1.Add($resourceTransformer)
            $attributeCollection1.Add($resourceCompleter)
        }
        if ( $Command -in $resourceCommands ) {
            $attribute.Mandatory = $true
            $attributeCollection1.Add($attribute)
            $param1 = [RuntimeDefinedParameter]::new('Resource', [string], $attributeCollection1)
            $dynParams.Add('Resource', $param1)
        }
        elseif ( $Command -eq 'logs' ) {
            $attributeCollection1.Add($attribute)
            $param1 = [RuntimeDefinedParameter]::new('Resource', [string], $attributeCollection1)
            $param1.Value = 'pods'
            $dynParams.Add('Resource', $param1)
        }
        elseif ( $Command -eq 'port-forward' ) {
            $attributeCollection1.Add($attribute)
            $param1 = [RuntimeDefinedParameter]::new('Resource', [string], $attributeCollection1)
            $param1.Value = 'services'
            $dynParams.Add('Resource', $param1)
        }
        elseif ( $Command -eq 'rollout' ) {
            $validateRolloutSubCommand = [ValidateSetAttribute]::new('history','pause','restart','resume','status','undo')
            $attributeRollout = [ParameterAttribute]@{mandatory=$true}
            $attributeCollectionRollout = [Collections.ObjectModel.Collection[System.Attribute]]::new($attributeRollout)
            $attributeCollectionRollout.Add($validateRolloutSubCommand)
            $paramRollout = [RuntimeDefinedParameter]::new('SubCommand', [string], $attributeCollectionRollout)
            $dynParams.Add('SubCommand',$paramRollout)
            
            $attributeCollection1.Add($attribute)
            $param1 = [RuntimeDefinedParameter]::new('Resource', [string], $attributeCollection1)
            $dynParams.Add('Resource', $param1)
        }
        return $dynParams
    }

}