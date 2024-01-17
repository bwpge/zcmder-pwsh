function Get-CurrentPrompt {
    if ($current = Get-Command prompt -ErrorAction SilentlyContinue) {
        $current.Definition
    } else {
        [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.InitialSessionState.Commands['prompt'].Definition
    }
}

function Test-ZcmderIsAdmin {
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

function Write-ZcmderPath {
    param ($path)

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

function Test-ZcmderCmdExists {
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
