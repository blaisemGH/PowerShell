# PowerShell
My PowerShell repository

This is my repository of profile functions. All of the above files constitute 80% of my profile. The remainder and my modules are connected to proprietary software so are not able to be shared. These functions are what I use to improve my CLI experience.

### profile-settings.ps1

  My console settings. I set my terminal background to 15:15:15 r:g:b.

# Functions

### Checkpoint-ModuleVersion
* This function contains comment-based help for its description. Please refer to this for more information. Background: Since I work in closed environments at customers, I desired a means of offline version control for my modules. This function was my approach. Even if using Git, it can still streamline your workflow as it presents a convenient means to update your module version and archive it.

### Find-StringRecursively (alias fsr or grep)
* This is basically a recursive Select-String and is equivalent to Bash's grep -ir. It has additional formatting to improve readability and leverages .NET to retrieve files, only resorting to Get-ChildItem if the .NET method fails. For file search parameters, one can specify a filter on the files and deactivate recursion if desired. The Select-String parameters are all available as of PS 5.1.

### Get-Dir (alias gd)
* An alternative to Get-ChildItem. The attributes column is displayed more prominently, and the length column is properly filled for folders. All columns have been reformatted to fixed widths for readability, and the length column is rounded to the nearest unit. Finally, this supports a tree parameter for viewing files in a tree format.

### Get-ItemSize (alias gs or du)
* Sizes directories similar to du -sh in Bash. Automatically infers the closest unit (KB, MB, GB, TB, PB, etc.), but you can specify a specific unit, too.

### Group-ObjectFixed (alias grp)
* This addresses a performance bug in Group-Object in V5.1 that causes it to run unbearably long for moderately sized objects or larger. The original source does not output the same object as Group-Object; hence, I updated it here.

### Out-AllMembersGrid
* This cmdlet normalizes object headers in collections. In PowerShell, the first object in a collection sets the headers for all subsequent objects in the collections, even if they have different headers. This cmdlet gathers all the headers in the collection and attaches them to each object, so that they are displayed correctly. My usecase at the time I worked on this required a grid as output, although best practice would be to not do this inside the function.

### Replace-StringInFile (alias rs or sed)
* Replaces strings in files according to a RegEx pattern, similar to sed -i. Use -Recurse to pull files recursively for replacement. One of my most useful cmdlets. Note that -IncludeCommentedLines is needed if you wish to update text in lines starting with #.

### Test-ValidArgs
* Validates arguments against a set of allowed values. Say you want to test if a collection contains 'a' or 'b'. You would submit a hashset containing @('a','b') and then your collection as a hashset. If your collection does not contain either value, then it throws an error; if it contains both values, then it also throws an error. The latter can be deactivated (see lines 20+).

  The purpose of this comes from a module I have where my parameter with attribute ValueFromRemainingArguments is used in 2 different contexts. I can only have 1 ValueFromRemainingArguments parameter, and my parameter sets are already complex, so I cannot comfortably split this into a different parameter for each context. I also cannot apply a single ValidationSet attribute to check for both contexts. Therefore, I apply the checks later in the module within each context. This function applies the validation accordingly.

### Update-FileVersionIncrement

* I have a module which aggregates CSVs into 1 file and exports this to a network drive.  Occasionally, the file will be rewritten as new data is delivered. I needed a means to update the file version and wrote this function.

  This function inserts a version marker into the filename, just before the extension, e.g., filename-v01.ext The 'v' can be configured in the input parameter. The '-' is default; however, if the file uses this convention already (?v##), then the ? in ?v## can be a different character, and the function will infer that and use it. If no version is present in the filename, then it will default to -v01, and thereafter it will increment it by 1, e.g., v02, v03, v04 etc. If the file doesn't exist yet, then it will be created with -v01.
