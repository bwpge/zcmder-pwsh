function Get-PropertyTable {
    param($obj, [string]$label)

    $table = @{}
    foreach ($prop in $obj.PSObject.Properties) {
        $k = if ($label) { $label + '.' + $prop.Name } else { $prop.Name }
        if ($prop.Value -eq $null) {
            $table[$k] = '$null'
            continue
        }
        $ty = $prop.Value.GetType().Name

        if ($ty -eq "Hashtable") {
            foreach ($item in $prop.Value.GetEnumerator()) {
                $key = "$k.$($item.Name)"
                $table[$key] = $item.Value
            }
            continue
        } elseif (($ty -eq "ZCOptions") -or ($ty -eq "ZCState") -or ($ty -eq "ZCGitStatus")) {
            Get-PropertyTable $prop.Value $k
            continue
        }

        if ($ty -eq "TimeSpan") {
            $table["Times.$k"] = "$($prop.Value.TotalMilliseconds) ms"
        } elseif ($ty -eq "String") {
            $table[$k] = "'" + $prop.Value + "'"
        }
        else {
            $table[$k] = $prop.Value
        }
    }

    $table
}

function Merge-PropertyTables {
    param([hashtable[]]$tables)

    $table = @{}
    foreach ($t in $tables) {
        foreach ($item in $t.GetEnumerator()) {
            $table[$item.Name] = $item.Value
        }
    }

    $table
}

function Write-ZcmderDebugInfo {
    [CmdletBinding()]
    param()


    $begin = Get-Date

    $info = [ZCDebugInfo]::new()
    $info.Options = $global:ZcmderOptions
    $info.State = $global:ZcmderState

    $start = Get-Date
    Set-ZcmderStateGitStatus
    $info.GitStatusUpdate = (Get-Date) - $start

    Write-Host "Prompt output:`n>>>>>>>>>>"
    $start = Get-Date
    Write-ZcmderPrompt
    $info.PromptWrite = (Get-Date) - $start
    Write-Host "<<<<<<<<<<`n"

    $info.PromptElapsed = $info.PromptWrite + $info.GitStatusUpdate
    $info.TotalElapsed = (Get-Date) - $begin

    Write-Host "Debug info:"
    $table = Merge-PropertyTables (Get-PropertyTable $info)
    $table | %{
        Write-Host
        $_.GetEnumerator() |
        Sort-Object -Property Name |
        Format-Table -AutoSize
    }
}
