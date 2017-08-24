#Made by jakob@runbook.guru
#Login-AzureRmAccount 

$ResourceGroupName = "OMS-RG"
$AutomationAccountName = "Automation"

cd "C:\Users\JGS\OneDrive\Git\Repos\AzureAutomationImportExport"

Import-Module .\AzureAutomationImportExport

#Export script runbook and child script runbooks (does not work in workflows!)
$RunbookName = "Enable-O365User"
$OutputFolder = "C:\Temp\ELEU\$RunbookName"
if(!(Test-PAth $OutputFolder)) {mkdir $OutputFolder | Out-Null}
. Export-ScriptRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -OutputFolder $OutputFolder









break

$Runbooks = Get-AzureRmAutomationRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
foreach($Runbook in $Runbooks){
    $RunbookName = $Runbook.Name
    $OutputFolder = "C:\Temp\ELEU\$RunbookName"
    if(!(Test-PAth $OutputFolder)) {mkdir $OutputFolder | Out-Null}
    . Export-ScriptRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -OutputFolder $OutputFolder
}

Remove-Module AzureAutomationImportExport

Get-ChildItem -Path $FolderPath | gm
Get-ChildItem -Path $FolderPath | where-object { $_ -is [System.IO.FileInfo] }