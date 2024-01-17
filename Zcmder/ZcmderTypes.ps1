class ZCOptions {
    [bool]$UnixPathStyle = $true
    [bool]$NewlineAfterCmd = $true
    [bool]$GitShowRemote = $false
    [bool]$DeferPromptWrite = $false

    [hashtable]$Components = @{
        Cwd = $true
        GitStatus = $true
        Hostname = $false
        PythonEnv = $true
        Username = $false
    }

    [hashtable]$Strings = @{
        Caret               = "λ"
        CaretAdmin          = "#"
        GitAheadPostfix     = " ↑"
        GitBehindPostfix    = " ↓"
        GitBranchIcon       = " "
        GitLabelNew          = "(new)"
        GitCleanPostfix     = " ✓"
        GitDirtyPostfix     = " *"
        GitDivergedPostfix  = " ↑↓"
        GitPostfix          = ""
        GitPrefix           = " on "
        GitStashedModifier  = " ⚑"
    }

    [hashtable]$Colors = @{
        Caret               = "DarkGray"
        CaretError          = "DarkRed"
        Cwd                 = "DarkGreen"
        CwdReadOnly         = "DarkRed"
        GitBranchDefault    = "DarkCyan"
        GitModified         = "DarkYellow"
        GitNewRepo          = "DarkGray"
        GitStaged           = "DarkBlue"
        GitUnmerged         = "DarkMagenta"
        GitUntracked        = "DarkRed"
        Hostname            = "DarkBlue"
        PythonEnv           = "DarkGray"
        Username            = "DarkBlue"
    }
}

class ZCGitStatus {
    [int]$Ahead = 0
    [int]$Behind = 0
    [int]$Changes = 0
    [int]$Diverged = 0
    [int]$Untracked = 0
    [int]$Unmerged = 0
    [int]$Modified = 0
    [string]$Label = ""
    [string]$Remote = ""
    $Dir = $null
    [int]$Stashed = 0
    [int]$Staged = 0
    [bool]$IsRepo = $false

    [bool] IsDiverged() {
        return ([bool]$this.Diverged) -or (($this.Ahead -gt 0) -and ($this.Behind -gt 0))
    }
}

class ZCState {
    $ExitCode = 0
    $IsAdmin = $false
    [ZCGitStatus]$Git = [ZCGitStatus]::new()
}
