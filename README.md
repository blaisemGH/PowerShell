# PowerShell
My repository of PowerShell modules. This is not released yet and all officially WIP, especially the comment helps. As the modules finish, I'll upload them to PSGallery (probably).

Otherwise, I use these every day at work, some for years, some for only a few months. I guess that's how I am field testing it all.

Before using these, I recommend installing Windows Terminal, the latest PowerShell Core version, and using this as your default in Windows Terminal. If you use my PSPrompt module, then Windows Terminal and also a nerd font are required (https://www.nerdfonts.com/font-downloads).

# Packages

* The modules are stored as zip files and can be unpacked in any path under $env:PSModulePath.
* After doing so, add `Import-Module <module name>` to your `$profile`, e.g., `Import-Module CliUtils`.

Eventually I will make these modules robust enough for a more public release and upload them to PSGallery.

# Modules

### CliUtils --> RequiredModules PSUtils

* Contains various functions to streamline the cli experience. In particular I extensively use Select-NestedObject for parsing structured data (accepts wildcards), as well as the functions Get-ItemSize, Replace-StringInFile, Find-StringRecursively, Lock-Thread, and `..[.]` to climb file structures.

### ConfigFileUtils --> RequiredModules PSUtils

* Contains functions for dealing with config files. Currently the main function is to handle yaml data, but it has a setup to include toml and some other ideas in the future. These will all be wrapped behind a single function set: \[Import|ConvertFrom|ConvertTo|Export]-StructuredData. I'll probably rename this module to StructuredDataUtils at that point.

### GCloudUtils --> RequiredModules KubectlUtils

* I use this module to quickly obtain GKE credentials, track projects via mounted logical drive (gcp:), and to keep track of which project I am in by editing my prompt line to display it.

### KubectlUtils --> RequiredModules PSUtils

* A wrapper for different kubectl functionalities. Some of my most used are to ping the metric api via Get-KubeMetrics, and then use kmax to find the most strained pod in the cluster, Set-KubeContext (kc) to transfer between clusters quickly, or Copy-KubeFile which is a wrapper of kubectl -cp but has autocomplete on filepaths inside the container, which I find very convenient. Another example is kex, which is a wrapper for kubectl -exec. I'll add help eventually.

### PSPrompt
* This is like an inferior Oh-My-Posh, BUT:
1. Its scriptblocks are in PowerShell. No need to learn GoLang or doc up on its dozen syntaxes.
2. You can update it modularly. My kubectlutils and gcloudutils modules update the prompt function if this module is imported.

I do need to rewrite the help for its latest configuration settings.

### PSUtils
* Similar to CliUtils but contains functions that you aren't likely to use on the cli but rather in scripts and more complex coding. I have my own Join-Object via Linq there, just made it for practice.

### RunspaceRunner

* My initial attempt to provide a wrapper to simplify runspace creation, i.e., multithreading in PowerShell. I had a bad experience recently with Start-ThreadJob in PS 7.3, where the threads weren't being properly used beyond 2 threads, so I am now skeptical it's complete and based this module off what I did with runspaces in that script. Barring bare minimum testing on my command line, I haven't tested it in action yet though 💀

### Complete-CSVContents

* This is a pretty niche module, but I intend to adapt it in the future for multithreaded handling of CSV files. Currently it parses a CSV and wraps string values in quotes if they are missing. It does depend on the first row being filled to identify data types.