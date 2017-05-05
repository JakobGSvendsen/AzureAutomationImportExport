#Made by jakob@runbook.guru

$ResourceGroupName = "Automation"
$AutomationAccountName = "CoretechAutomation"
#Login-AzureRmAccount 

cd "C:\Users\JGS\OneDrive\Git\Repos\AzureAutomationImportExport"

Import-Module .\AzureAutomationImportExport

#Export script runbook and child script runbooks (does not work in workflows!)
#$RunbookName = "Alert-UserLockedSMS"

$RunbookName = "Enable-O365User"
$OutputFolder = "C:\temp\AA\Export\$RunbookName"
if(!(Test-PAth $OutputFolder)) {mkdir $OutputFolder | Out-Null}
. Export-ScriptRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -OutputFolder $OutputFolder


Remove-Module AzureAutomationImportExport