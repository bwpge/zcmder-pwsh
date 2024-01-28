# this function uses beatcracker/Powershell-Misc as a reference for implementation
# see: https://github.com/beatcracker/Powershell-Misc/blob/master/Write-Host.ps1
function New-ZCAnsiString {
    param(
        [Parameter(
            Position=0,
            ValueFromPipeline=$true,
            ValueFromRemainingArguments=$true
        )]
        [Alias('Msg', 'Message')]
        [System.Object[]]$Object,
        [AllowNull()]
        [ZCColor]$Color,
        [AllowNull()]
        [ZCStyle]$Style,
        [switch]$NoNewline,
        [System.Object]$Prefix,
        [System.Object]$Suffix
    )

    begin {
        $esc = [char]27
        $reset = "$esc[0m"
    }

    process {
        if (!$Host.UI.SupportsVirtualTerminal -or (!$Color -and !$Style)) {
            "$Prefix$Object$Suffix"
        } else {
            $c = if ($Color) { $Color.ToAnsiString() } else { "" }
            $s = if ($Style) { $Style.ToAnsiString() } else { "" }
            "$Prefix$s$c$Object$reset$Suffix"
        }
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
        New-ZCAnsiString "$py" -Color $color -Style $style -Suffix ' '
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
    New-ZCAnsiString $s -Color $opts.Colors.UserAndHost -Style $opts.Styles.UserAndHost -Suffix ' '
}

function Get-ZCCwd {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin
    )

    $opts = $global:ZcmderOptions
    $path = $ExecutionContext.SessionState.Path.CurrentLocation
    $p = Write-ZCPath $path

    $prefix = ""
    $color = $global:ZcmderOptions.Colors.Cwd
    $style = $global:ZcmderOptions.Styles.Cwd
    if (!$IsAdmin -and (Test-IsReadOnlyDir $path)) {
        $prefix = $opts.Strings.ReadOnlyPrefix
        $color = $opts.Colors.CwdReadOnly
    }
    New-ZCAnsiString "$prefix$p" -Color $color -Style $style -Suffix ' '
}

function Get-ZCGitPrompt {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ZCGitStatus]$GitStatus
    )

    if (!$GitStatus.IsRepo) {
        return ""
    }
    $opts = $global:ZcmderOptions

    # get status modifiers from local changes
    $modifier = ""
    if ($GitStatus.Changes) {
        $modifier += $opts.Strings.GitDirtyPostfix
    }
    # otherwise repo is clean, but don't show if in a new repo
    elseif ($GitStatus.Label -ne $opts.Strings.GitLabelNew) {
        $modifier = $opts.Strings.GitCleanPostfix
    }
    # add stashed modifier
    if ($GitStatus.Stashed) {
        $modifier += $opts.Strings.GitStashedModifier
    }

    # branch suffix from remote status
    $diverged = $GitStatus.IsDiverged()
    $suffix = ""
    if ($diverged) {
        $suffix = $opts.Strings.GitDivergedPostfix
    } elseif ($GitStatus.Ahead) {
        $suffix = $opts.Strings.GitAheadPostfix
    } elseif ($GitStatus.Behind) {
        $suffix = $opts.Strings.GitBehindPostfix
    }

    # get color based on local or remote
    $color = if ($GitStatus.Changes -and ($GitStatus.Changes -eq $GitStatus.Staged)) {
        $opts.Colors.GitStaged
    } elseif ($GitStatus.Unmerged -or $diverged) {
        $opts.Colors.GitUnmerged
    } elseif ($GitStatus.Untracked -gt 0) {
        $opts.Colors.GitUntracked
    } elseif ($GitStatus.Modified -gt 0) {
        $opts.Colors.GitModified
    } elseif ($GitStatus.IsNew) {
        $opts.Colors.GitNewRepo
    } else {
        $opts.Colors.GitBranchDefault
    }

    $remote = if ($GitStatus.Remote) { ":" + $GitStatus.Remote }
    $label = $opts.Strings.GitPrefix + $GitStatus.Label
    $style = $opts.Styles.GitStatus
    New-ZCAnsiString $label$remote$modifier$suffix -NoNewline -Color $color -Style $style -Prefix $opts.Strings.GitSeparator
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

    New-ZCAnsiString $caret -Color $color -Style $style -Prefix "`n" -Suffix ' '
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
        [void]$sb.Append((Get-ZCGitPrompt (Get-ZCGitStatus)))
    }
    [void]$sb.Append((Get-ZCCaret -IsAdmin:$IsAdmin -ExitCode:$ExitCode -DollarQ:$DollarQ))
    $sb.ToString()
}
