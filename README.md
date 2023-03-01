# PowerShell
My PowerShell repository

This is my repository of profile functions. All of the above files constitute 80% of my profile. The remainder and my modules are connected to proprietary software so are not able to be shared. These functions are what I use to improve my CLI experience.

### profile-settings.ps1

  A template of my console settings and generic shortcusts. I set my terminal background to 15:15:15 r:g:b.

# Functions

### Import-Yaml

* This function takes an input yaml file and outputs a hashtable, e.g., `Import-Yaml -Path file.yaml` or `Get-Item file.yaml | Import-Yaml`. It's analogous to the standard Import-Csv cmdlet, although it's lacking the full PSObject functionality; however, this should be possible to incorporate if one needs it (convert hashtable to PSObject, applied recursively over the nested hashtable).

  At the time of writing this, I am consulting a product migrating to Kubernetes, where all the config files are in yaml. I feel that allowing my legacy PowerShell batch module to be configured in yaml and abstracting the rest of the PS code away as much as possible will be best for the future. My module will simply need to parse the yaml files in the background, hence this function. Also, since my customers are banks, downloading third-party modules is a no-no, so bundling this logic natively causes the least friction.

### ConvertFrom-Yaml

* This function is similar to ConvertFrom-Json, but it takes YAML code and converts it into a hashtable. It is currently embedded in the Import-Yaml file and was added for completeness, as one can now import from a yaml file like Import-Csv or from raw yaml code like ConvertFrom-Json. I added it as an afterthought in a couple minutes, and this shows. It is essentially the same as Import-Yaml as it serializes incoming raw code to a temporary file, thereby creating a yaml file that can be parsed the same way Import-Yaml does it. This is trivial to refactor into a proper function when I have a motive to.

### Export-PowerShellDataFile

