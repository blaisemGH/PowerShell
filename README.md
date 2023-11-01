# PowerShell
My PowerShell repository

This is my repository of modules.

# Packages

* The modules are stored as zip files and can be unpacked in any path under $env:PSModulePath.

# Modules

### CliUtils --> RequiredModules PSUtils

* Contains various functions to streamline the cli experience. In particular I extensively use the functions Get-ItemSize, Replace-StringInFile, Find-StringRecursively, Lock-Thread, and `..[.]` to climb file structures.

### ConfigFileUtils --> RequiredModules PSUtils

* Contains modules for dealing with config files. Currently the main function is to load yaml files. I may also include a way to export ps data files in the future, although the code probably already exists somewhere.

### GCloudUtils --> RequiredModules KubectlUtils

* I use this module to quickly obtain GKE credentials, so that I can switch between different GKE contexts on the fly.

### KubectlUtils --> RequiredModules PSUtils

* A wrapper for different kubectl functionalities. Some of my most used are to ping the metric api via Get-KubeMetrics, and then use kmax to find the most strained pod in the cluster, Set-KubeContext (kc) to transfer between clusters quickly, or Copy-KubeFile which is a wrapper of kubectl -cp but has autocomplete on filepaths inside the container, which I find very convenient. Another example is kex, which is a wrapper for kubectl -exec. kex has autocomplete on pods, and the simple syntax of `kex <pod> <command>`. If no command is provided, it will run `kubectl -exec -it <pod name> -- /bin/[bash|sh]`, where it will first attempt bash but default to sh if that fails. If a command is provided, then it runs `kubectl -exec <pod name> -- <command>` A single concise syntax for 3 different verbose kubectl variations.

### Prompt
* My prompt on a 20% opaque low-gradient background in Windows Terminal using the font Hasklug Nerd Font Mono and color scheme Tango Dark. It's a little stupid, but it's easily changed if you're familiar with the prompt function. I left all the symbols in the function, so you can insert your own emojis or symbols. It's like a mini, weaker version of oh-my-posh that doesn't have the wall of documentation and blackbox of go templates required to configure it. It's just 150 lines of PS Code. Also its own challenge, but for me it's more accessible.

### PSUtils
* Similar to CliUtils but contains functions that you aren't likely to use on the cli but rather in scripts and more complex coding. There is a function to convert nested hashtables to PSCustomObjects, such as when importing from a psd1 file. A recursive Read-Host wrapper that will loop until defined valid strings are provided (up to 10 loops by default). There is also a function to join objects using Linq, which already exists as the popular Join-Object module, but I made my own for practice. Haven't worked with it much yet except to perform left joins in the kubectlUtils module.

### RunspaceRunner

* My initial attempt to provide a wrapper to simplify runspace creation, i.e., multithreading in PowerShell. I had a bad experience recently with Start-ThreadJob in PS 7.3, where the threads weren't being properly used beyond 2 threads, so I am now skeptical it's complete and based this module off what I did with runspaces in that script. Barring bare minimum testing on my command line, I haven't tested it in action yet though 💀

### Complete-CSVContents

* This is a pretty niche module. It identifies string fields in a csv file and wraps them in a delimiter character of your choice. It pushes the limits of PS performance, and I was satisfied with the runtimes, maybe around 30-60 sceonds per million lines at 40 fields, about half of which were strings. I may build upon it in the future with other CSV-based tasks as they arise, assuming the content isn't too proprietary.