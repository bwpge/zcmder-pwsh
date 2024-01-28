function Measure-ZCCommandWithOutput {
    param([scriptblock]$Block)

    $start = Get-Date
    $output = $Block.Invoke()
    $elapsed = (Get-Date) - $start

    @{
        Elapsed = $elapsed.TotalMilliseconds
        Output = $output
    }
}

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
    $prompt_cmd = Measure-ZCCommandWithOutput { Get-ZcmderPrompt -IsAdmin:$is_admin -ExitCode:$exit_code -DollarQ:$dollar_q }
    $times["Render full prompt"] = $prompt_cmd.Elapsed
    Write-Host "`n>>>>>>>>>>"
    Write-Host ($prompt_cmd.Output  -replace ([char]27),'\x1b')
    Write-Host "<<<<<<<<<<`n"

    Write-ZCDebugHeader "Git Status"
    $git_status_cmd = Measure-ZCCommandWithOutput { Get-ZCGitStatus }
    $times["Parse git status"] = $git_status_cmd.Elapsed
    Write-ZCSortedTable (Get-ZCPropertyTable $git_status_cmd.Output[0])

    Write-ZCDebugHeader "Options"
    $table = Merge-ZCPropertyTables (Get-ZCPropertyTable $global:ZcmderOptions)
    Write-ZCSortedTable $table

    $commands = @{
        "Render component: python env" = { Get-ZCPythonEnv }
        "Render component: user and host" = { Get-ZCUserAndHost }
        "Render component: cwd" = { Get-ZCCwd -IsAdmin:$is_admin }
        "Render component: git status" = { Get-ZCGitPrompt -GitStatus:$git_status_cmd.Output[0] }
        "Render component: caret" = { Get-ZCCaret -IsAdmin:$is_admin -ExitCode:$exit_code -DollarQ:$dollar_q }
    }
    foreach ($item in $commands.GetEnumerator()) {
        $times[$item.Name] = (Measure-ZCCommandWithOutput $item.Value).Elapsed
    }
    Write-ZCDebugHeader "Stats"
    Write-ZCSortedTable $times -Property Name, @{label = "Elapsed"; e = {"$($_.Value) ms" }}

    $global:LASTEXITCODE = $exit_code
}
