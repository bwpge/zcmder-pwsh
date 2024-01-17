# zcmder-pwsh

A PowerShell port of my [zcmder](https://github.com/bwpge/zcmder) theme for `zsh`.

A lot of this module's implementation uses the great work done by the authors of [posh-git](https://github.com/dahlbyk/posh-git).

## Requirements

This module requires a minimum version of [PowerShell 7.0](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows).

The easiest way to install the latest version of PowerShell is with `winget`:

```sh
winget install --id Microsoft.Powershell --source winget
```

## Installation

Clone this repository and add the following to the top of your `$PROFILE` script:

```pwsh
Import-Module path\to\zcmder-pwsh\Zcmder
Set-ZcmderPrompt
```

### Symbolic Link

To avoid using the full path with `Import-Module`, you can create a symbolic link to this module in your PowerShell module directory (usually `$HOME\Documents\PowerShell\Modules`).

You can ensure this directory is created with (be sure to note the path):

```pwsh
New-Item ([System.IO.DirectoryInfo]$env:PSModulePath.Split(';')[0]) -ItemType Directory -Force -ea 0
```

To create a symbolic link, you need to use an admin prompt and run:

```pwsh
New-Item -ItemType SymbolicLink -Path your\modules\path -Target path\to\zcmder-pwsh\Zcmder\
```

Then you can just use `Import-Module Zcmder` in your `$PROFILE` script.
