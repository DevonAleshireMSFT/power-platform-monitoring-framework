# =============================================================================
# Test-PPMFDeployment.ps1
#
# Validates that a PPMF solution deployment is complete and correctly
# configured in a target Power Platform environment. Safe to run repeatedly.
#
# Checks performed:
#   - Solution exists at the expected version
#   - All cloud flows exist and are in their expected state
#   - All connection references exist and are assigned
#   - All environment variable definitions exist
#   - All web resources (ppmf_ prefix) exist
#   - All security roles exist
#
# Usage (interactive — prompts for auth):
#   .\Test-PPMFDeployment.ps1 -EnvironmentUrl "https://org.crm.dynamics.com"
#
# Usage (CI / service principal):
#   .\Test-PPMFDeployment.ps1 `
#       -EnvironmentUrl  "https://org.crm.dynamics.com" `
#       -ClientId        $env:PP_CLIENT_ID `
#       -ClientSecret    $env:PP_CLIENT_SECRET `
#       -TenantId        $env:PP_TENANT_ID
#
# Exit codes:
#   0  All checks passed (or passed with warnings)
#   1  One or more checks failed
#
# For GCC / GCC High / DoD environments pass -Cloud with the appropriate value:
#   Commercial : (default, omit -Cloud)
#   GCC        : UsGov
#   GCC High   : UsGovHigh
#   DoD        : UsGovDod
# =============================================================================

#Requires -Version 7.0

[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string] $EnvironmentUrl,

    # Service principal auth (CI). Omit for interactive auth.
    [string] $ClientId,
    [string] $ClientSecret,
    [string] $TenantId,

    [ValidateSet("", "UsGov", "UsGovHigh", "UsGovDod")]
    [string] $Cloud = "",

    # Expected solution version to verify. Leave empty to skip version check.
    [string] $ExpectedVersion = "1.0.0.11"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── Constants ─────────────────────────────────────────────────────────────────

$SOLUTION_NAME = "PowerPlatformMonitoringFramework"

$EXPECTED_FLOWS = @(
    @{ Name = "PPMF-Child-FlowErrorHandler-JSON";        ExpectedState = 1 }  # 1 = Active
    @{ Name = "PPMF-Child-FlowErrorHandler-Parameters";  ExpectedState = 1 }
    @{ Name = "PPMF-Child-FlowErrorHandler-SharePoint";  ExpectedState = 1 }
    @{ Name = "PPMF-Child-FlowWritetoIntakeList";        ExpectedState = 1 }
    @{ Name = "PPMF-Child-ProcessFlowError";             ExpectedState = 1 }
    @{ Name = "PPMF-Child-WriteErrorToSharePoint";       ExpectedState = 1 }
    @{ Name = "PPMF-Delete-Old-Errors";                  ExpectedState = 1 }
    @{ Name = "PPMF-Get-Environment-Info";               ExpectedState = 1 }
    @{ Name = "PPMF-Power-Apps-Error-Handler-JSON";      ExpectedState = 1 }
    @{ Name = "PPMF-Sync-SharePointErrorsToDataverse";   ExpectedState = 0 }  # 0 = Off by design
    @{ Name = "PPMF-Demo-Flow-Failure";                  ExpectedState = 0 }  # 0 = Off by design
)

$EXPECTED_CONNECTION_REFS = @(
    "ppmf_DataverseConnectionReference"
    "ppmf_TeamsConnectionReference"
    "ppmf_SharePointConnectionReference"
)

$EXPECTED_ENV_VARS = @(
    "ppmf_TeamID"
    "ppmf_FlowAlertsChannelID"
    "ppmf_EnvironmentName"
    "ppmf_PortalBaseUrl"
    "ppmf_WritingMode"
    "ppmf_RetentionDays"
    "ppmf_AlertThrottleMinutes"
    "ppmf_SharePointSiteUrl"
    "ppmf_SharePointListName"
    "ppmf_DataverseSyncEnabled"
    "ppmf_SyncIntervalMinutes"
    "ppmf_SyncBatchSize"
)

$EXPECTED_ROLES = @(
    "PPMF - Admin"
    "PPMF - Reader"
    "PPMF - Service Account"
    "PPMF - Triager"
)

$WEB_RESOURCE_PREFIX = "ppmf_"

# ── Helpers ───────────────────────────────────────────────────────────────────

$script:PassCount = 0
$script:WarnCount = 0
$script:FailCount = 0
$script:Results   = [System.Collections.Generic.List[hashtable]]::new()

