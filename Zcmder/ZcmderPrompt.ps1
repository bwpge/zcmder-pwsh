# this function uses beatcracker/Powershell-Misc as a reference for implementation
# see: https://github.com/beatcracker/Powershell-Misc/blob/master/Write-Host.ps1
function Write-ZCHost {
    [CmdletBinding()]
    param(
        [Parameter(
            Position=0,
            ValueFromPipeline=$true,
            ValueFromRemainingArguments=$true
        )]
        [Alias('Msg', 'Message')]
        [System.Object[]]$Object,
        [System.Object]$Separator,
        [AllowNull()]
        [ZCColor]$Color,
        [switch]$NoNewline
    )

    # see: https://en.wikipedia.org/wiki/ANSI_escape_code
    begin {
        $esc = [char]27
        $ansi_fmt = "$esc[{0}m"
        $reset = $ansi_fmt -f '0'
    }

    process {
        $PSBoundParameters.Remove("Color")
        if (!$Color) {
            Write-Host @PSBoundParameters
            return
        }
        $PSBoundParameters.Remove("Object")
        $seq = $Color.ToAnsiString()

        Write-Host "$seq$Object$reset" @PSBoundParameters
    }
}

function Write-ZCPythonEnv {
    $color = $global:ZcmderOptions.Colors.PythonEnv
    $py = if (Test-Path env:CONDA_PROMPT_MODIFIER) {
        ($env:CONDA_PROMPT_MODIFIER).Trim()
    } elseif (Test-Path env:VIRTUAL_ENV) {
        "($($(Get-Item $env:VIRTUAL_ENV).Basename))"
    }
    if ($py) {
        Write-ZCHost "$py " -NoNewline -Color $color
    }
}

function Write-ZCUsername {
    $sp = ""
    if (!$global:ZcmderOptions.Components.Hostname) {
        $sp = " "
    }
    Write-ZCHost $env:USERNAME$sp -NoNewline -Color $global:ZcmderOptions.Colors.UserAndHost
}

function Write-ZCHostname {
    $sep = ""
    if ($global:ZcmderOptions.Components.Username) {
        $sep = "@"
    }
    Write-ZCHost "$sep$env:COMPUTERNAME " -NoNewline -Color $global:ZcmderOptions.Colors.UserAndHost
}

function Write-ZCCwd {
    $opts = $global:ZcmderOptions
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    $p = Write-ZCPath $path

    $prefix = ""
    $color = $global:ZcmderOptions.Colors.Cwd
    if (!$global:ZcmderState.IsAdmin -and (Test-IsReadOnlyDir $path)) {
        $prefix = $opts.Strings.ReadOnlyPrefix
        $color = $opts.Colors.CwdReadOnly
    }
    Write-ZCHost "$prefix$p" -NoNewline -Color $color
}

function Write-ZCGitStatus {
    # NOTE: Set-ZCStateGitStatus must be called first for this to be accurate

    $opts = $global:ZcmderOptions
    $state = $global:ZcmderState

    if (!$state.Git.IsRepo) {
        return
    }

    Write-ZCHost $opts.Strings.GitSeparator -NoNewline

    # get status modifiers from local changes
    $modifier = ""
    if ($state.Git.Changes) {
        $modifier += $opts.Strings.GitDirtyPostfix
    }
    # otherwise repo is clean, but don't show if in a new repo
    elseif ($state.Git.Label -ne $opts.Strings.GitLabelNew) {
        $modifier = $opts.Strings.GitCleanPostfix
    }
    # add stashed modifier
    if ($state.Git.Stashed) {
        $modifier += $opts.Strings.GitStashedModifier
    }

    # branch suffix from remote status
    $diverged = $state.Git.IsDiverged()
    $suffix = ""
    if ($diverged) {
        $suffix = $opts.Strings.GitDivergedPostfix
    } elseif ($state.Git.Ahead) {
        $suffix = $opts.Strings.GitAheadPostfix
    } elseif ($state.Git.Behind) {
        $suffix = $opts.Strings.GitBehindPostfix
    }

    # get color based on local or remote
    $color = if ($state.Git.Changes -and ($state.Git.Changes -eq $state.Git.Staged)) {
        $opts.Colors.GitStaged
    } elseif ($state.Git.Unmerged -or $diverged) {
        $opts.Colors.GitUnmerged
    } elseif ($state.Git.Untracked -gt 0) {
        $opts.Colors.GitUntracked
    } elseif ($state.Git.Modified -gt 0) {
        $opts.Colors.GitModified
    } else {
        $opts.Colors.GitBranchDefault
    }

    $remote = if ($state.Git.Remote) { ":" + $state.Git.Remote }
    $label = $opts.Strings.GitPrefix + $state.Git.Label
    Write-ZCHost $label$remote$modifier$suffix -NoNewline -Color $color
}

function Write-ZCCaret {
    $state = $global:ZcmderState
    $opts = $global:ZcmderOptions

    $color = if ($state.ExitCode -eq 0) { $opts.Colors.Caret } else { $opts.Colors.CaretError }
    $caret = if ($state.IsAdmin) { $opts.Strings.CaretAdmin } else { $opts.Strings.Caret }

    # avoid painting caret background across lines depending on terminal emulator
    Write-Host
    Write-ZCHost "$caret" -NoNewline -Color $color
}

function Write-ZcmderPrompt {
    $opts = $global:ZcmderOptions

    # if set, update git status first to avoid choppy printing
    if ($opts.DeferPromptWrite -and $opts.Components.GitStatus) {
        Set-ZCStateGitStatus
    }
    # new line before prompt if not at top row
    if ($opts.NewlineBeforePrompt -and !$Host.UI.RawUI.CursorPosition.Y -eq 0) {
        Write-Host
    }
    if ($opts.Components.PythonEnv) {
        Write-ZCPythonEnv
    }
    if ($opts.Components.Username) {
        Write-ZCUsername
    }
    if ($opts.Components.Hostname) {
        Write-ZCHostname
    }
    if ($opts.Components.Cwd) {
        Write-ZCCwd
    }
    if ($opts.Components.GitStatus) {
        if (!$opts.DeferPromptWrite) {
            Set-ZCStateGitStatus
        }
        Write-ZCGitStatus
    }
    Write-ZCCaret
}
