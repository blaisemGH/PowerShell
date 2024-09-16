function Register-GCloudCompletion {
    $gcloudCompletion = {
        param($wordToComplete, $commandAst, $commandCharPosition)
        $argTokens = $commandAst.CommandElements.Extent.Text | where { $_ -notmatch '^-' }
        $ht = [GCloud]::CompletionTree.Clone()
        $gcloudAllFlags = $ht.gcloudAllFlags | Sort-Object
        $ht.Remove('gcloudAllFlags')

        # step through completion possibilities for each token.
        if ( $argTokens.Count -gt 1 ) {
            foreach ( $token in $argTokens ){
                if ( $token -eq 'gcloud' ) { continue }
                if ( $ht.ContainsKey($token) ) { #-and !$flagIsCommandWithProperties...
                    if ( $ht[$token].ContainsKey('commandProperties') ) {
                        $ht = $ht[$token].commandProperties
                    }
                    else {
                        $ht = $ht[$token]
                    }
                }
            }
        }
            
        # Handle the case where the last token is a subarg. This requires a different completion logic.
        if ( $argTokens[-1] -match '=' ) {
            $key = ($argTokens[-1] -split '=')[0] + '='
            $value = $ht.$key
            $outCompletionStrings = switch ($value) {
                { $_ -is [IList] } {
                    $value
                }
                { $_ -is [IDictionary] } {
                    $splitSubArgs = $completionStrings[0] -split '=',2
                    if ( $splitSubArgs.Count -gt 1) {
                        [string[]]$subTokens = $splitSubArgs[-1] -split ','
                        $lastSubToken = $subTokens[-1]

                        # if --arg=sub1=<unfinished value> or --arg=sub1=
                        if ( $lastSubToken -match '=' ) {
                            [string[]]$splitLastSubToken = $lastSubToken -split '='
                            $lastSubValue = $splitLastSubToken[1]
                            $value.Values | where { $_ -like "$lastSubValue*" }
                          # if --arg=sub1=x,sub2=y or --arg=su
                        } else {
                            $lastSubKey = $lastSubToken[0]
                            [string[]]$alreadyUsedSubKeys = $subtokens | foreach {
                                if ($_ -match '=') {
                                    ($_ -split '=')[0]
                                }
                            }
                            $value.Keys | where { $_ -notin $alreadyUsedSubKeys -and $_ -like "$lastSubKey*" }
                        }
                        # if --arg=
                    } else {
                        $value.Keys
                    }
                }
            }           
            return $outCompletionStrings | Sort-Object -Unique
        }
        else {
            $gcloudAllFlags = if ( $ht.gcloudAllowedAllFlags ) {
                $ht.gcloudAllowedAllFlags
            } else { @() }

            return [string[]]($ht.Keys | Where-Object { $_ -like "$wordToComplete*" -and $_ -notin 'gcloudAllowedAllFlags', 'commandProperties' } | Sort-Object -Unique) + ($gcloudAllFlags | Where-Object { $_ -notin $argTokens -and $_ -in $flags })
        }
    }

    Register-ArgumentCompleter -CommandName gcloud -ScriptBlock $gcloudCompletion -Native
}