function Write-Header ([string]$Text) {
    Write-Host ""
    Write-Host "$('─' * 64)" -ForegroundColor DarkGray
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$('─' * 64)" -ForegroundColor DarkGray
}

function Add-Result ([string]$Status, [string]$Category, [string]$Check, [string]$Detail = "") {
    $script:Results.Add(@{ Status = $Status; Category = $Category; Check = $Check; Detail = $Detail })
    switch ($Status) {
        "PASS" { $script:PassCount++; Write-Host "  ✔  $Check" -ForegroundColor Green }
        "WARN" { $script:WarnCount++; Write-Host "  ⚠  $Check$(if ($Detail) { " — $Detail" })" -ForegroundColor Yellow }
        "FAIL" { $script:FailCount++; Write-Host "  ✖  $Check$(if ($Detail) { " — $Detail" })" -ForegroundColor Red }
    }
}

function Invoke-DvApi ([string]$RelativeUrl) {
    $baseUrl = $EnvironmentUrl.TrimEnd('/')
    $uri     = "$baseUrl/api/data/v9.2/$RelativeUrl"
    $headers = @{
        'OData-MaxVersion' = '4.0'
        'OData-Version'    = '4.0'
        'Accept'           = 'application/json'
        'Authorization'    = "Bearer $script:AccessToken"
        'Prefer'           = 'odata.include-annotations="*"'
    }
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
    return $response
}

# ── Authentication ────────────────────────────────────────────────────────────

function Get-AccessToken {
    Write-Header "Authentication"

    $useServicePrincipal = $ClientId -and $ClientSecret -and $TenantId

    if ($useServicePrincipal) {
        Write-Host "  Authenticating with service principal..." -ForegroundColor Gray

        $authority = switch ($Cloud) {
            "UsGov"    { "https://login.microsoftonline.us" }
            "UsGovHigh"{ "https://login.microsoftonline.us" }
            "UsGovDod" { "https://login.microsoftonline.us" }
            default    { "https://login.microsoftonline.com" }
        }

        $resource = switch ($Cloud) {
            "UsGov"    { "https://gov.crm.microsoftdynamics.com" }
            "UsGovHigh"{ "https://high.crm.microsoftdynamics.com" }
            "UsGovDod" { "https://mil.crm.microsoftdynamics.com" }
            default    { "https://service.crm.dynamics.com" }
        }

        $tokenBody = @{
            grant_type    = "client_credentials"
            client_id     = $ClientId
            client_secret = $ClientSecret
            resource      = $resource
        }

        $tokenResponse = Invoke-RestMethod `
            -Uri    "$authority/$TenantId/oauth2/token" `
            -Method Post `
            -Body   $tokenBody `
            -ErrorAction Stop

        $script:AccessToken = $tokenResponse.access_token
        Write-Host "  ✔  Service principal authenticated" -ForegroundColor Green

    } else {
        Write-Host "  Authenticating interactively via PAC CLI..." -ForegroundColor Gray

        # Use pac cli to get a token for the environment
        $cloudArg = if ($Cloud) { "--cloud $Cloud" } else { "" }
        $pacOutput = pac auth list 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  ✖  PAC CLI not available or no auth profile found." -ForegroundColor Red
            Write-Host "     Run 'pac auth create' or provide -ClientId/-ClientSecret/-TenantId." -ForegroundColor DarkGray
            exit 1
        }

        # Acquire token via PAC CLI whoami to trigger auth and then use REST
        # Fall back to device code flow via MSAL if no service principal provided
        Write-Host "  ℹ  For CI usage, provide -ClientId, -ClientSecret, and -TenantId." -ForegroundColor Yellow
        Write-Host "     Attempting to use current PAC CLI auth profile token..." -ForegroundColor Gray

        # Extract token from PAC environment (PAC stores tokens in the profile)
        $envInfo = pac env who --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
        if (-not $envInfo) {
            Write-Host "  ✖  Could not retrieve auth token from PAC CLI profile." -ForegroundColor Red
            Write-Host "     Run 'pac auth select' to choose an active profile, or provide service principal credentials." -ForegroundColor DarkGray
            exit 1
        }

        # Use PAC CLI to invoke a raw API call — pac does auth transparently
        # Store a sentinel so Invoke-DvApi uses pac instead of Bearer token
        $script:AccessToken = $null
        $script:UsePacCli   = $true
        Write-Host "  ✔  Using PAC CLI active auth profile" -ForegroundColor Green
    }
}