* This function takes an object and writes it to a new .psd1 file, similar to Export-CSV. This means you can now convert from other file formats to a PowerShellDataFile, e.g., `Get-Content file.json -Raw | ConvertFrom-Json | Export-PowerShellDataFile -Path config.psd1`. It is backed by my supporting function ConvertTo-PowerShellDataFile, which converts any generic PS object to literal PS code. ConvertTo-PowerShellDataFile is inspired by the function from [from Dave-Wyatt](https://stackoverflow.com/a/34383464/6076137).

  Keep in mind the psd1 format is designed for humble config files—don't export a giant csv to psd1 ;). Furthermore, it cannot import a collection of configs, such as what comes from `Invoke-WebRequest 'https://api.github.com/repos/PowerShell/PowerShell/issues' | ConvertFrom-Json | Export-PowerShellDataFile -path issues.psd1; Import-PowerShellDataFile issues.psd1`. However, for a collection of configs, you can still import it via `Invoke-Expression ((Get-Content issues.psd1) -join [Environment]::NewLine)`. While this limitation of `Import-PowerShellDataFile` may seem unfortunate, on the other hand it enforces a simple syntax that can't be overcomplicated. If you run into this limitation, probably you have complicated configs / thousands of lines, and it's simply better to stick with json or `Export-CliXml`. PSD1 should be used for a single, simple config that needs to be more human readable than json/xml, less human readable than yaml but can't be overcomplicated with features and interops better natively with PS (also easier to manually edit/maintain than yaml imo).

### Checkpoint-ModuleVersion
* This function contains comment-based help for its description. Please refer to this for more information. Background: Since I work in closed environments at customers, I desired a means of offline version control for my modules. This function was my approach. Even if using Git, it can still streamline your workflow as it presents a convenient means to update your module version and archive it.

### Find-StringRecursively (alias fsr or grep)
* This is basically a recursive Select-String and is equivalent to Bash's grep -ir. It has additional formatting to improve readability and leverages .NET to retrieve files, only resorting to Get-ChildItem if the .NET method fails. For file search parameters, one can specify a filter on the files and deactivate recursion if desired. The Select-String parameters are all available as of PS 5.1.

### Get-Dir (alias gd)
* An alternative to Get-ChildItem. The attributes column is displayed more prominently, and the length column is properly filled for folders. All columns have been reformatted to fixed widths for readability, and the length column is rounded to the nearest unit. Finally, this supports a tree parameter for viewing files in a tree format. There are hidden parameters to enable sorting, e.g., on directory size via `length`.

### Get-ItemSize (alias gs or du)
* Sizes directories similar to du -sh in Bash. Automatically infers the closest unit (KB, MB, GB, TB, PB, etc.), but you can specify the unit explicitly via input parameter. I've left the fullname, name, and length as hidden properties to enable sorting or selects.

### Group-ObjectFixed (alias grp)
* This addresses a performance bug in Group-Object in V5.1 that causes it to run unbearably long for moderately sized objects or larger. I had borrowed a fixed version from stackOverflow that didn't output the same object properties as `Group-Object`, so I made this function to correct the object output. I have since found the same function [at powershell.one](https://powershell.one/tricks/performance/group-object), which already has the corrected output. I assume this was the original source, and I either copied it wrong or had an incomplete version from somewhere else. This original version also has a nice switch parameter to speed up cases where you just want to count, a feature the original Group-Object also offers that I didn't know about. So the linked function is more complete and original. Credit where credit is due. powershell.one is an awesome site.

### Out-AllMembersGrid
* This cmdlet normalizes object headers in collections. In PowerShell, the first object in a collection sets the headers for all subsequent objects in the collections, even if they have different headers. This means adding additional objects with different headers will cause them to only display the headers in common with the first object. This can cause issues with, e.g., `Export-Csv`. My cmdlet here gathers all the headers in the collection and attaches them to each object, so that they are displayed correctly. My usecase at the time I worked on this required a grid as output, since I was troubleshooting ETL data on the CLI, although best practice would be to not force grid formatting inside the function. Simply delete the pipe to `Out-GridView` in the code to fix this.

### Replace-StringInFile (alias rs or sed)
* Replaces strings in files according to a RegEx pattern, similar to sed -i. Use -Recurse to pull files recursively for replacement. One of my most useful cmdlets. Note that -IncludeCommentedLines is needed if you wish to update text in lines starting with #.

### Test-ValidArgs
* Validates arguments against a set of allowed values. Say you want to test if a collection contains 'a' or 'b'. You would submit a validation hashset containing @('a','b') and then your test collection as a hashset. If your test collection does not contain either value in the validation set, then it throws an error; if it contains both values, then it also throws an error. The latter throw for containing more than 1 value in the validation set can be deactivated (see lines 20+), but if that's your use-case, then you can simply use -in and don't need this function ;)

  The purpose of this comes from a batch job module I have where my parameter with attribute ValueFromRemainingArguments is used in 2 different contexts. In one context, I am running a batch of data loading, so I pass a variable number of input files via this parameter, and in the other context, I am exporting certain data and require additional flags to select that data. I can only have 1 ValueFromRemainingArguments parameter, and my parameter sets are already complex, so I cannot comfortably split this into a different parameter for each context. Therefore, I need a way to dynamically validate this parameter later in the script. That's what this function accomplishes. It can be generically used in any scenario where you need to validate a set without duplicate matches.

### Update-FileVersionIncrement

* I have a module which aggregates CSVs into 1 file and exports this to a network drive.  Occasionally, the file will be rewritten as new data is delivered. I needed a means to update the file version and wrote this function.

  This function inserts a version marker into the filename, just before the extension, e.g., filename-v01.ext The 'v' can be configured in the input parameter. The '-' is default; however, if the file uses this convention already (?v##), then the ? in ?v## can be a different character, and the function will infer that and use it. If no version is present in the filename, then it will default to -v01, and thereafter it will increment it by 1, e.g., v02, v03, v04 etc. If the file doesn't exist yet, then it will be created with -v01.
