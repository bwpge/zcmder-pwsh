function Format-ZCPropertyValue {
    param($value, $ty)

    if ($value -eq $null) {
        return '$null'
    }
    if (!$ty) {
        $ty = $value.GetType().Name
    }

    if ($ty -eq "TimeSpan") {
        "$($value.TotalMilliseconds) ms"
    } elseif ($ty -eq "String") {
        '"' + $value + '"'
    } else {
        $value
    }
}

function Get-ZCPropertyTable {
    param($obj, [string]$label)

    $table = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        $k = if ($label) { $label + '.' + $prop.Name } else { $prop.Name }
        if ($prop.Value -eq $null) {
            $table[$k] = '$null'
            continue
        }

        $ty = $prop.Value.GetType().Name
        if ($ty -eq "Hashtable" -or $ty.StartsWith("Dictionary")) {
            foreach ($item in $prop.Value.GetEnumerator()) {
                $key = if ($ty -eq "Hashtable") { "$k.$($item.Name)" } else { "$k.$($item.Key)" }
                $table[$key] = Format-ZCPropertyValue $item.Value
            }
            continue
        } elseif (($ty -eq "ZCOptions") -or ($ty -eq "ZCState") -or ($ty -eq "ZCGitStatus")) {
            Get-ZCPropertyTable $prop.Value $k
            continue
        }

        $v = Format-ZCPropertyValue $prop.Value $ty
        if ($ty -eq "TimeSpan") {
            $table["Times.$k"] = $v
        } else {
            $table[$k] = $v
        }
    }

    $table
}

function Merge-ZCPropertyTables {
    param([hashtable[]]$tables)

    $table = @{}
    foreach ($t in $tables) {
        foreach ($item in $t.GetEnumerator()) {
            $table[$item.Name] = $item.Value
        }
    }

    $table
}

function Write-ZCSortedTable {
    param([hashtable]$table)

    $table | %{
        $_.GetEnumerator() |
        Sort-Object -Property Name |
        Format-Table -AutoSize -HideTableHeaders -Wrap
    }
}

function Write-ZCDebugHeader {
    param([string]$header)

    $div = '-' * $header.Length
    Write-Host "$($header.ToUpper())`n$div" -Foreground DarkGreen
}

function Write-ZcmderDebugInfo {
    [CmdletBinding()]
    param()

    $exit_code = $global:LASTEXITCODE

    $begin = Get-Date
    $info = [ZCDebugInfo]::new()
    $info.Options = $global:ZcmderOptions
    $info.State = $global:ZcmderState

    Write-Host
    Write-ZCDebugHeader "Module info"
    Get-Module | ?{ $_.Name -eq "Zcmder" } | %{
        $mod_info = @{}
        $_ | Select-Object -Property Guid,Name,Version,ModuleBase,Path | %{
            $_.PSObject.Properties |
            %{ $mod_info[$_.Name] = $_.Value }
        }
        Write-ZCSortedTable $mod_info
        Write-Host
    }

    $start = Get-Date
    Set-ZCStateGitStatus
    $info.GitStatusUpdate = (Get-Date) - $start

    Write-ZCDebugHeader "Prompt output"
    Write-Host ">>>>>>>>>>"
    $start = Get-Date
    Write-ZcmderPrompt | Out-Null
    $info.PromptElapsed = (Get-Date) - $start
    Write-Host "`n<<<<<<<<<<`n"

    $info.DebugElapsed = (Get-Date) - $begin

    Write-ZCDebugHeader "Debug info"
    $table = Merge-ZCPropertyTables (Get-ZCPropertyTable $info)
    Write-ZCSortedTable $table

    $global:LASTEXITCODE = $exit_code
    $global:ZcmderState.ExitCode = $exit_code
}