function Invoke-DvApiPac ([string]$RelativeUrl) {
    # Wrapper that uses pac org api if no Bearer token available (interactive auth)
    if ($script:UsePacCli) {
        $baseUrl  = $EnvironmentUrl.TrimEnd('/')
        $fullUrl  = "$baseUrl/api/data/v9.2/$RelativeUrl"
        $raw      = pac org api --url $fullUrl --json 2>&1
        return $raw | ConvertFrom-Json -ErrorAction Stop
    }
    return Invoke-DvApi $RelativeUrl
}

# ── Checks ────────────────────────────────────────────────────────────────────

function Test-SolutionVersion {
    Write-Header "Solution"
    try {
        $resp = Invoke-DvApiPac "solutions?`$filter=uniquename eq '$SOLUTION_NAME'&`$select=uniquename,version,friendlyname"
        $sol  = $resp.value | Select-Object -First 1
        if (-not $sol) {
            Add-Result "FAIL" "Solution" "Solution '$SOLUTION_NAME' exists" "Not found in environment"
            return
        }
        Add-Result "PASS" "Solution" "Solution '$SOLUTION_NAME' exists"

        if ($ExpectedVersion) {
            if ($sol.version -eq $ExpectedVersion) {
                Add-Result "PASS" "Solution" "Version is $ExpectedVersion"
            } else {
                Add-Result "FAIL" "Solution" "Version is $ExpectedVersion" "Found $($sol.version)"
            }
        }
    } catch {
        Add-Result "FAIL" "Solution" "Solution query succeeded" $_.Exception.Message
    }
}

function Test-Flows {
    Write-Header "Cloud Flows"
    try {
        $resp = Invoke-DvApiPac "workflows?`$filter=category eq 5 and (contains(name,'PPMF'))&`$select=name,statecode&`$top=50"
        $flows = $resp.value

        foreach ($expected in $EXPECTED_FLOWS) {
            $match = $flows | Where-Object { $_.name -like "*$($expected.Name)*" } | Select-Object -First 1
            if (-not $match) {
                Add-Result "FAIL" "Flows" "$($expected.Name)" "Not found"
                continue
            }

            $stateLabel    = if ($expected.ExpectedState -eq 1) { "Active" } else { "Off (by design)" }
            $actualLabel   = if ($match.statecode -eq 1) { "Active" } else { "Inactive" }

            if ($match.statecode -eq $expected.ExpectedState) {
                Add-Result "PASS" "Flows" "$($expected.Name) — $stateLabel"
            } else {
                Add-Result "WARN" "Flows" "$($expected.Name)" "Expected $stateLabel but found $actualLabel"
            }
        }
    } catch {
        Add-Result "FAIL" "Flows" "Flows query succeeded" $_.Exception.Message
    }
}

function Test-ConnectionReferences {
    Write-Header "Connection References"
    try {
        $resp = Invoke-DvApiPac "connectionreferences?`$filter=startswith(connectionreferencelogicalname,'ppmf_')&`$select=connectionreferencelogicalname,connectionid,statecode"
        $refs = $resp.value

        foreach ($logicalName in $EXPECTED_CONNECTION_REFS) {
            $match = $refs | Where-Object { $_.connectionreferencelogicalname -eq $logicalName } | Select-Object -First 1
            if (-not $match) {
                Add-Result "FAIL" "Connection References" $logicalName "Not found"
                continue
            }
            if ($match.statecode -ne 0) {
                Add-Result "WARN" "Connection References" $logicalName "Exists but is Inactive"
                continue
            }
            if (-not $match.connectionid) {
                Add-Result "WARN" "Connection References" $logicalName "Active but not assigned — flows will fail at runtime"
                continue
            }
            Add-Result "PASS" "Connection References" "$logicalName — Assigned"
        }
    } catch {
        Add-Result "FAIL" "Connection References" "Connection reference query succeeded" $_.Exception.Message
    }
}

function Test-EnvironmentVariables {
    Write-Header "Environment Variables"
    try {
        $resp = Invoke-DvApiPac "environmentvariabledefinitions?`$filter=startswith(schemaname,'ppmf_')&`$select=schemaname,isrequired&`$expand=environmentvariablevalues(`$select=value)"
        $defs = $resp.value

        foreach ($schemaName in $EXPECTED_ENV_VARS) {
            $match = $defs | Where-Object { $_.schemaname -eq $schemaName } | Select-Object -First 1
            if (-not $match) {
                Add-Result "FAIL" "Environment Variables" $schemaName "Definition not found"
                continue
            }

            $hasValue = ($match.environmentvariablevalues -and $match.environmentvariablevalues.Count -gt 0)
            $isRequired = $match.isrequired

            if ($hasValue) {
                Add-Result "PASS" "Environment Variables" "$schemaName — value set"
            } elseif ($isRequired) {
                Add-Result "WARN" "Environment Variables" $schemaName "Required but no value set — using default if one exists"
            } else {
                Add-Result "PASS" "Environment Variables" "$schemaName — using default"
            }
        }
    } catch {
        Add-Result "FAIL" "Environment Variables" "Environment variable query succeeded" $_.Exception.Message
    }
}

