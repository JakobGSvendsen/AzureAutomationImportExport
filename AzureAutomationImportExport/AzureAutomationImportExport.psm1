
Function Get-RunbookChildScripts {
    param(
    [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $RunbookContent
    )
    #Check each line to find child runbooks
    Foreach ($Line in $RunbookContent) {
         if($Line -match ".*\.\\(.+)\.ps1.*")
         {
            $Matches[1]
         }
    }
}

Function Get-RunbookAssets {
    param(
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $ResourceGroupName,
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $AutomationAccountName,
    [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
    $RunbookContent
    )
    $Assets = @()
    #Check each line to find child runbooks
    Foreach ($Line in $RunbookContent) {
         if($Line -match "Get-(Automation\w+) .*['`"]{1}(.+)['`"]{1}")
         {
            #Rename PSCredentials as the cmdlet does not have same name (so much for consistency)
            if($Matches[1] -eq "AutomationPSCredential") { 
                 $Assets += @{"Type"="AutomationCredential";"Name"=$Matches[2]}
            }
            else
            {
                $Assets += @{"Type"=$Matches[1];"Name"=$Matches[2]}
            }
         }
      
    }

    Foreach($Asset in $Assets)
    {
        #Skip connection as the cmdlet is not currently stable and certificate as it is not implemented yet
        if($Asset.Type -in "AutomationConnection","AutomationCertificate")
        {
            continue
        }
    
        $Expression = "Get-AzureRM$($Asset.Type) -Name '$($Asset.Name)' -ResourceGroupName '$ResourceGroupName' -AutomationAccountName '$AutomationAccountName'"
        $AssetReturn = Invoke-Expression $Expression 
        $AssetReturn | Add-Member -MemberType NoteProperty -Name Type -Value $Asset.Type -PassThru
    }
    
}

Function Get-RunbookContent {
    param(
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $ResourceGroupName,
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $AutomationAccountName,
    [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
    $RunbookName,
    [ValidateSet("Published", "Draft")]
    [String]$Slot = "Published"
    )
    #Export runbook to temp dir and get content    
    $TempDir = Join-Path $env:TEMP "$AutomationAccountName\$RunbookName$((Get-Date).ToString("yyyyMMddttmmss"))"
    if(!(Test-PAth $TempDir)) {mkdir $TempDir | Out-Null}
    $RunbookMain = Export-AzureRmAutomationRunbook -Name $RunbookName -OutputFolder $TempDir -Force -Slot $Slot  -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    $RunbookContent = Get-Content (Join-Path $TempDir $RunbookMain)
    Remove-Item $TempDir -Force -Recurse | Out-Null

    $RunbookContent
}

Function Export-ScriptRunbook {
   param(
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $ResourceGroupName,
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $AutomationAccountName,
    [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
    $RunbookName,
    [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=3)]
    $OutputFolder,
    $ExportedChilds
    )


    if(!(Test-PAth $OutputFolder)) {
        throw "Output Folder: '$OutputFolder' does not exist"
    }

    Write-Host "Exporting $RunbookName"

    $Runbook = Get-AzureRmAutomationRunbook -Name $RunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    if(!$Runbook) { throw "Runbook $RunbookName not found" }

    if(!(Test-Path (Join-Path $OutputFolder "PS1"))) {mkdir (Join-Path $OutputFolder "PS1") | Out-Null}

    #Export draft if it is in edit mode
    $ContentDraft = ""
    if($Runbook.State -eq "Edit") {
        $ContentDraft = Get-RunbookContent -RunbookName $RunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Slot Draft
        $ContentDraft | Out-File -FilePath (Join-Path $OutputFolder "ps1\$RunbookName-draft.ps1") -Force
    }

    $ContentPublished = Get-RunbookContent -RunbookName $RunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Slot Published
    $ContentPublished | Out-File -FilePath (Join-Path $OutputFolder "ps1\$RunbookName.ps1") -Force

    #region retrieve Runbook schedule information
    $Schedule = Get-AzureRmAutomationScheduledRunbook -RunbookName $RunbookName -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    #endregion

    # Build XML Definition for Export
 <#   $TemplateSchema = @'
<?xml version="1.0" encoding="UTF-8"?>
<Runbook>
    <Name></Name>
    <Tags></Tags>
    <Configuration>
        <Description></Description>
        <LogVerbose></LogVerbose>
        <LogProgress></LogProgress>
    </Configuration>
    <Published>
        <Definition></Definition>
        <Assets></Assets>
    </Published>
    <Draft>
        <Definition></Definition>
        <Assets></Assets>
    </Draft>
    <Schedules>
    </Schedules>
    <Webhooks>
    </Webhooks>
</Runbook>
'@

    # Assign Schema to Variable
    [XML]$XMLExportFile = $TemplateSchema 

    # Build node data for export to XML
    $XMLExportFile.Runbook.Name = "$RunbookName"
    $XMLExportFile.Runbook.Published.Definition = ($ContentPublished | Out-String).TosTring()
    $XMLExportFile.Runbook.Draft.Definition = ($ContentDraft  | Out-String).TosTring()
    $XMLExportFile.Runbook.Tags = [string]($Runbook.Tags | ConvertTo-Json)
    $XMLExportFile.Runbook.Configuration.Description = "$($Runbook.Description)"
    # Log values being converted to string to be supported by XML
    $XMLExportFile.Runbook.Configuration.LogVerbose = [string]$Runbook.LogVerbose
    $XMLExportFile.Runbook.Configuration.LogProgress = [string]$Runbook.LogProgress
#>

$Export = COnvertFrom-JSON @"
{
  "Runbook": {
       "Name": "",
        "Tags": "",
        "Configuration": {
            "Description": "",
            "LogVerbose": false,
            "LogProgress": false
        },
        "Published": {
            "Definition": "",
            "Assets": ""
        },
        "Draft": {
            "Definition": "",
            "Assets": ""
        },
        "Schedules": "",
        "Webhooks": "" 
    }  
}
"@

   # Build node data for export to XML
    $Export.Runbook.Name = "$RunbookName"
    $Export.Runbook.Published.Definition = ($ContentPublished | Out-String).TosTring()
    $Export.Runbook.Draft.Definition = ($ContentDraft  | Out-String).TosTring()
    $Export.Runbook.Tags = $Runbook.Tags
    $Export.Runbook.Configuration.Description = "$($Runbook.Description)"
    # Log values being converted to string to be supported by XML
    $Export.Runbook.Configuration.LogVerbose = $Runbook.LogVerbose
    $Export.Runbook.Configuration.LogProgress = $Runbook.LogProgress
    $Export.Runbook.Schedules = "$($Schedule.ScheduleName)"
    


    # SCHEDULES SECTION - NOT IMPLEMENTED
            # Export schedules (if -exportSchedules is specified) [Schedules defined per Runbook]
            <#if($Using:ExportSchedules -or $Using:ExportAssets)
            {
                $RunbookSch = Get-SmaRunbook -Name $Using:RunbookName -WebServiceEndpoint $Using:WebServiceEndpoint -Port $Using:Port -AuthenticationType $Using:AuthenticationType -Credential $Using:Cred
                $RBSchedules = $RunbookSch.Schedules
                $SchedulesVariable = (@($XMLExportFile.Runbook.Schedules)[0]).Clone()
                foreach($RBSchedule in $RBSchedules)
                {
                    If($RBSchedule.GetType().Name -eq "DailySchedule")
                    {
                        $SchedulesVariable.ScheduleName = [string]$RBSchedule.Name 
                        $SchedulesVariable.ScheduleDescription = [string]$RBSchedule.Description
                        $SchedulesVariable.ScheduleType = [string]$RBSchedule.GetType().Name
                        $SchedulesVariable.ScheduleNextRun = [string]$RBSchedule.NextRun
                        $SchedulesVariable.ScheduleExpiryTime = [string]$RBSchedule.ExpiryTime
                        $SchedulesVariable.ScheduleDayInterval = [string]$RBSchedule.DayInterval
                        $XMLExportvariable = $XMLExportFile.Runbook.AppendChild($SchedulesVariable)
                        $SchedulesVariable = $SchedulesVariable.clone()
                    }
                }
            }#>

    #WEBHOOKS NOT IMPLEMENTED

    $AssetsDraft = Get-RunbookAssets -RunbookContent $ContentDraft -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    if(![String]::IsNullOrEmpty($AssetsDraft)) {    
        $Export.Runbook.Draft.Assets = $AssetsDraft  | select-object Type, Name, Encrypted, Value, Description
    }

    $AssetsPublished = Get-RunbookAssets -RunbookContent $ContentPublished -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName
    if(![String]::IsNullOrEmpty($AssetsPublished)) {
        $Export.Runbook.Published.Assets = $AssetsPublished | select-object Type, Name, Encrypted, Value, Description
    }

    # Output Runbook from SMA
    $Export | ConvertTo-JSON -Depth 99 | Out-file -FilePath "$OutputFolder\$RunbookName.json"
   
    $IncludeChilds = $true
    if($IncludeChilds)
    {
        #Published 
        $RunbookChilds = Get-RunbookChildScripts -RunbookContent $ContentPublished | Sort-Object -Unique

        if($null -eq $ExportedChilds) { 
            $ExportedChilds = @()
        }

        Foreach($Child in $RunbookChilds)
        {
            if($ExportedChilds -notcontains $Child)
            {
            $ExportedChilds += $Child
            Export-ScriptRunbook -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -RunbookName $Child -OutputFolder $OutputFolder -ExportedChilds $ExportedChilds
            }
        }
    }
}



Function Import-ScriptRunbook {
    param(
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $ResourceGroupName,
    [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
    $AutomationAccountName,
    $RunbookJSONPath
    )

    $Runbook = Get-Content $RunbookJSONPath | ConvertFrom-JSON

    #Export runbook to temp dir and get content    
    $TempDir = Join-Path $env:TEMP "$AutomationAccountName\$RunbookName$((Get-Date).ToString("yyyyMMddttmmss"))"
    if(!(Test-Path $TempDir)) {mkdir $TempDir | Out-Null}
    
    #Set name
    $Name = $Runbook.Runbook.Name

    #Export definition
    $TempFilePath = (Join-Path $TempDir "$Name.PS1")
    $Runbook.Runbook.Published.Definition | Out-File $TempFilePath

    #$Tags = $RunbookXML.Runbook.Tags | ConvertFrom-JSON
    $Tags = $null
    $Splat = @{
        ResourceGroupName =$ResourceGroupName
        AutomationAccountName =$AutomationAccountName
        Name = $Name
        Path = $TempFilePath
        Description = $Runbook.Runbook.Configuration.Description
        Tags = $Tags
        LogProgress = [Boolean]$Runbook.Runbook.Configuration.LogProgress
        LogVerbose = [Boolean]$Runbook.Runbook.Configuration.LogVerbose
    }

    Import-AzureRmAutomationRunbook  @splat -Type PowerShell -Published 
    Remove-Item $TempDir -Force -Recurse | Out-Null

    #Import Runbook Assets
    #create dummy credential for use when crreating credential assets as real credential was not exportred
    $username = "domain\admin"
    $password = "password" | ConvertTo-SecureString -AsPlainText -Force
    $CredDummy =  New-Object -typename System.Management.Automation.PSCredential -argumentlist $username, $password
    #Published
    $Assets = $Runbook.Runbook.Published.Assets

    Foreach ($Asset in $Assets)
    {
        Switch ($Asset.Type)
        {
           "AutomationCredential"  { New-AzureRmAutomationCredential -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Asset.Name -Value $CredDummy}
           "AutomationVariable"  { New-AzureRmAutomationVariable -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccountName -Name $Asset.Name -Value $Asset.Value -Encrypted $Asset.Encrypted }
        }
    }
 }
