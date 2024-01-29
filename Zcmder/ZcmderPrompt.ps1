function New-ZCAnsiString {
    param(
        [Parameter(Mandatory = $true)]
        [System.Object]$Object,
        [AllowNull()]
        [ZCColor]$Color,
        [AllowNull()]
        [ZCStyle]$Style,
        [System.Object]$Before,
        [System.Object]$After
    )

    if (!$Host.UI.SupportsVirtualTerminal -or (!$Color -and !$Style)) {
        "$Before$Object$After"
    } else {
        $reset = "{0}[0m" -f ([char]27)
        $c = if ($Color) { $Color.ToAnsiString() } else { "" }
        $s = if ($Style) { $Style.ToAnsiString() } else { "" }
        "$Before$s$c$Object$reset$After"
    }
}

function Get-ZCPythonEnv {
    $py = if (Test-Path env:CONDA_PROMPT_MODIFIER) {
        ($env:CONDA_PROMPT_MODIFIER).Trim()
    } elseif (Test-Path env:VIRTUAL_ENV) {
        "($($(Get-Item $env:VIRTUAL_ENV).Basename))"
    }
    if ($py) {
        $color = $global:ZcmderOptions.Colors.PythonEnv
        $style = $global:ZcmderOptions.Styles.PythonEnv
        New-ZCAnsiString "$py" -Color $color -Style $style -After ' '
    }
    else {
        ""
    }
}

function Get-ZCUserAndHost {
    $opts = $global:ZcmderOptions
    $values = [System.Collections.Generic.List[string]]::new()
    if ($opts.Components.Username) {
        $values.Add($env:USERNAME)
    }
    if ($opts.Components.Hostname) {
        $values.Add($env:COMPUTERNAME)
    }
    $s = ($values -join '@')
    New-ZCAnsiString $s -Color $opts.Colors.UserAndHost -Style $opts.Styles.UserAndHost -After ' '
}

function Get-ZCCwd {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin
    )

    $opts = $global:ZcmderOptions
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    $p = Get-ZCPath $path

    $prefix = ""
    $color = $global:ZcmderOptions.Colors.Cwd
    $style = $global:ZcmderOptions.Styles.Cwd
    if (!$IsAdmin -and (Test-ZCReadOnlyDir $path)) {
        $prefix = $opts.Strings.ReadOnlyPrefix
        $color = $opts.Colors.CwdReadOnly
    }
    New-ZCAnsiString "$prefix$p" -Color $color -Style $style -After ' '
}

function Get-ZCGitPrompt {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ZCGitInfo]$Info
    )

    if (!$Info.Dir) {
        return ""
    }
    $opts = $global:ZcmderOptions

    # get status modifiers from local changes
    $modifier = ""
    if ($Info.Changes) {
        $modifier += $opts.Strings.GitDirtyPostfix
    }
    # otherwise repo is clean, but don't show if in a new repo
    elseif ($Info.Label -ne $opts.Strings.GitLabelNew) {
        $modifier = $opts.Strings.GitCleanPostfix
    }
    # add stashed modifier
    if ($Info.Stashed) {
        $modifier += $opts.Strings.GitStashedModifier
    }

    # branch suffix from remote status
    $diverged = $Info.IsDiverged()
    $suffix = ""
    if ($diverged) {
        $suffix = $opts.Strings.GitDivergedPostfix
    } elseif ($Info.Ahead) {
        $suffix = $opts.Strings.GitAheadPostfix
    } elseif ($Info.Behind) {
        $suffix = $opts.Strings.GitBehindPostfix
    }

    # get color based on local or remote
    $color = if ($Info.Changes -and ($Info.Changes -eq $Info.Staged)) {
        $opts.Colors.GitStaged
    } elseif ($Info.Unmerged -or $diverged) {
        $opts.Colors.GitUnmerged
    } elseif ($Info.Untracked -gt 0) {
        $opts.Colors.GitUntracked
    } elseif ($Info.Modified -gt 0) {
        $opts.Colors.GitModified
    } elseif ($Info.IsNew) {
        $opts.Colors.GitNewRepo
    } else {
        $opts.Colors.GitBranchDefault
    }

    $remote = if ($Info.Remote) { ":" + $Info.Remote }
    $label = $opts.Strings.GitPrefix + $Info.Label
    $style = $opts.Styles.Info
    New-ZCAnsiString $label$remote$modifier$suffix -Color $color -Style $style -Before $opts.Strings.GitSeparator
}

function Get-ZCCaret {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin,
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $true)]
        [bool]$DollarQ
    )

    $opts = $global:ZcmderOptions

    # consider exit code (set by processes) and $? (set by cmdlets)
    $color = if ($ExitCode -eq 0 -and $DollarQ) {
        $opts.Colors.Caret
    } else {
        $opts.Colors.CaretError
    }
    $style = $opts.Styles.Caret
    $caret = if ($IsAdmin) { $opts.Strings.CaretAdmin } else { $opts.Strings.Caret }

    New-ZCAnsiString $caret -Color $color -Style $style -Before "`n" -After ' '
}

function Get-ZcmderPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin,
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $true)]
        [bool]$DollarQ
    )

    $opts = $global:ZcmderOptions
    $sb = [System.Text.StringBuilder]::new()

    if ($opts.NewlineBeforePrompt -and !$Host.UI.RawUI.CursorPosition.Y -eq 0) {
        [void]$sb.Append("`n")
    }
    if ($opts.Components.PythonEnv) {
        [void]$sb.Append((Get-ZCPythonEnv))
    }
    if ($opts.Components.Username -or $opts.Components.Hostname) {
        [void]$sb.Append((Get-ZCUserAndHost))
    }
    if ($opts.Components.Cwd) {
        [void]$sb.Append((Get-ZCCwd -IsAdmin:$IsAdmin))
    }
    if ($opts.Components.GitStatus) {
        [void]$sb.Append((Get-ZCGitPrompt (Get-ZCGitInfo)))
    }
    [void]$sb.Append((Get-ZCCaret -IsAdmin:$IsAdmin -ExitCode:$ExitCode -DollarQ:$DollarQ))
    $sb.ToString()
}
