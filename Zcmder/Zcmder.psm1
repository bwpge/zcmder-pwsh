. $PSScriptRoot\ZcmderTypes.ps1
. $PSScriptRoot\ZcmderGit.ps1
. $PSScriptRoot\ZcmderPrompt.ps1
. $PSScriptRoot\ZcmderUtils.ps1
. $PSScriptRoot\ZcmderDebug.ps1

$default_prompt = Get-ZCCurrentPrompt
$is_admin = Test-ZCIsAdmin

Remove-ZCVariable ZcmderOptions
Remove-ZCVariable ZcmderState
$global:ZcmderOptions = [ZCOptions]::new()
$global:ZcmderState = [ZCState]::new()

$prompt_block = {
    $exit_code = $global:LASTEXITCODE
    $global:ZcmderState.ExitCode = $exit_code
    $global:ZcmderState.IsAdmin = $is_admin

    Write-ZcmderPrompt | Out-Null
    $global:LASTEXITCODE = $exit_code

    # need to return a string to get the PS> prompt
    " "
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

    # always clean up our global variables
    Remove-ZCVariable ZcmderOptions
    Remove-ZCVariable ZcmderState
}
