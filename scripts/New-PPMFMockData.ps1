#Requires -Version 7.0
<#
.SYNOPSIS
    Generates mock ppmf_errorevent (and optionally ppmf_errornote) records in Dataverse for PPMF testing.

.DESCRIPTION
    Creates realistic test data via the Dataverse Web API using an Azure CLI access token.
    No credentials are stored or logged. All inputs are validated before any writes occur.

    Prerequisites:
      - Azure CLI installed and signed in ('az login').
      - For GCCH: 'az cloud set --name AzureUSGovernment' before 'az login'.
      - The signed-in account must have the 'PPMF - Admin' or 'PPMF - Service Account' role in the target environment.

.PARAMETER OrgUrl
    Dataverse org root URL, e.g. https://org05d9d92f.crm.microsoftdynamics.us/
    Trailing slash is optional.

.PARAMETER Count
    Number of error events to create. Range: 1–500. Default: 50.

.PARAMETER IncludeNotes
    When specified, adds 1–3 ppmf_errornote records to approximately 30 percent of created events.

.PARAMETER DaysBack
    Spread 'Occurred On' timestamps across this many days in the past. Default: 90.

.PARAMETER WhatIf
    Describe what would be created without writing to Dataverse.

.EXAMPLE
    .\New-PPMFMockData.ps1 -OrgUrl https://org05d9d92f.crm.microsoftdynamics.us/ -Count 100 -IncludeNotes

.EXAMPLE
    .\New-PPMFMockData.ps1 -OrgUrl https://org05d9d92f.crm.microsoftdynamics.us/ -Count 20 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^https://[a-z0-9\-]+\.(crm[0-9]*\.dynamics\.com|crm\.microsoftdynamics\.us|api\.crm[0-9]*\.microsoftdynamics\.us)/?$')]
    [string] $OrgUrl,

    [ValidateRange(1, 500)]
    [int] $Count = 50,

    [switch] $IncludeNotes,

    [ValidateRange(7, 365)]
    [int] $DaysBack = 90
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region ── Helpers ────────────────────────────────────────────────────────────

function Get-DataverseToken {
    param([string] $Resource)

    # Verify az CLI is present
    if (-not (Get-Command 'az' -ErrorAction SilentlyContinue)) {
        throw "Azure CLI (az) is not installed or not on PATH. See https://aka.ms/installazurecliwindows"
    }

    Write-Verbose "Requesting token from Azure CLI for resource: $Resource"
    $tokenJson = az account get-access-token --resource $Resource 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "az account get-access-token failed: $tokenJson`nRun 'az login' (and 'az cloud set --name AzureUSGovernment' for GCCH) first."
    }

    $token = ($tokenJson | ConvertFrom-Json).accessToken
    if ([string]::IsNullOrWhiteSpace($token)) {
        throw "Received an empty access token. Ensure you are signed in with 'az login'."
    }
    return $token
}

