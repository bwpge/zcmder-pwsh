enum ZCColorType {
    None
    Integer
    Rgb
}

class ZCBaseColor {
    [PSObject]$Value = $null
    [ZCColorType]$Kind = [ZCColorType]::None

    ZCBaseColor() {}

    ZCBaseColor([System.ConsoleColor]$val) {
        $this.Value = Convert-ZCConsoleTo256Color $val
        $this.Kind = [ZCColorType]::Integer
    }

    ZCBaseColor([string]$val) {
        # try getting a ConsoleColor by name
        if ($color = Get-ZCConsoleColor $val) {
            $this.Value = Convert-ZCConsoleTo256Color $color
            $this.Kind = [ZCColorType]::Integer
        }
        # try matching RGB string
        elseif ($val -match '#([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})') {
            $this.Value = [System.Collections.Generic.List[string]]::new()
            $this.Value.Add([convert]::ToInt32($matches[1], 16)) # r
            $this.Value.Add([convert]::ToInt32($matches[2], 16)) # g
            $this.Value.Add([convert]::ToInt32($matches[3], 16)) # b
            $this.Kind = [ZCColorType]::Rgb
        }
        # unknown color string
        else {
            throw "'$val' is not a valid color"
        }
    }

    ZCBaseColor([int]$val) {
        if ($val -gt 255 -or $val -lt 0) {
            throw "Integer colors must be in the range 0-255"
        }
        $this.Value = $val
        $this.Kind = [ZCColorType]::Integer
    }

    [System.Collections.Generic.List[string]] GetAnsiSeq() {
        $result = [System.Collections.Generic.List[string]]::new()
        switch ($this.Kind) {
            ([ZCColorType]::Integer) {
                $result += '5'
                $result += $this.Value
            }
            ([ZCColorType]::Rgb) {
                $result += '2'
                $result += $this.Value
            }
            default {}
        }

        return $result
    }

    hidden [string] ToString() {
        $s = "ZCColor::{0}"
        $result = switch ($this.Kind) {
            ([ZCColorType]::None) { $this.Kind }
            ([ZCColorType]::Rgb) {
                $val = $this.Value -join ','
                "$($this.Kind)($val)"
            }
            default {
                "$($this.Kind)($($this.Value))"
            }
        }
        return $result
    }
}

class ZCColor {
    [ZCBaseColor]$Foreground
    [ZCBaseColor]$Background

    ZCColor() {
        $this.Foreground = [ZCBaseColor]::new()
        $this.Background = [ZCBaseColor]::new()
    }

    ZCColor([string]$fg) {
        $this.Foreground = [ZCBaseColor]::new($fg)
        $this.Background = [ZCBaseColor]::new()
    }

    ZCColor([string]$fg, [string]$bg) {
        $this.Foreground = [ZCBaseColor]::new($fg)
        $this.Background = [ZCBaseColor]::new($bg)
    }

    [string] ToAnsiString() {
        if (!$this.Foreground.Value -and !$this.Background.Value) {
            return ""
        }

        $esc = [char]27
        $ansi_fmt = "$esc[{0}m"
        $fg = [System.Collections.Generic.List[string]]::new()
        $bg = [System.Collections.Generic.List[string]]::new()

        if ($this.Foreground) {
            $fg.Add('38')
            $fg += $this.Foreground.GetAnsiSeq()
        }
        if ($this.Background) {
            $bg.Add('48')
            $bg += $this.Background.GetAnsiSeq()
        }
        $fg = ($ansi_fmt -f ($fg -join ';'))
        $bg = ($ansi_fmt -f ($bg -join ';'))

        return "$fg$bg"
    }
}

# the dictionary constructor doesn't take a hashtable with values, so we have
# to create it here outside the constructor
function Get-ZCColorDict {
    $dict = [System.Collections.Generic.Dictionary[String, ZCColor]]::new()
    $dict.Caret            = "DarkGray"
    $dict.CaretError       = "DarkRed"
    $dict.Cwd              = "DarkGreen"
    $dict.CwdReadOnly      = "DarkRed"
    $dict.GitBranchDefault = "DarkCyan"
    $dict.GitModified      = "DarkYellow"
    $dict.GitNewRepo       = "DarkGray"
    $dict.GitStaged        = "DarkBlue"
    $dict.GitUnmerged      = "DarkMagenta"
    $dict.GitUntracked     = "DarkRed"
    $dict.PythonEnv        = "DarkGray"
    $dict.UserAndHost      = "DarkBlue"
    $dict
}

class ZCOptions {
    [bool]$DeferPromptWrite = $false
    [bool]$GitShowRemote = $false
    [bool]$NewlineBeforePrompt = $true
    [bool]$UnixPathStyle = $true

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
        GitCleanPostfix     = " ✓"
        GitDirtyPostfix     = " *"
        GitDivergedPostfix  = " ↑↓"
        GitLabelNew         = "(new)"
        GitPostfix          = ""
        GitPrefix           = " "
        GitSeparator        = " on "
        GitStashedModifier  = " ⚑"
        ReadOnlyPrefix      = " "
    }

    [System.Collections.Generic.Dictionary[String, ZCColor]]$Colors = (Get-ZCColorDict)
}

class ZCGitStatus {
    [int]$Ahead = 0
    [int]$Behind = 0
    [int]$Changes = 0
    [int]$Diverged = 0
    [int]$Untracked = 0
    [int]$Unmerged = 0
    [int]$Modified = 0
    [int]$Stashed = 0
    [int]$Staged = 0
    [string]$Label = ""
    [string]$Remote = ""
    $Dir = $null
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

class ZCDebugInfo {
    [ZCOptions]$Options
    [ZCState]$State
    [TimeSpan]$GitStatusUpdate
    [TimeSpan]$PromptElapsed
    [TimeSpan]$DebugElapsed
}
