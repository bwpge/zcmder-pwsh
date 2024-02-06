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
                $result.Add('5')
                $result.Add($this.Value)
            }
            ([ZCColorType]::Rgb) {
                $result.Add('2')
                $result.AddRange($this.Value)
            }
            default {}
        }

        return $result
    }

    [string] ToString() {
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

    [string] ToString() {
        return "{fg=$($this.Foreground), bg=$($this.Background)}"
    }

    [string] ToAnsiString() {
        if (!$this.Foreground.Value -and !$this.Background.Value) {
            return ""
        }

        $esc = [char]27
        $ansi_fmt = "$esc[{0}m"
        $fg = [System.Collections.Generic.List[string]]::new()
        $bg = [System.Collections.Generic.List[string]]::new()

        if ($this.Foreground -and $this.Foreground.Kind -ne [ZCColorType]::None) {
            $fg.Add('38')
            $fg.AddRange($this.Foreground.GetAnsiSeq())
        }
        if ($this.Background -and $this.Background.Kind -ne [ZCColorType]::None) {
            $bg.Add('48')
            $bg.AddRange($this.Background.GetAnsiSeq())
        }
        $fg = if ($fg) { ($ansi_fmt -f ($fg -join ';')) } else { "" }
        $bg = if ($bg) { ($ansi_fmt -f ($bg -join ';')) } else { "" }

        return "$fg$bg"
    }
}

class ZCStyle {
    [bool]$Bold = $false
    [bool]$Dim = $false
    [bool]$Italic = $false
    [bool]$Underline = $false
    [bool]$Invert = $false

    ZCStyle() {}

    ZCStyle(
        [bool]$bold,
        [bool]$dim,
        [bool]$italic,
        [bool]$underline,
        [bool]$invert
    ) {
        $this.Bold = $bold
        $this.Dim = $dim
        $this.Italic = $italic
        $this.Underline = $underline
        $this.Invert = $invert
    }

    [string] ToString() {
        return "{bold=$($this.Bold), dim=$($this.Dim), italic=$($this.Italic), underline=$($this.Underline), invert=$($this.Invert)}"
    }

    [string] ToAnsiString() {
        $esc = [char]27
        $ansi_fmt = "$esc[{0}m"
        $s = ''

        # invert needs to be first
        if ($this.Invert) {
            $s += ($ansi_fmt -f '7')
        }
        if ($this.Bold) {
            $s += ($ansi_fmt -f '1')
        }
        if ($this.Dim) {
            $s += ($ansi_fmt -f '2')
        }
        if ($this.Italic) {
            $s += ($ansi_fmt -f '3')
        }
        if ($this.Underline) {
            $s += ($ansi_fmt -f '4')
        }

        return $s
    }
}

class ZCOptions {
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
        GitPrefix           = " "
        GitSeparator        = "on "
        GitStashedModifier  = " ⚑"
        ReadOnlyPrefix      = " "
    }

    [System.Collections.Generic.Dictionary[String, ZCColor]]$Colors = (New-ZCDict -KeyType:([string]) -ValueType:([ZCColor]) @{
        Caret            = "DarkGray"
        CaretError       = "DarkRed"
        Cwd              = "DarkGreen"
        CwdReadOnly      = "DarkRed"
        GitBranchDefault = "DarkCyan"
        GitModified      = "DarkYellow"
        GitNewRepo       = "DarkGray"
        GitStaged        = "DarkBlue"
        GitUnmerged      = "DarkMagenta"
        GitUntracked     = "DarkRed"
        PythonEnv        = "DarkGray"
        UserAndHost      = "DarkBlue"
    })

    [System.Collections.Generic.Dictionary[String, ZCStyle]]$Styles = (New-ZCDict -KeyType:([string]) -ValueType:([ZCStyle]) @{
        Caret = [ZCStyle]::new()
        Cwd = [ZCStyle]::new()
        GitStatus = [ZCStyle]::new()
        PythonEnv = [ZCStyle]::new()
        UserAndHost = [ZCStyle]::new()
    })
}

class ZCGitInfo {
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
    [bool]$IsNew = $false

    [bool] IsDiverged() {
        return ([bool]$this.Diverged) -or (($this.Ahead -gt 0) -and ($this.Behind -gt 0))
    }
}
