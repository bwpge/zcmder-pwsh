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

function Test-IsReadOnlyDir {
    param($path)

    if (-not $(Test-Path $path) -or -not $(Test-Path $path -PathType Container)) {
        return $false
    }

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

function Write-ZCPath {
    param ([string]$path)

    $result = $path
    if ($global:ZcmderOptions.UnixPathStyle) {
        $home_path = $env:USERPROFILE  # $HOME might not be set
        $root_drive = $env:HOMEDRIVE

        $result = switch -Wildcard ($path) {
            "$home_path"    { "~" }
            "$home_path\*"  { $path.Replace($home_path, "~") }
            default         { $path }
        }

        $result = $result -creplace "^$root_drive"
        $result = $result.Replace("\", "/")
    }

    $result
}

function Test-ZCCmdExists {
    param ($command)
    $original = $ErrorActionPreference
    $ErrorActionPreference = "Stop"

    try {
        if (Get-Command $command) { return $true }
    } catch {
    } finally {
        $ErrorActionPreference = $original
    }

    $false
}

function Remove-ZCVariable {
    param($name)

    if (Get-Variable -Scope Global $name 2>$null) {
        Remove-Variable -Name $name -Scope Global -EA 0
    }
}

function Get-ZCConsoleColor {
    param([string]$value)

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
