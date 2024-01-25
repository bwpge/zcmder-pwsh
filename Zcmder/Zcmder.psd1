@{
# Script module or binary module file associated with this manifest.
RootModule = 'Zcmder.psm1'

# Version number of this module.
ModuleVersion = '0.2.1'

# ID used to uniquely identify this module
GUID = '2f55cab3-5190-4291-839a-4f45b5ae19b2'

# Author of this module
Author = 'bwpge'

# Copyright statement for this module
Copyright = '(c) 2024 bwpge'

# Description of the functionality provided by this module
Description = 'A cmder inspired PowerShell theme with git prompt integration.'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Set-ZcmderPrompt', 'Write-ZcmderDebugInfo', 'New-ZCStyle')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = @()

# Variables to export from this module
VariablesToExport = @('ZcmderOptions', 'ZcmderState')

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{
    PSData = @{
        # A URL to the license for this module.
        # # LicenseUri = ''

        # A URL to the main website for this project
        ProjectUri = 'https://github.com/bwpge/zcmder-pwsh'
    }
}
}
