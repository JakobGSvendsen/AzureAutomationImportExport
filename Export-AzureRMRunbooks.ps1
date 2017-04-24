#Made for Jgs@coretech.dk

$ResourceGroupName = "Automation"
$AutomationAccountName = "CoretechAutomation"
$PSDefaultParameterValues = @{
"*AzureRMAutomation*:ResourceGroupName" = $ResourceGroupName
"*AzureRMAutomation*:AutomationAccountName" = $AutomationAccountName
}

Login-AzureRmAccount 

cd "C:\Users\JGS\OneDrive\Events\2017 05 PowerShell Conference EU"

Import-Module .\AzureAutomationImportExport.psm1

#Export script runbook and child script runbooks (does not work in workflows!)
$RunbookName = "Invoke-ServiceNowUpdate"
#$RunbookName = "Handle-TwilioSMS"
$OutputFolder = "C:\temp\AA\Export\$RunbookName"

. Export-ScriptRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -OutputFolder $OutputFolder


Remove-Module AzureAutomationImportExport