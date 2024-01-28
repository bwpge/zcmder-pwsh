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
        [AllowNull()]
        [ZCStyle]$Style,
        [switch]$NoNewline,
        [System.Object]$Prefix,
        [System.Object]$Suffix
    )

    # see: https://en.wikipedia.org/wiki/ANSI_escape_code
    begin {
        $esc = [char]27
        $ansi_fmt = "$esc[{0}m"
        $reset = $ansi_fmt -f '0'
    }

    process {
        $PSBoundParameters.Remove("Color")
        $PSBoundParameters.Remove("Style")
        $PSBoundParameters.Remove("Prefix")
        $PSBoundParameters.Remove("Suffix")
        if (!$Color -and !$Style) {
            Write-Host @PSBoundParameters
            return
        }
        $PSBoundParameters.Remove("Object")

        $c = if ($Color) { $Color.ToAnsiString() } else { "" }
        $s = if ($Style) { $Style.ToAnsiString() } else { "" }
        Write-Host "$Prefix$s$c$Object$reset$Suffix" @PSBoundParameters
    }
}

function Write-ZCPythonEnv {
    $py = if (Test-Path env:CONDA_PROMPT_MODIFIER) {
        ($env:CONDA_PROMPT_MODIFIER).Trim()
    } elseif (Test-Path env:VIRTUAL_ENV) {
        "($($(Get-Item $env:VIRTUAL_ENV).Basename))"
    }
    if ($py) {
        $color = $global:ZcmderOptions.Colors.PythonEnv
        $style = $global:ZcmderOptions.Styles.PythonEnv
        Write-ZCHost "$py" -NoNewline -Color $color -Style $style -Suffix ' '
    }
}

function Write-ZCUserAndHost {
    $opts = $global:ZcmderOptions
    $values = [System.Collections.Generic.List[string]]::new()
    if ($opts.Components.Username) {
        $values.Add($env:USERNAME)
    }
    if ($opts.Components.Hostname) {
        $values.Add($env:COMPUTERNAME)
    }
    $s = ($values -join '@')
    Write-ZCHost $s -NoNewline -Color $opts.Colors.UserAndHost -Style $opts.Styles.UserAndHost -Suffix ' '
}

function Write-ZCCwd {
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
    Write-ZCHost "$prefix$p" -NoNewline -Color $color -Style $style -Suffix ' '
}

function Write-ZCGitStatus {
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [ZCGitStatus]$GitStatus
    )

    $opts = $global:ZcmderOptions
    if (!$GitStatus.IsRepo) {
        return
    }

    Write-ZCHost $opts.Strings.GitSeparator -NoNewline

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
    Write-ZCHost $label$remote$modifier$suffix -NoNewline -Color $color -Style $style
}

function Write-ZCCaret {
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

    # avoid rendering caret background across lines depending on terminal emulator
    Write-Host
    Write-ZCHost "$caret" -NoNewline -Color $color -Style $style
}

function Write-ZcmderPrompt {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$IsAdmin,
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $true)]
        [bool]$DollarQ
    )

    $opts = $global:ZcmderOptions
    $git_status = $null

    # if set, update git status first to avoid choppy printing
    if ($opts.DeferPromptWrite -and $opts.Components.GitStatus) {
        $git_status = Get-ZCGitStatus
    }
    # new line before prompt if not at top row
    if ($opts.NewlineBeforePrompt -and !$Host.UI.RawUI.CursorPosition.Y -eq 0) {
        Write-Host
    }
    if ($opts.Components.PythonEnv) {
        Write-ZCPythonEnv
    }
    if ($opts.Components.Username -or $opts.Components.Hostname) {
        Write-ZCUserAndHost
    }
    if ($opts.Components.Cwd) {
        Write-ZCCwd -IsAdmin:$IsAdmin
    }
    if ($opts.Components.GitStatus) {
        if (!$git_status) {
            $git_status = Get-ZCGitStatus
        }
        Write-ZCGitStatus $git_status
    }
    Write-ZCCaret -IsAdmin:$IsAdmin -ExitCode:$ExitCode -DollarQ:$DollarQ
}