function Test-SecurityRoles {
    Write-Header "Security Roles"
    try {
        $resp = Invoke-DvApiPac "roles?`$filter=startswith(name,'PPMF')&`$select=name"
        $roles = $resp.value

        foreach ($roleName in $EXPECTED_ROLES) {
            $match = $roles | Where-Object { $_.name -eq $roleName } | Select-Object -First 1
            if ($match) {
                Add-Result "PASS" "Security Roles" $roleName
            } else {
                Add-Result "FAIL" "Security Roles" $roleName "Not found"
            }
        }
    } catch {
        Add-Result "FAIL" "Security Roles" "Security role query succeeded" $_.Exception.Message
    }
}

function Test-WebResources {
    Write-Header "Web Resources"
    try {
        $resp = Invoke-DvApiPac "webresourceset?`$filter=startswith(name,'$WEB_RESOURCE_PREFIX')&`$select=name,webresourcetype"
        $resources = $resp.value

        if ($resources.Count -gt 0) {
            Add-Result "PASS" "Web Resources" "$($resources.Count) web resource(s) with prefix '$WEB_RESOURCE_PREFIX' found"

            # Spot-check key resources
            $keyResources = @("ppmf_config_setup", "ppmf_connectionrefs", "ppmf_releasenotes", "ppmf_base")
            foreach ($key in $keyResources) {
                $match = $resources | Where-Object { $_.name -like "*$key*" } | Select-Object -First 1
                if ($match) {
                    Add-Result "PASS" "Web Resources" "$key found"
                } else {
                    Add-Result "WARN" "Web Resources" $key "Not found — may not have deployed correctly"
                }
            }
        } else {
            Add-Result "FAIL" "Web Resources" "Web resources with prefix '$WEB_RESOURCE_PREFIX'" "None found"
        }
    } catch {
        Add-Result "FAIL" "Web Resources" "Web resource query succeeded" $_.Exception.Message
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

function Write-Summary {
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    $total     = $script:PassCount + $script:WarnCount + $script:FailCount

    Write-Host ""
    Write-Host "$('═' * 64)" -ForegroundColor DarkGray
    Write-Host "  PPMF Deployment Validation Summary" -ForegroundColor White
    Write-Host "  Environment : $EnvironmentUrl" -ForegroundColor DarkGray
    Write-Host "  Version     : $ExpectedVersion" -ForegroundColor DarkGray
    Write-Host "  Timestamp   : $timestamp" -ForegroundColor DarkGray
    Write-Host "$('═' * 64)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Total checks : $total" -ForegroundColor Gray
    Write-Host "  Passed       : $($script:PassCount)" -ForegroundColor Green
    Write-Host "  Warnings     : $($script:WarnCount)" -ForegroundColor Yellow
    Write-Host "  Failed       : $($script:FailCount)" -ForegroundColor $(if ($script:FailCount -gt 0) { "Red" } else { "Gray" })
    Write-Host ""

    if ($script:FailCount -eq 0 -and $script:WarnCount -eq 0) {
        Write-Host "  ✔  All checks passed. Deployment is healthy." -ForegroundColor Green
    } elseif ($script:FailCount -eq 0) {
        Write-Host "  ⚠  Deployment succeeded with $($script:WarnCount) warning(s)." -ForegroundColor Yellow
        Write-Host "     Review warnings above — some may require action before flows run correctly." -ForegroundColor DarkGray
    } else {
        Write-Host "  ✖  Deployment has $($script:FailCount) failure(s). Remediation required." -ForegroundColor Red
    }

    Write-Host ""
}

# ── Main ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "PPMF Deployment Validator" -ForegroundColor White
Write-Host "Solution : $SOLUTION_NAME" -ForegroundColor DarkGray
Write-Host "Target   : $EnvironmentUrl" -ForegroundColor DarkGray

$script:UsePacCli = $false

Get-AccessToken

Test-SolutionVersion
Test-Flows
Test-ConnectionReferences
Test-EnvironmentVariables
Test-SecurityRoles
Test-WebResources

Write-Summary

# Exit 1 if any check failed (allows CI to gate on this)
if ($script:FailCount -gt 0) { exit 1 }
exit 0
