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
        } elseif ($ty -eq "ZCOptions" -or $ty -eq "ZCGitStatus") {
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
    param(
        [hashtable]$table,
        $Property=$null
    )

    $table | %{
        $_.GetEnumerator() |
        Sort-Object -Property Name |
        Format-Table -AutoSize -HideTableHeaders -Wrap -Property:$Property
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

    $dollar_q = $global:?
    $exit_code = $global:LASTEXITCODE
    $is_admin = Test-ZCIsAdmin
    $times = @{}

    Write-Host
    Write-ZCDebugHeader "Module info"
    Get-Module | ?{ $_.Name -eq "Zcmder" } | %{
        $info = @{}
        $_ | Select-Object -Property Guid,Name,Version,ModuleBase,Path | %{
            $_.PSObject.Properties |
            %{ $info[$_.Name] = $_.Value }
        }
        Write-ZCSortedTable $info
        Write-Host
    }

    Write-ZCDebugHeader "Prompt output"
    Write-Host "`n>>>>>>>>>>"
    $start = Get-Date
    Write-ZcmderPrompt -IsAdmin:$is_admin -ExitCode:$exit_code -DollarQ:$dollar_q | Out-Null
    $times["Total prompt time"] = (Get-Date) - $start
    Write-Host "`n<<<<<<<<<<`n"

    Write-ZCDebugHeader "Git Status"
    $start = Get-Date
    $git_status = Get-ZCGitStatus
    $times["Parse git status time"] = (Get-Date) - $start
    Write-ZCSortedTable (Get-ZCPropertyTable $git_status)

    Write-ZCDebugHeader "Options"
    $table = Merge-ZCPropertyTables (Get-ZCPropertyTable $global:ZcmderOptions)
    Write-ZCSortedTable $table

    Write-ZCDebugHeader "Stats"
    Write-ZCSortedTable $times -Property Name, @{label = "Elapsed"; e = {"$($_.Value.TotalMilliseconds) ms" }}

    $global:LASTEXITCODE = $exit_code
}
