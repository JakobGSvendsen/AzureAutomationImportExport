#Made for Jakob@runbook.guru
#Login-AzureRmAccount 

$ResourceGroupName = "OMS-RG"
$AutomationAccountName = "Automation"

cd "C:\Users\JGS\OneDrive\Git\Repos\AzureAutomationImportExport"
Import-Module .\AzureAutomationImportExport

#import Single
$RunbookXMLPath = "C:\Temp\AA\Export\Alert-UserLockedSMS\Enable-O365User.xml"
Import-ScriptRunbook -RunbookXMLPath $RunbookXMLPath -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
break
#Import Folder
$FolderPath = "C:\Temp\AA\Export\Enable-O365User"
foreach($File in (Dir "$FolderPath\*.xml"))
{
    Import-ScriptRunbook -RunbookXMLPath $File.FullName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
}

Remove-Module AzureAutomationImportExport