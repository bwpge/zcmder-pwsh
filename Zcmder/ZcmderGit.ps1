function Invoke-ZCGit {
    git --no-optional-locks $args
}

function Get-ZCGitDir {
    $d = Invoke-ZCGit rev-parse --git-dir 2>$null
    if ($d) {
        Resolve-Path $d 2>$null
    }
}

function Get-ZCGitStatus {
    $opts = $global:ZcmderOptions
    $state = [ZCGitStatus]::new()
    $state.Dir = Get-ZCGitDir
    $state.IsRepo = [bool]$state.Dir
    $state.IsNew = $false

    if (!$state.IsRepo) { return $state }

    # try and get current git label
    $label = Invoke-ZCGit rev-parse --abbrev-ref HEAD 2>$null
    if ($label -eq "HEAD") {
        $label = Invoke-ZCGit rev-parse --short HEAD 2>$null
    }
    # check if a new repo
    if ([string]::IsNullOrEmpty($label)) {
        $label = $opts.Strings.GitLabelNew
        $state.IsNew = $true
    }
    $state.Label = $label

    # set remote label (avoid git call if not needed)
    if ($opts.GitShowRemote) {
        $state.Remote = Invoke-ZCGit rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
    } else {
        $state.Remote = ""
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
                    $state.Ahead += [int]$matches[2]
                } elseif ($matches[1] -eq "behind") {
                    $state.Behind += [int]$matches[2]
                } elseif ($matches[1] -eq "diverged") {
                    $state.Diverged += [int]$matches[2]
                }
            }
        } else {
            $state.Changes++
            switch -regex ($line.Substring(0, 2)) {
                '\?.'     { $state.Untracked++ }
                'U.'      { $state.Unmerged++ }
                '(.M| .)' { $state.Modified++ }
                default   { $state.Staged++ }
            }
        }
    }

    # check for any stashes
    # see: https://stackoverflow.com/a/53823705
    $state.Stashed = [int](Invoke-ZCGit rev-list --walk-reflogs --count refs/stash 2>$null)

    return $state
}
