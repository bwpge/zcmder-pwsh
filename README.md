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
$ZcmderOptions.Colors.GitNewRepo.Background = '#2277ff'  # use RGB value for new repo bg color
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

Colors (`ZCColor`) are essentially a pair of color values, `Foreground` and `Background`. A color can be directly assigned to, implying a foreground color (e.g., `$ZcmderOptions.Colors.Cwd = 'DarkRed'`), or you can assign to the `Foreground` and `Background` properties directly (e.g., `$ZcmderOptions.Colors.Cwd.Background = '#FFFFFF'`).

Valid colors have the following form:

- [`ConsoleColor`](https://learn.microsoft.com/en-us/dotnet/api/system.consolecolor) enum name (e.g., `'DarkRed'` or `'White'`)
    - `ConsoleColor` names can be confusing: `Dark<color>` values are the "standard" colors, while `<color>` is the "bright" or "intense" variation
    - These values are converted to 256-color values (0-7 for standard, 8-15 for bright or intense)
- 256-color integer value (e.g., `8` for "bright black" or `142` for `Gold3`, see [this reference](https://ss64.com/bash/syntax-colors.html))
- Hex RGB string `'#RRGGBB'`
- `$null` for no color

Git status colors have the following priority:

- `GitStaged`
- `GitUnmerged`
- `GitUntracked`
- `GitModified`
- `GitRepoNew`
- `GitBranchDefault`

| Key | Type | Usage |
| --- | ---- | ----- |
| `Caret` | `ZCColor` | Default caret color |
| `CaretError` | `ZCColor` | Caret color when the last exit code was non-zero |
| `Cwd` | `ZCColor` | Color of the current working directory |
| `CwdReadOnly` | `ZCColor` | Color when the current working directory is read-only |
| `GitBranchDefault` | `ZCColor` | Default git status color |
| `GitModified` | `ZCColor` | Git status color when only tracked files are modified |
| `GitNewRepo` | `ZCColor` | Git status color when in a new repository |
| `GitStaged` | `ZCColor` | Git status color when all local changes are staged |
| `GitUnmerged` | `ZCColor` | Git status when there are unmerged changes |
| `GitUntracked` | `ZCColor` | Git status when untracked (dirty) files are present |
| `PythonEnv` | `ZCColor` | The color for current python environment name |
| `UserAndHost` | `ZCColor` | Color for both username and hostname components |

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

## Debugging

You can display debug information with the `Write-ZcmderDebugInfo` cmdlet. This is useful if you get a `PS>` prompt (which indicates `$global:prompt` function had error output). The cmdlet will attempt to write the prompt and display error information.

The output of `Write-ZcmderDebugInfo` is particularly helpful to attach in issues. It will look something like:

```
MODULE INFO
-----------

Guid       2f55cab3-5190-4291-839a-4f45b5ae19b2
ModuleBase C:\Users\user\Documents\PowerShell\Modules\Zcmder
Name       Zcmder
Path       C:\Users\user\Documents\PowerShell\Modules\Zcmder\Zcmder.psd1
Version    x.y.z


PROMPT OUTPUT
-------------
>>>>>>>>>>

~
λ
<<<<<<<<<<

DEBUG INFO
----------

(...truncated for brevity...)
Times.DebugElapsed                 564.7499 ms
Times.GitStatusUpdate              19.8973 ms
Times.PromptElapsed                52.3646 ms
```

Note, you may want to sanitize your username if it is captured in the `ModuleBase` or `Path` values.
