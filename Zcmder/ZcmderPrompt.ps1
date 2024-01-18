function Write-ZCPythonEnv {
    $color = $global:ZcmderOptions.Colors.PythonEnv
    $py = if (Test-Path env:CONDA_PROMPT_MODIFIER) {
        $env:CONDA_PROMPT_MODIFIER
    } elseif (Test-Path env:VIRTUAL_ENV) {
        $env:VIRTUAL_ENV
    }
    if ($py) {
        $py = $py.Trim()
        Write-Host "$py " -NoNewline -Foreground $color
    }
}

function Write-ZCUsername {
    $sp = ""
    if (!$global:ZcmderOptions.Components.Hostname) {
        $sp = " "
    }
    Write-Host $env:USERNAME$sp -NoNewline -Foreground $global:ZcmderOptions.Colors.Username
}

function Write-ZCHostname {
    $sep = ""
    if ($global:ZcmderOptions.Components.Username) {
        $sep = "@"
    }
    Write-Host "$sep$env:COMPUTERNAME " -NoNewline -Foreground $global:ZcmderOptions.Colors.Hostname
}

function Write-ZCCwd {
    $opts = $global:ZcmderOptions
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    $p = Write-ZCPath $path

    $prefix = ""
    $color = $global:ZcmderOptions.Colors.Cwd
    if (Test-IsReadOnlyDir $path) {
        $prefix = $opts.Strings.ReadOnlyPrefix
        $color = $opts.Colors.CwdReadOnly
    }
    Write-Host "$prefix$p" -NoNewline -Foreground $color
}

function Write-ZCGitStatus {
    # NOTE: Set-ZCStateGitStatus must be called first for this to be accurate

    $opts = $global:ZcmderOptions
    $state = $global:ZcmderState

    if (!$state.Git.IsRepo) {
        return
    }

    Write-Host $opts.Strings.GitPrefix -NoNewline

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
    $label = $opts.Strings.GitBranchIcon + $state.Git.Label
    Write-Host $label$remote$modifier$suffix -NoNewline -Foreground $color
}

function Write-ZCCaret {
    $state = $global:ZcmderState
    $opts = $global:ZcmderOptions

    $color = if ($state.ExitCode -eq 0) { $opts.Colors.Caret } else { $opts.Colors.CaretError }
    $caret = if ($state.IsAdmin) { $opts.Strings.CaretAdmin } else { $opts.Strings.Caret }
    Write-Host
    Write-Host $caret -NoNewline -Foreground $color
}

function Write-ZcmderPrompt {
    $opts = $global:ZcmderOptions

    # if set, update git status first to avoid choppy printing
    if ($opts.DeferPromptWrite -and $opts.Components.GitStatus) {
        Set-ZCStateGitStatus
    }
    # new line before prompt if not at top row
    if ($opts.NewlineAfterCmd -and !$Host.UI.RawUI.CursorPosition.Y -eq 0) {
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
