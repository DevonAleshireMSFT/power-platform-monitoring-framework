# =============================================================================
# New-PPMFSharePointList.ps1
#
# Creates (or verifies) the PPMF Error Events SharePoint list with the
# required column schema. Safe to run multiple times — existing columns are
# left untouched.
#
# Requirements:
#   Install-Module PnP.PowerShell -Scope CurrentUser
#
# Usage:
#   .\New-PPMFSharePointList.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/PPMF"
#
# Optional parameters:
#   -ListName      Display name of the list (default: "PPMF Error Events")
#   -ListDescription  Description shown in SharePoint UI
#
# For GCC / GCC High / DoD environments, PnP.PowerShell automatically uses
# the correct authority when you connect with -AzureEnvironment.
# Common values: Production (default), USGovernment, USGovernmentHigh, USGovernmentDoD
#
#   .\New-PPMFSharePointList.ps1 -SiteUrl "https://contoso.sharepoint.us/sites/PPMF" `
#                                -AzureEnvironment USGovernmentHigh
# =============================================================================

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string] $SiteUrl,

    [string] $ListName = "PPMF Error Events",

    [string] $ListDescription = "Power Monitoring Framework — error event log",

    [ValidateSet("Production","USGovernment","USGovernmentHigh","USGovernmentDoD")]
    [string] $AzureEnvironment = "Production"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Helper ────────────────────────────────────────────────────────────────────

function Write-Step ([string]$msg) { Write-Host "  $msg" -ForegroundColor Cyan }
function Write-Ok   ([string]$msg) { Write-Host "  ✔  $msg" -ForegroundColor Green }
function Write-Skip ([string]$msg) { Write-Host "  –  $msg" -ForegroundColor DarkGray }

# ── Connect ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "PPMF SharePoint List Provisioner" -ForegroundColor White
Write-Host "Site  : $SiteUrl" -ForegroundColor DarkGray
Write-Host "List  : $ListName" -ForegroundColor DarkGray
Write-Host ""

Write-Step "Connecting to SharePoint..."
if ($AzureEnvironment -eq "Production") {
    Connect-PnPOnline -Url $SiteUrl -Interactive
} else {
    Connect-PnPOnline -Url $SiteUrl -Interactive -AzureEnvironment $AzureEnvironment
}
Write-Ok "Connected"

# ── Create or verify list ─────────────────────────────────────────────────────

Write-Step "Checking for existing list..."
$list = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue

if ($null -eq $list) {
    Write-Step "List not found — creating '$ListName'..."
    $list = New-PnPList -Title $ListName `
                        -Template GenericList `
                        -Description $ListDescription `
                        -OnQuickLaunch
    Write-Ok "List created"
} else {
    Write-Ok "List already exists — verifying columns"
}

# ── Column definitions ────────────────────────────────────────────────────────
# Format: @{ Name; Type; Required; Description }
# Type values: Text, Note, Number, YesNo, DateTime

$columns = @(
    @{ Name = "SourceType";         Type = "Text";   Required = $false; Desc = "PowerApp or Flow" }
    @{ Name = "EnvironmentName";    Type = "Text";   Required = $false; Desc = "Name of the Power Platform environment" }
    @{ Name = "SolutionName";       Type = "Text";   Required = $false; Desc = "Solution the failing flow belongs to" }
    @{ Name = "ApplicationName";    Type = "Text";   Required = $false; Desc = "Canvas App name (if source is PowerApp)" }
    @{ Name = "AppVersion";         Type = "Text";   Required = $false; Desc = "Canvas App version at time of error" }
    @{ Name = "FlowName";           Type = "Text";   Required = $false; Desc = "Display name of the failing flow" }
    @{ Name = "FlowRunId";          Type = "Text";   Required = $false; Desc = "GUID of the specific flow run — used for deduplication" }
    @{ Name = "FlowUrl";            Type = "Text";   Required = $false; Desc = "Direct URL to the failed flow run" }
    @{ Name = "SessionId";          Type = "Text";   Required = $false; Desc = "Canvas App session ID (if source is PowerApp)" }
    @{ Name = "CorrelationId";      Type = "Text";   Required = $false; Desc = "Correlation ID for cross-system tracing" }
    @{ Name = "UserName";           Type = "Text";   Required = $false; Desc = "Display name of the user who triggered the error" }
    @{ Name = "UserEmail";          Type = "Text";   Required = $false; Desc = "Email of the user who triggered the error" }
    @{ Name = "ActiveScreen";       Type = "Text";   Required = $false; Desc = "Canvas App screen active when the error occurred" }
    @{ Name = "ErrorMessage";       Type = "Note";   Required = $false; Desc = "Full error message text" }
    @{ Name = "ErrorSource";        Type = "Text";   Required = $false; Desc = "Control or action that raised the error" }
    @{ Name = "ErrorType";          Type = "Text";   Required = $false; Desc = "Error type classification" }
    @{ Name = "Severity";           Type = "Text";   Required = $false; Desc = "Info, Warning, or Critical" }
    @{ Name = "OccurredOn";         Type = "Text";   Required = $false; Desc = "ISO 8601 timestamp of when the error occurred" }
    @{ Name = "RawPayload";         Type = "Note";   Required = $false; Desc = "Full JSON payload as received by the handler flow" }
    @{ Name = "TriageStatus";       Type = "Text";   Required = $false; Desc = "New, In Progress, or Fixed" }
    @{ Name = "SyncedToDataverse";  Type = "YesNo";  Required = $false; Desc = "Whether this record has been synced to Dataverse" }
    @{ Name = "SyncAttempts";       Type = "Number"; Required = $false; Desc = "Number of Dataverse sync attempts made" }
)

# Fetch existing fields once to avoid repeated round-trips
$existingFields = Get-PnPField -List $list | Select-Object -ExpandProperty InternalName

Write-Host ""
Write-Step "Provisioning columns..."

foreach ($col in $columns) {
    if ($existingFields -contains $col.Name) {
        Write-Skip "$($col.Name) — already exists"
        continue
    }

    $addParams = @{
        List         = $list
        DisplayName  = $col.Name
        InternalName = $col.Name
        Type         = $col.Type
        Required     = $col.Required
        AddToDefaultView = $true
    }

    Add-PnPField @addParams | Out-Null
    Write-Ok "$($col.Name) — created ($($col.Type))"
}

# ── Verify Title column ───────────────────────────────────────────────────────

Write-Host ""
Write-Step "Verifying Title column is in default view..."
$view = Get-PnPView -List $list -Identity "All Items" -ErrorAction SilentlyContinue
if ($null -eq $view) {
    $view = Get-PnPView -List $list | Select-Object -First 1
}
Write-Ok "Default view: '$($view.Title)'"

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Done. List provisioning complete." -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Return to PPMF Setup & Configuration in the model-driven app" -ForegroundColor DarkGray
Write-Host "  2. Enter the SharePoint Site URL and confirm the List Name" -ForegroundColor DarkGray
Write-Host "  3. Assign the SharePoint connection reference in the solution" -ForegroundColor DarkGray
Write-Host "  4. Turn on PPMF-Child-WriteErrorToSharePoint" -ForegroundColor DarkGray
Write-Host "  5. Turn on PPMF-Child-FlowErrorHandler-SharePoint" -ForegroundColor DarkGray
Write-Host ""
