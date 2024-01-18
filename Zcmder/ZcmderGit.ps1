function Invoke-ZCGit {
    git --no-optional-locks $args
}

function Get-ZCGitDir {
    $d = Invoke-ZCGit rev-parse --git-dir 2>$null
    if ($d) {
        Resolve-Path $d 2>$null
    }
}

function Set-ZCStateGitStatus {
    $opts = $global:ZcmderOptions
    $state = $global:ZcmderState
    $state.Git = [ZCGitStatus]::new()

    $state.Git.Dir = Get-ZCGitDir
    $state.Git.IsRepo = [bool]$state.Git.Dir

    if (!$state.Git.IsRepo) { return }

    # try and get current git label
    $label = Invoke-ZCGit rev-parse --abbrev-ref HEAD 2>$null
    if ($label -eq "HEAD") {
        $label = Invoke-ZCGit rev-parse --short HEAD
    }
    # check if a new repo
    if ([string]::IsNullOrEmpty($label)) {
        $label = "(new)"
    }
    $state.Git.Label = $label

    # set remote label (avoid git call if not needed)
    if ($opts.GitShowRemote) {
        $state.Git.Remote = Invoke-ZCGit rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
    } else {
        $state.Git.Remote = ""
    }

    # update status
    $status = Invoke-ZCGit status --porcelain -b 2>$null
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

    # check for any stashes
    # see: https://stackoverflow.com/a/53823705
    $state.Git.Stashed = [int](Invoke-ZCGit rev-list --walk-reflogs --count refs/stash 2>$null)
}
