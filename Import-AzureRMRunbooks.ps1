#Made by Jakob@runbook.guru
#Login-AzureRmAccount 

$ResourceGroupName = "DemoAutomation"
$AutomationAccountName = "DemoAutomation"

cd "C:\Users\JGS\OneDrive\Git\Repos\AzureAutomationImportExport"
Import-Module .\AzureAutomationImportExport

#Import Folder
$FolderPath = "C:\Temp\ELEU\Enable-O365User"
foreach($File in (Dir "$FolderPath\*.json"))
{
    Import-ScriptRunbook -RunbookJSONPath $File.FullName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
}
break

#import Single
#$RunbookXMLPath = "C:\Temp\ELEU\Remove-O365AdminAccess\Remove-O365AdminAccess.json"
#. Import-ScriptRunbook -RunbookJSONPath $RunbookXMLPath -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName

#Cleanup
Remove-Module AzureAutomationImportExport
Remove-AzureRmAutomationAccount -ResourceGroupName "DemoAutomation" -AutomationAccountName "DemoAutomation" -Force
New-AzureRmAutomationAccount -ResourceGroupName "DemoAutomation" -AutomationAccountName "DemoAutomation" -Location "West Europe"
