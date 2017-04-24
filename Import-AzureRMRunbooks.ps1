#Made for Jakob@runbook.guru

$ResourceGroupName = "OMS-RG"
$AutomationAccountName = "Automation"
$PSDefaultParameterValues = @{
"*AzureRMAutomation*:ResourceGroupName" = $ResourceGroupName
"*AzureRMAutomation*:AutomationAccountName" = $AutomationAccountName
}

#Login-AzureRmAccount 

cd "C:\Users\JGS\OneDrive\Events\2017 05 PowerShell Conference EU"

Import-Module .\AzureAutomationImportExport.psm1

#Export script runbook and child script runbooks (does not work in workflows!)
#RunbookName = "Invoke-ServiceNowUpdate"

$RunbookXMLPath = "C:\Temp\AA\Export\Invoke-ServiceNowUpdate\Invoke-ServiceNowUpdate.xml"

$RunbookXML = [XML](Get-Content "C:\Temp\AA\Export\Invoke-ServiceNowUpdate\Invoke-ServiceNowUpdate.xml")

#Export runbook to temp dir and get content    
$TempDir = Join-Path $env:TEMP "$AutomationAccountName\$RunbookName$((Get-Date).ToString("yyyyMMddttmmss"))"
if(!(Test-PAth $TempDir)) {mkdir $TempDir | Out-Null}


#Set name
$Name = $RunbookXML.Runbook.Name

#Export definition
$TempFilePath = (Join-Path $TempDir "$Name.PS1")
$RunbookXML.Runbook.Published.Definition | Out-File $TempFilePath

#$Tags = $RunbookXML.Runbook.Tags | ConvertFrom-JSON
$Tags = $null
$Splat = @{
    ResourceGroupName =$ResourceGroupName
    AutomationAccountName =$AutomationAccountName
    Name = $Name
    Path = $TempFilePath
    Description = $RunbookXML.Runbook.Configuration.Description
    Tags = $Tags
    LogProgress = [Boolean]$RunbookXML.Runbook.Configuration.LogProgress
    LogVerbose = [Boolean]$RunbookXML.Runbook.Configuration.LogVerbose
}

Import-AzureRmAutomationRunbook  @splat -Type PowerShell  -Published 
Remove-Item $TempDir -Force -Recurse | Out-Null


#Import Runbook Assets
#create dummy credential for use when crreating credential assets as real credential was not exportred
$username = "domain\admin"
$password = "password" | ConvertTo-SecureString -AsPlainText -Force
$CredDummy =  New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
#Published
$Assets = $RunbookXML.Runbook.Published.Assets | ConvertFrom-Json

Foreach ($Asset in $Assets)
{
    Switch ($Asset.Type)
    {
       "AutomationCredential"  { New-AzureRmAutomationCredential -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Asset.Name -Value $CredDummy}
       "AutomationVariable"  { New-AzureRmAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Asset.Name -Value $Asset.Value -Encrypted $Asset.Encrypted }
    }
}

#. Export-ScriptRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $RunbookName -OutputFolder $OutputFolder


Remove-Module AzureAutomationImportExport