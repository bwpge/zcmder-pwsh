. $PSScriptRoot\ZcmderTypes.ps1
. $PSScriptRoot\ZcmderGit.ps1
. $PSScriptRoot\ZcmderPrompt.ps1
. $PSScriptRoot\ZcmderUtils.ps1
. $PSScriptRoot\ZcmderDebug.ps1

$default_prompt = Get-CurrentPrompt

$prompt_block = {
    $exit_code = $LASTEXITCODE

    if(!$global:ZcmderOptions) {
        $global:ZcmderOptions = [ZCOptions]::new()
    }
    if(!$global:ZcmderState) {
        $global:ZcmderState = [ZCState]::new()
        $global:ZcmderState.IsAdmin = Test-ZcmderIsAdmin
    }

    $global:ZcmderState.ExitCode = $exit_code

    $prompt = Write-ZcmderPrompt
    $global:LASTEXITCODE = $exit_code
    $prompt
}

<#
.SYNOPSIS
    Sets the current prompt to Zcmder.
.DESCRIPTION
    Sets the current prompt to Zcmder. This prompt updates as settings change,
    so it is not required to reset the prompt.
.INPUTS
    None
.OUTPUTS
    None
#>
function Set-ZcmderPrompt {
    Set-Item Function:\prompt -Value $prompt_block
}

# clean up when module is removed
$ExecutionContext.SessionState.Module.OnRemove = {
    # reset prompt but only if it was modified by Set-ZcmderPrompt
    $current = Get-CurrentPrompt
    if ($current -eq $prompt_block) {
        Set-Item Function:\prompt -Value ([scriptblock]::Create($default_prompt))
    }

    # always clean up zcmder variables
    try { Remove-Variable ZcmderOptions -Scope Global } catch {}
    try { Remove-Variable ZcmderState -Scope Global } catch {}
}
