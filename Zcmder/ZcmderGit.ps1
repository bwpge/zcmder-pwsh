function Invoke-ZCGit {
    git --no-optional-locks @args
}

function Get-ZCGitDir {
    $d = Invoke-ZCGit rev-parse --git-dir 2>$null
    if ($d) {
        Resolve-Path $d 2>$null
    }
}

function Get-ZCGitInfo {
    $opts = $global:ZcmderOptions
    $info = [ZCGitInfo]::new()
    $info.Dir = Get-ZCGitDir

    if (!$info.Dir) { return $info }

    # try and get current git label
    $label = Invoke-ZCGit rev-parse --abbrev-ref HEAD 2>$null
    if ($label -eq "HEAD") {
        $label = Invoke-ZCGit rev-parse --short HEAD 2>$null
    }
    # check if a new repo
    if ([string]::IsNullOrEmpty($label)) {
        $label = $opts.Strings.GitLabelNew
        $info.IsNew = $true
    }
    $info.Label = $label

    # set remote label (avoid git call if not needed)
    if ($opts.GitShowRemote) {
        $info.Remote = Invoke-ZCGit rev-parse --abbrev-ref --symbolic-full-name "@{upstream}" 2>$null
    } else {
        $info.Remote = ""
    }

    # update status
    $git_status = Invoke-ZCGit status --porcelain -b 2>$null
    foreach ($line in $git_status) {
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
                    $info.Ahead += [int]$matches[2]
                } elseif ($matches[1] -eq "behind") {
                    $info.Behind += [int]$matches[2]
                } elseif ($matches[1] -eq "diverged") {
                    $info.Diverged += [int]$matches[2]
                }
            }
        } else {
            $info.Changes++
            switch -regex ($line.Substring(0, 2)) {
                '\?.'     { $info.Untracked++ }
                'U.'      { $info.Unmerged++ }
                '(.M| .)' { $info.Modified++ }
                default   { $info.Staged++ }
            }
        }
    }

    # check for any stashes
    # see: https://stackoverflow.com/a/53823705
    $info.Stashed = [int](Invoke-ZCGit rev-list --walk-reflogs --count refs/stash 2>$null)

    $info
}
