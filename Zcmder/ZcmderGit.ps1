function Invoke-ZcmderGit {
    git --no-optional-locks $args
}

function Get-ZcmderGitDir {
    $d = Invoke-ZcmderGit rev-parse --git-dir 2>$null
    if ($d) {
        Resolve-Path $d 2>$null
    }
}

function Get-ZcmderGitAllStaged {
    Invoke-ZcmderGit diff --exit-code | Out-Null
    $diff = [bool]$LASTEXITCODE
    Invoke-ZcmderGit diff --cached --exit-code | Out-Null
    $cached = [bool]$LASTEXITCODE

    !$diff -and $cached
}

function Set-ZcmderStateGitStatus {
    $opts = $global:ZcmderOptions
    $state = $global:ZcmderState
    $state.Git = [ZCGitStatus]::new()

    $state.Git.Dir = Get-ZcmderGitDir
    $state.Git.IsRepo = [bool]$state.Git.Dir

    if (!$state.Git.IsRepo) { return }

    # try and get current git label
    $label = Invoke-ZcmderGit rev-parse --abbrev-ref HEAD 2>$null
    if ($label -eq "HEAD") {
        $label = Invoke-ZcmderGit rev-parse --short HEAD
    }
    # check if a new repo
    if ([string]::IsNullOrEmpty($label)) {
        $label = "(new)"
    }
    # otherwise use a branch/tag/commit sha
    else {
        ($label = Invoke-ZcmderGit symbolic-ref --short HEAD 2>$null) -or
        ($label = Invoke-ZcmderGit describe --tags --exact-match HEAD 2>$null) -or
        ($label = Invoke-ZcmderGit rev-parse --short HEAD 2>$null) | Out-Null
    }

    $state.Git.Label = $label

    # set remote label
    if ($opts.GitShowRemote) {
        $state.Git.Remote = Invoke-ZcmderGit rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
    } else {
        $state.Git.Remote = ""
    }

    # update status
    $status = Invoke-ZcmderGit status --porcelain -b 2>$null
    foreach ($line in $status) {
        if ($line.Length -lt 2) { continue }

        # check branch info, example:
        # ## foo...origin/bar [ahead 1, behind 1826735]
        if ($line.StartsWith("##")) {
            if (!($line -match '## .+\.\.\..+ \[(.*)\]')) {
                continue
            }
            $matches[1] -split ',\s*' | %{
                if (!($_ -match '(behind|diverged|ahead) (\d+)')) {
                    continue
                }
                if ($matches[1] -eq "ahead") {
                    $state.Git.Ahead += [int]$matches[2]
                } elseif ($matches[1] -eq "behind") {
                    $state.Git.Behind += [int]$matches[2]
                } elseif ($matches[1] -eq "diverged") {
                    $state.Git.Diverged += [int]$matches[2]
                }
            }
        } else {
            $state.Git.Changes++
            switch -regex ($line.Substring(0, 2)) {
                '\?.'     { $state.Git.Untracked++ }
                'U.'      { $state.Git.Unmerged++ }
                '(.M| .)' { $state.Git.Modified++ }
                default   { $state.Git.Staged++ }
            }
        }
    }

    # count changes between local and remote
    # $ahead_behind = -split (Invoke-ZcmderGit rev-list --left-right --count "$label...@{upstream}" 2>$null)
    # if ($ahead_behind.Length -eq 2) {
    #     $state.Git.Ahead = [int]$ahead_behind[0]
    #     $state.Git.Behind = [int]$ahead_behind[1]
    # } else {
    #     $state.Git.Ahead = 0
    #     $state.Git.Behind = 0
    # }
    # $state.Git.Diverged = ($state.Git.Ahead -gt 0) -and ($state.Git.Behind -gt 0)

    # check for any stashes
    # see: https://stackoverflow.com/a/53823705
    $state.Git.Stashed = [int](Invoke-ZcmderGit rev-list --walk-reflogs --count refs/stash 2>$null)

    # check if all changes are staged
    # $state.Git.AllStaged = Get-ZcmderGitAllStaged
}