function Invoke-DataversePost {
    param(
        [string] $Endpoint,
        [hashtable] $Headers,
        [object]  $Body
    )
    $bodyJson = $Body | ConvertTo-Json -Depth 5 -Compress
    $response = Invoke-RestMethod `
        -Uri        $Endpoint `
        -Method     POST `
        -Headers    $Headers `
        -Body       $bodyJson `
        -ContentType 'application/json; charset=utf-8'
    return $response
}

function Get-RandomItem {
    param([array] $List)
    return $List[(Get-Random -Maximum $List.Count)]
}

function New-FakeGuid {
    return [System.Guid]::NewGuid().ToString()
}

#endregion

#region ── Static data pools ──────────────────────────────────────────────────

$solutions = @(
    'PowerPlatformMonitoringFramework',
    'SCOUTSolution',
    'HRPortal',
    'FinanceApprovalFlow',
    'ITServiceDesk',
    'InventoryManagement',
    'CustomerOnboarding'
)

$applications = @(
    'HR Self-Service Portal',
    'Finance Approval App',
    'IT Help Desk',
    'Asset Tracker',
    'Onboarding Wizard',
    'Expense Report App'
)

$flowNames = @(
    'Approval-Routing-Flow',
    'Daily-Sync-SharePoint',
    'Invoice-Processing-Flow',
    'Employee-Offboarding-Flow',
    'Incident-Notification-Flow',
    'Data-Validation-Flow',
    'Report-Generation-Flow',
    'Teams-Notification-Flow',
    'Record-Cleanup-Flow',
    'License-Check-Flow'
)

$environments = @('DEV', 'TEST', 'UAT', 'PROD')

$errorMessages = @(
    "Unable to process template language expressions in action 'Compose_2' inputs at line '0' and column '0': 'Attempt to divide an integral or decimal value by zero in function ''div'''.",
    "The request failed with http status code NotFound.",
    "Connection to SharePoint timed out after 30 seconds. The operation has been cancelled.",
    "Access to the path 'C:\Temp\upload.csv' is denied.",
    "The value 'null' cannot be assigned to type 'System.Int32'.",
    "OData query failed: The property 'ppmf_missingcolumn' is not valid on type 'mscrm.ppmf_errorevent'.",
    "HTTP/1.1 429 TooManyRequests — throttle limit reached. Retry after 60 seconds.",
    "Connector 'shared_commondataserviceforapps' returned an error: Unique key constraint violation on column 'ppmf_uniquekey'.",
    "Expression evaluation failed: item()['Body']?['EmployeeId'] is null.",
    "The flow run has been cancelled because it exceeded the 30-day wait limit.",
    "Failed to retrieve rows from Dataverse table 'msdyn_incidents'. Service unavailable.",
    "Adaptive card schema validation failed on field 'body[2].columns[0].items[0].text'.",
    "The trigger condition evaluated to false; execution skipped.",
    "Concurrency limit reached: only 50 simultaneous flow runs are allowed.",
    "Team ID 'abc123' is not a valid GUID-format identifier."
)

$errorSources = @(
    'Compose_2',
    'Get_items',
    'Send_an_HTTP_request',
    'Initialize_variable',
    'Apply_to_each',
    'Parse_JSON',
    'Update_a_row',
    'Post_adaptive_card',
    'Filter_array',
    'Condition_Check'
)

$probableCauses = @(
    'Division by zero: the DaysRemaining variable was not initialised before use in the Compose step.',
    'SharePoint list does not exist at the configured URL or the service account lacks Contribute access.',
    'The API throttle window was exceeded during a bulk import; no backoff retry was implemented.',
    'Null reference: the trigger body does not include the expected EmployeeId field for internal requests.',
    'Dataverse duplicate detection triggered: a record with the same UniqueKey already exists.',
    'The scheduled flow ran outside the maintenance window; Dataverse was in read-only mode.',
    'Missing environment variable value: ppmf_EnvironmentName was blank at time of execution.'
)

$suggestedFixes = @(
    'Add a null-check condition before the Compose step and default DaysRemaining to 0.',
    'Verify the SharePoint Site URL environment variable and confirm service account permissions.',
    'Implement exponential backoff with a retry policy of 3 attempts at 30-second intervals.',
    'Add a condition to check that EmployeeId is not empty before branching into the approval path.',
    'Pre-check for existing records using a List Rows action filtered by UniqueKey before creating.',
    'Schedule the flow run outside the 2 AM – 4 AM UTC maintenance window.',
    'Populate the ppmf_EnvironmentName environment variable in the target environment before activating flows.'
)

$userNames = @('Jane Smith', 'Bob Johnson', 'Alice Martinez', 'David Lee', 'Sara Kim', 'Tom Williams', 'System')
$userEmails = @('jsmith@contoso.gov', 'bjohnson@contoso.gov', 'amartinez@contoso.gov', 'dlee@contoso.gov', 'skim@contoso.gov', 'twilliams@contoso.gov')

$noteNames = @(
    'Initial triage review',
    'Root cause identified',
    'Fix deployed to TEST',
    'Awaiting vendor response',
    'Duplicate confirmed',
    'Workaround applied',
    'Customer notified',
    'Developer assigned'
)

$noteTexts = @(
    'Reviewed the flow run history. The error is reproducible and appears to be caused by the upstream SharePoint list returning a null for the Title column on rows added via the mobile app.',
    'Root cause confirmed: the DaysRemaining variable has a default of null, not 0. Fix is a 30-minute code change — adding an Initialize Variable action before the Compose step.',
    'Fix deployed to TEST on 2026-05-05. QA confirmed the flow ran successfully on 5 test records including one with a null Title. Promoting to PROD pending change approval.',
    'Opened a support ticket with Microsoft (Case #1234567). Issue is on their side — the Dataverse connector returns 429 for bulk operations even within documented limits.',
    'Confirmed duplicate of ERR-000987. Both records originate from the same flow run. Closing this one; all notes have been added to the canonical record.',
    'Workaround in place: scheduled the flow to run at 06:00 UTC, outside the maintenance window. Permanent fix (retry policy) is scheduled for the v1.2 release.',
    'Customer (Finance team) has been notified via email. They are aware that approvals submitted before 08:00 UTC may be delayed by up to 2 hours.',
    'Assigned to @dlee for investigation. Expected turnaround: 2 business days. Priority set to P2 per triage policy.'
)

# Severity weights: 35% Info, 35% Warning, 25% Critical, 5% Unknown
$severityWeights = @(1,1,1,1,1,1,1,2,2,2,2,2,2,2,3,3,3,3,3,4)
# Triage status weights: heavier on New/InProgress for realism
$triageWeights   = @(1,1,1,1,1,1,1,1,2,2,2,2,3,3,4,5,6,7)

#endregion

#region ── Main ───────────────────────────────────────────────────────────────

# Normalise org URL
$OrgUrl = $OrgUrl.TrimEnd('/')
$apiBase = "$OrgUrl/api/data/v9.2"

Write-Host "`nPPMF Mock Data Generator" -ForegroundColor Cyan
Write-Host "  Org URL  : $OrgUrl"
Write-Host "  Events   : $Count"
Write-Host "  Notes    : $(if ($IncludeNotes) { 'Yes (~30% of events)' } else { 'No' })"
Write-Host "  Days back: $DaysBack"
if ($WhatIfPreference) {
    Write-Host "  Mode     : WhatIf (no records will be written)" -ForegroundColor Yellow
}
Write-Host ""

# Acquire token (skip in WhatIf so the script can be demoed without az login)
$headers = $null
if (-not $WhatIfPreference) {
    $token = Get-DataverseToken -Resource "$OrgUrl/"
    $headers = @{
        'Authorization'    = "Bearer $token"
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        'Accept'           = 'application/json'
        'Prefer'           = 'return=representation'
    }
}

$now       = [System.DateTimeOffset]::UtcNow
$createdIds = [System.Collections.Generic.List[string]]::new()

for ($i = 1; $i -le $Count; $i++) {

    # Pick random field values
    $severity     = Get-RandomItem $severityWeights
    $triageStatus = Get-RandomItem $triageWeights
    $sourceType   = Get-Random -Minimum 1 -Maximum 5          # 1–4
    $errorType    = Get-Random -Minimum 1 -Maximum 8          # 1–7
    $solutionName = Get-RandomItem $solutions
    $envName      = Get-RandomItem $environments
    $occurredOn   = $now.AddDays(-(Get-Random -Minimum 0 -Maximum $DaysBack)).AddHours(-(Get-Random -Minimum 0 -Maximum 23)).AddMinutes(-(Get-Random -Minimum 0 -Maximum 59))
    $uniqueKey    = New-FakeGuid
    $correlId     = New-FakeGuid
    $flowRunId    = New-FakeGuid
    $envGuid      = New-FakeGuid
    $flowId       = New-FakeGuid

    # Fields conditional on source type
    $flowName   = $null
    $flowUrl    = $null
    $appName    = $null
    $appVersion = $null
    $activeScr  = $null
    $sessionId  = $null
    $userName   = Get-RandomItem $userNames
    $userEmail  = if ($sourceType -eq 1) { Get-RandomItem $userEmails } else { $null }

    switch ($sourceType) {
        1 { # PowerApp
            $appName    = Get-RandomItem $applications
            $appVersion = "1.$(Get-Random -Minimum 0 -Maximum 10).$(Get-Random -Minimum 0 -Maximum 50)"
            $activeScr  = Get-RandomItem @('HomeScreen','DetailScreen','EditScreen','SearchScreen','LoginScreen')
            $sessionId  = New-FakeGuid
        }
        2 { # Flow
            $flowName = Get-RandomItem $flowNames
            $flowUrl  = "https://make.powerautomate.appsplatform.us/environments/$envGuid/flows/$flowId/runs/$flowRunId"
        }
        3 { # ChildFlow
            $flowName = "PPMF-Child-$(Get-RandomItem @('ProcessFlowError','WriteToIntakeList','FlowErrorHandler-JSON','FlowErrorHandler-Parameters'))"
            $flowUrl  = "https://make.powerautomate.appsplatform.us/environments/$envGuid/flows/$flowId/runs/$flowRunId"
        }
        4 { # Integration
            $flowName = Get-RandomItem $flowNames
            $flowUrl  = "https://make.powerautomate.appsplatform.us/environments/$envGuid/flows/$flowId/runs/$flowRunId"
        }
    }

    # Alert sent (70% of non-New records)
    $alertSentOn = $null
    if ($triageStatus -ne 1 -and (Get-Random -Minimum 0 -Maximum 10) -ge 3) {
        $alertSentOn = $occurredOn.AddMinutes((Get-Random -Minimum 1 -Maximum 60)).ToString('o')
    }

    # Fixed / reviewed dates for resolved statuses
    $fixedOn     = $null
    $reviewedOn  = $null
    $resType     = $null
    $confLevel   = $null
    $fixDeployed = $false
    $fixVersion  = $null
    $custImpact  = $null
    $probCause   = $null
    $sugFix      = $null

    if ($triageStatus -in 3,4,5,7) {
        $fixedOn     = $occurredOn.AddDays((Get-Random -Minimum 1 -Maximum 14)).ToString('o')
        $reviewedOn  = $occurredOn.AddHours((Get-Random -Minimum 1 -Maximum 48)).ToString('o')
        $resType     = Get-Random -Minimum 1 -Maximum 6
        $confLevel   = Get-Random -Minimum 1 -Maximum 4
        $fixDeployed = ($triageStatus -eq 3) -and ((Get-Random -Minimum 0 -Maximum 2) -eq 1)
        $fixVersion  = "1.$(Get-Random -Minimum 0 -Maximum 5).$(Get-Random -Minimum 0 -Maximum 20)"
        $probCause   = Get-RandomItem $probableCauses
        $sugFix      = Get-RandomItem $suggestedFixes
    } elseif ($triageStatus -eq 2) {
        $reviewedOn  = $occurredOn.AddHours((Get-Random -Minimum 1 -Maximum 24)).ToString('o')
        $probCause   = Get-RandomItem $probableCauses
    }

    if ($severity -eq 3) {
        $custImpact = "Users are unable to complete the $solutionName workflow. Estimated $((Get-Random -Minimum 5 -Maximum 200)) records affected."
    }

    # Build raw payload
    $rawPayload = @{
        SolutionName  = $solutionName
        FlowName      = $flowName
        FlowRunId     = $flowRunId
        ErrorMessage  = Get-RandomItem $errorMessages
        OccurredOn    = $occurredOn.ToString('o')
        EnvironmentName = $envName
        UniqueKey     = $uniqueKey
    } | ConvertTo-Json -Compress

    # Build record body — only include non-null fields
    $record = [ordered]@{
        ppmf_errormessage = Get-RandomItem $errorMessages
        ppmf_solutionname = $solutionName
        ppmf_environmentname = $envName
        ppmf_severity     = $severity
        ppmf_triagestatus = $triageStatus
        ppmf_sourcetype   = $sourceType
        ppmf_errortype    = $errorType
        ppmf_errorsource  = Get-RandomItem $errorSources
        ppmf_occurredon   = $occurredOn.ToString('o')
        ppmf_uniquekey    = $uniqueKey
        ppmf_correlationid = $correlId
        ppmf_rawpayload   = $rawPayload
        ppmf_username     = $userName
        ppmf_flowrunid    = $flowRunId
    }

    if ($flowName)    { $record['ppmf_flowname']    = $flowName }
    if ($flowUrl)     { $record['ppmf_flowurl']     = $flowUrl }
    if ($appName)     { $record['ppmf_applicationname'] = $appName }
    if ($appVersion)  { $record['ppmf_appversion']  = $appVersion }
    if ($activeScr)   { $record['ppmf_activescreen'] = $activeScr }
    if ($sessionId)   { $record['ppmf_sessionid']   = $sessionId }
    if ($userEmail)   { $record['ppmf_useremail']   = $userEmail }
    if ($alertSentOn) { $record['ppmf_alertsenton'] = $alertSentOn }
    if ($fixedOn)     { $record['ppmf_fixedon']     = $fixedOn }
    if ($reviewedOn)  { $record['ppmf_reviewedon']  = $reviewedOn }
    if ($resType)     { $record['ppmf_resolutiontype'] = $resType }
    if ($confLevel)   { $record['ppmf_confidencelevel'] = $confLevel }
    if ($fixDeployed) { $record['ppmf_fixdeployed'] = $true }
    if ($fixVersion)  { $record['ppmf_fixversiontarget'] = $fixVersion }
    if ($probCause)   { $record['ppmf_probablecause'] = $probCause }
    if ($sugFix)      { $record['ppmf_suggestedfix'] = $sugFix }
    if ($custImpact)  { $record['ppmf_customerimpact'] = $custImpact }

    $severityLabel = @{1='Info';2='Warning';3='Critical';4='Unknown'}[$severity]
    $statusLabel   = @{1='New';2='InProgress';3='Fixed';4='Duplicate';5="Won't Fix";6='AwaitingInfo';7='Closed'}[$triageStatus]
    $sourceLabel   = @{1='PowerApp';2='Flow';3='ChildFlow';4='Integration'}[$sourceType]

    Write-Host "[$i/$Count] $severityLabel | $statusLabel | $sourceLabel | $envName | $solutionName" -ForegroundColor $(
        switch ($severity) { 3 {'Red'} 2 {'Yellow'} default {'Gray'} }
    )

    if ($PSCmdlet.ShouldProcess("$apiBase/ppmf_errorevents", "POST error event $i ($severityLabel, $statusLabel)")) {
        try {
            $result = Invoke-DataversePost -Endpoint "$apiBase/ppmf_errorevents" -Headers $headers -Body $record
            # Extract the created record ID from the returned entity
            $recordId = $result.ppmf_erroreventid
            if ($recordId) { $createdIds.Add($recordId) }
        }
        catch {
            Write-Warning "  Failed to create event $i : $($_.Exception.Message)"
            continue
        }

        # Create notes for ~30% of records when -IncludeNotes is set
        if ($IncludeNotes -and $recordId -and ((Get-Random -Minimum 0 -Maximum 10) -lt 3)) {
            $noteCount = Get-Random -Minimum 1 -Maximum 4
            for ($n = 1; $n -le $noteCount; $n++) {
                $noteType = Get-Random -Minimum 1 -Maximum 8
                $noteBody = [ordered]@{
                    ppmf_name     = Get-RandomItem $noteNames
                    ppmf_notetext = Get-RandomItem $noteTexts
                    ppmf_notetype = $noteType
                    'ppmf_erroreventid@odata.bind' = "/ppmf_errorevents($recordId)"
                }
                $noteTypeLabel = @{1='AnalystComment';2='CustomerUpdate';3='DeveloperUpdate';4='RootCause';5='Workaround';6='ResolutionDetail';7='ReleaseNote'}[$noteType]
                try {
                    Invoke-DataversePost -Endpoint "$apiBase/ppmf_errornotes" -Headers $headers -Body $noteBody | Out-Null
                    Write-Host "     Note $n/$noteCount created ($noteTypeLabel)" -ForegroundColor DarkGray
                }
                catch {
                    Write-Warning "     Failed to create note $n for event $i : $($_.Exception.Message)"
                }
            }
        }
    }
}

Write-Host ""
if ($WhatIfPreference) {
    Write-Host "WhatIf: $Count error event(s) would have been created." -ForegroundColor Yellow
} else {
    Write-Host "Done. Created $($createdIds.Count) of $Count error event(s)." -ForegroundColor Green
    if ($IncludeNotes) {
        Write-Host "Error notes were added to approximately 30% of created events." -ForegroundColor Green
    }
}

#endregion
