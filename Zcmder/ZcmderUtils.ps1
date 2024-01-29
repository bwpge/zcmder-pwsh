function Get-ZCCurrentPrompt {
    if ($current = Get-Command prompt -ErrorAction SilentlyContinue) {
        $current.Definition
    } else {
        [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.Commands['prompt'].Definition
    }
}

function Test-ZCIsAdmin {
    (New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-ZCReadOnlyDir {
    param(
        [ValidateScript({Test-Path $path -PathType Container})]
        $path
    )

    # see: https://stackoverflow.com/a/34180361/
    $modify = [System.Security.AccessControl.FileSystemRights]::Modify -as [int]
    $write = [System.Security.AccessControl.FileSystemRights]::Write -as [int]
    $acl = (Get-Acl $path).Access | Where-Object {
        ($_.FileSystemRights -band $modify) -eq $modify -or
        ($_.FileSystemRights -band $write) -eq $write -and
        (
            $_.IdentityReference -eq "$(whoami)" -or
            $_.IdentityReference -eq "BUILTIN\Users" -or
            $_.IdentityReference -eq "NT AUTHORITY\Authenticated Users"
        )
    }

    @($acl).Length -eq 0
}

function Get-ZCPath([string]$path) {
    $result = $path
    if ($global:ZcmderOptions.UnixPathStyle) {
        $home_path = $env:USERPROFILE  # $HOME might not be set
        $result = switch -Wildcard ($path) {
            "$home_path"    { "~" }
            "$home_path\*"  { $path.Replace($home_path, "~") }
            default         { $path }
        }

        $result = $result -creplace "^$env:HOMEDRIVE",'' -replace '\\','/'
    }

    $result
}

function Remove-ZCVariable($name) {
    if (Test-Path "variable:global:$name" 2>$null) {
        Remove-Variable -Name $name -Scope Global -EA 0
    }
}

function Get-ZCConsoleColor([string]$value) {
    # avoid "partial" matching that .NET does (e.g., "blu" will match "Blue")
    [enum]::GetValues([System.ConsoleColor]) | %{
        if ($value -eq $_.ToString()) {
            return $_
        }
    }
}

function Convert-ZCConsoleTo256Color {
    param([ConsoleColor]$color)

    # of course windows always has to have some goofy way of doing things.
    # instead of just using normal X11 colors like "red" and "bright red",
    # we have to use confusing colors like "DarkGray" to mean "bright black"
    # and "Gray" to mean "white".
    # see:
    #   - https://i.stack.imgur.com/KTSQa.png
    #   - https://unix.stackexchange.com/a/105578
    switch ($color) {
        # standard colors
        ([ConsoleColor]::Black)       { 0 }
        ([ConsoleColor]::DarkRed)     { 1 }
        ([ConsoleColor]::DarkGreen)   { 2 }
        ([ConsoleColor]::DarkYellow)  { 3 }
        ([ConsoleColor]::DarkBlue)    { 4 }
        ([ConsoleColor]::DarkMagenta) { 5 }
        ([ConsoleColor]::DarkCyan)    { 6 }
        ([ConsoleColor]::Gray)        { 7 }
        # high-intensity colors
        ([ConsoleColor]::DarkGray)    { 8 }
        ([ConsoleColor]::Red)         { 9 }
        ([ConsoleColor]::Green)       { 10 }
        ([ConsoleColor]::Yellow)      { 11 }
        ([ConsoleColor]::Blue)        { 12 }
        ([ConsoleColor]::Magenta)     { 13 }
        ([ConsoleColor]::Cyan)        { 14 }
        ([ConsoleColor]::White)       { 15 }
    }
}

# the dictionary constructor doesn't handle hashtables, so this function is
# a hacky way to create one given a key-type and value-type
function New-ZCDict {
    param(
        [type]$KeyType = [string],
        [type]$ValueType,
        [hashtable]$values
    )

    $dict = New-Object ('System.Collections.Generic.Dictionary[{0}, {1}]' -f $KeyType, $ValueType)
    foreach ($item in $values.GetEnumerator()) {
        $dict[$item.Name] = $item.Value
    }
    $dict
}

<#
.SYNOPSIS
    Creates a new style.
.DESCRIPTION
    Simplifies setting effect flags (bold, italic, etc.) on a style option
    ($ZcmderOptions.Styles). If a switch is provided, the effect is enabled.
    Otherwise it is disabled.
.INPUTS
    None
.OUTPUTS
    ZCStyle
.EXAMPLE
    $ZcmderOptions.Styles.Cwd = New-ZCStyle -Bold -Invert
    Sets cwd component to a style with bold/invert effects.
.EXAMPLE
    $ZcmderOptions.Styles.Caret = New-ZCStyle
    Disable all effects on the caret component.
#>
function New-ZCStyle {
    param(
        [switch]$Bold,
        [switch]$Dim,
        [switch]$Italic,
        [switch]$Underline,
        [switch]$Invert
    )

    [ZCStyle]::new($Bold, $Dim, $Italic, $Underline, $Invert)
}
