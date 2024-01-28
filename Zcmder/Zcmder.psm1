# the module requires ANSI escape sequences, check support
if (!$Host.UI.SupportsVirtualTerminal) {
    throw 'Zcmder requires support for ANSI escape sequences to render prompts correctly, but `$Host.UI.SupportsVirtualTerminal` was False. See: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_ansi_terminals for more information.'
}

. $PSScriptRoot\ZcmderTypes.ps1
. $PSScriptRoot\ZcmderGit.ps1
. $PSScriptRoot\ZcmderPrompt.ps1
. $PSScriptRoot\ZcmderUtils.ps1
. $PSScriptRoot\ZcmderDebug.ps1

$default_prompt = Get-ZCCurrentPrompt
$is_admin = Test-ZCIsAdmin

Remove-ZCVariable ZcmderOptions
$global:ZcmderOptions = [ZCOptions]::new()

$prompt_block = {
    # NOTE: $? must be captured before *any* statement because powershell always
    # needs to do things in convoluted and confusing ways
    $dollar_q = $global:?
    $exit_code = $global:LASTEXITCODE
    $text = Get-ZcmderPrompt -IsAdmin:$is_admin -ExitCode:$exit_code -DollarQ:$dollar_q
    $global:LASTEXITCODE = $exit_code

    $text
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
}
