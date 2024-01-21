# zcmder-pwsh

A PowerShell port of my [zcmder](https://github.com/bwpge/zcmder) theme for `zsh`.

A lot of this module's implementation uses the great work done by the authors of [posh-git](https://github.com/dahlbyk/posh-git).

## Requirements

This module requires a minimum version of PowerShell 5.0 (a fresh install of Windows 10/11 should come with 5.1).

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
New-Item ([System.IO.DirectoryInfo]$env:PSModulePath.Split(';')[0]) -Confirm -ItemType Directory -Force -EA 0
```

To create a symbolic link, you need to use an admin prompt and run:

```pwsh
New-Item -Confirm -ItemType SymbolicLink -Path your\modules\Zcmder -Target path\to\zcmder-pwsh\Zcmder
```

Then you can just use `Import-Module Zcmder` in your `$PROFILE` script.

## Configuration

This module uses a global variable `ZcmderOptions` to manage configuration. This object ([`ZCOptions`](https://github.com/bwpge/zcmder-pwsh/blob/main/Zcmder/ZcmderTypes.ps1)) has the following structure:

- [`ZCOptions.*`](#zcoptions)
- [`ZCOptions.Colors`](#zcoptionscolors)
- [`ZCOptions.Components`](#zcoptionscomponents)
- [`ZCOptions.Strings`](#zcoptionsstrings)

When the module is imported by `Import-Module`, the variable is reset to ensure proper initialization. To customize settings, set your desired values *after* calling `Import-Module`.

Example `$PROFILE`:

```powershell
Import-Module Zcmder
Set-ZcmderPrompt

# zcmder options
$ZcmderOptions.Colors.GitBranchDefault = 'DarkMagenta'  # use magenta for default git branch color
$ZcmderOptions.Colors.GitNewRepo = 'Blue'  # use bright blue for new repo color
$ZcmderOptions.Components.PythonEnv = $false  # disable python env prefix
$ZcmderOptions.Strings.GitSeparator = ' '  # remove ' on ' before git prompt
$ZcmderOptions.Strings.GitPrefix = '■ '  # use different branch icon
```

The following tables explains each option and usage.

### `ZCOptions.*`

Controls general behavior of the prompt.

| Key | Type | Usage |
| --- | ---- | ----- |
| `DeferPromptWrite` | bool | Defers writing the prompt until all components update. This will avoid choppy printing on new prompts, but may make the prompt feel sluggish in git repositories. Not recommended. |
| `GitShowRemote` | bool | Show the remote with git status (e.g., `main:origin/main`) |
| `NewlineBeforePrompt` | bool | Print an empty line before the next prompt (excluding the first prompt) |
| `UnixPathStyle` | bool | Does some naive string manipulation on the current working directory component to print Unix-style paths. This is purely aesthetic and does not affect anything in the shell. |

### `ZCOptions.Colors`

Controls colors of the various items in the prompt.

Color names must be valid values to the [`-ForegroundColor` argument of `Write-Host`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/write-host#-foregroundcolor). Note that a quirk about this cmdlet is that `Dark<color>` is the "regular" color, while `<Color>` is the "bright" equivalent.

Git status colors have the following priority:

- `GitStaged`
- `GitUnmerged`
- `GitUntracked`
- `GitModified`
- `GitRepoNew`
- `GitBranchDefault`

| Key | Type | Usage |
| --- | ---- | ----- |
| `Caret` | color | Default caret color |
| `Caret_error` | color | Caret color when the last exit code was non-zero |
| `Cwd` | color | Color of the current working directory |
| `CwdReadOnly` | color | Color when the current working directory is read-only |
| `GitBranchDefault` | color | Default git status color |
| `GitModified` | color | Git status color when only tracked files are modified |
| `GitNewRepo` | color | Git status color when in a new repository |
| `GitStaged` | color | Git status color when all local changes are staged |
| `GitUnmerged` |color | Git status when there are unmerged changes |
| `GitUntracked` | color | Git status when untracked (dirty) files are present |
| `PythonEnv` | color | The color for current python environment name |
| `UserAndHost` | color | Color for both username and hostname components |

### `ZCOptions.Components`

Controls which components or segments of the prompt are printed.

| Key | Type | Usage |
| --- | ---- | ----- |
| `Cwd` | bool | Print the current working directory in the prompt |
| `GitStatus` | bool | Print a git status (if in a git repo) in the prompt |
| `Hostname` | bool | Print the hostname in the prompt |
| `PythonEnv` | bool | Print the current python environment (`conda`or `venv`) in the prompt |
| `Username` | bool | Print the username in the prompt |

### `ZCOptions.Strings`

Controls values or tokens in each component that are printed.

| Key | Type | Usage |
| --- | ---- | ----- |
|`Caret`| string | Prompt string (the value printed directly before user input area) |
|`CaretAdmin`| string | Prompt string when running with elevated permissions |
|`GitAheadPostfix`| string | Printed when repo is ahead of upstream |
|`GitBehindPostfix`| string | Printed when repo is behind upstream |
|`GitCleanPostfix`| string | Printed when repo has no local changes |
|`GitDirtyPostfix`| string | Printed when repo contains unstaged changes |
|`GitDivergedPostfix`| string | Printed when repo is both ahead and behind (diverged from) upstream |
|`GitLabelNew`| string | Label to use for a new repository |
|`GitPrefix`| string | Prefix always printed for git status e.g., a branch icon or `git(` |
|`GitSeparator`| string | A separator or preamble before the git status is printed e.g., `' on '` |
|`GitStashedModifier`| string | Printed when repo contains stashes |
|`GitSuffix`| string | Suffix always printed for git status e.g., `)` |
|`ReadOnlyPrefix`| string | Printed before current working directory when read-only |
