# Changelog

All notable changes to PPMF are documented here. Versions follow `MAJOR.MINOR.PATCH.BUILD` and are reflected in `PowerPlatformMonitoringFramework/Other/Solution.xml`.

---

## [1.0.0.11] — 2026-05-08

### Added

- **Connection Reference Review page** — new page under Configuration in the PPMF Platform Monitor app. Displays assignment status, record owner, solution membership, and dependent flow count for every connection reference in the environment. Highlights unassigned references with a callout. Includes a filter bar (search, status, connector, solution, owner, hide system references) and expandable rows showing dependent flows with enable/disable state pills.
- **`scripts/Test-PPMFDeployment.ps1`** — post-deploy validation script. Asserts solution version, all 11 flows, all 3 connection references, all 12 environment variable definitions, all 4 security roles, and key web resources. Supports service principal (CI) and interactive PAC CLI (local) auth. Exits `1` on any failure.
- **CI/CD pipeline — Dev** (`.github/workflows/deploy-dev.yml`) — GitHub Actions workflow that packs and imports the solution to the dev environment on push to `dev`, then runs the health check script to validate the deployment.
- **CI/CD pipeline — Release** (`.github/workflows/release.yml`) — GitHub Actions workflow triggered on version tag push. Validates tag matches `Solution.xml`, packs unmanaged and managed zips, creates a GitHub Release with changelog content from `CHANGELOG.md`, imports the managed solution to production, re-activates flows, runs the health check, then merges `main` back into `dev` to keep branch histories in sync.

### Changed

- Solution version bumped to `1.0.0.11`.

### Fixed

- `Test-PPMFDeployment.ps1`: service principal auth branch not taken in CI — replaced `$PSBoundParameters.ContainsKey()` with direct value checks, which are reliable when PowerShell invokes the script from a GitHub Actions `run:` block.
- `Test-PPMFDeployment.ps1`: OAuth2 token request failed with `AADSTS500011 invalid_resource` in some sovereign tenants — replaced static cloud-level resource URIs with `$EnvironmentUrl` as the resource, which is always correct for direct Dataverse API access.
- `Test-PPMFDeployment.ps1`: three flow display names did not match actual Dataverse names (hyphens vs spaces) — corrected to `PPMF-Child-Flow Error Handler-JSON`, `PPMF-Child-Flow Error Handler-Parameters`, `PPMF-Child-Flow Write to Intake List`.
- `Test-PPMFDeployment.ps1`: environment variable query returned HTTP 400 — removed unsupported nested `$select` inside `$expand`; check now asserts definition presence only.
- `release.yml`: flows were left in a deactivated state after managed solution import — added a re-activation step that PATCHes the 9 production flows back to active via the Dataverse API.
- `release.yml`: GitHub Release page showed duplicate "What's Changed" sections — set `generate_release_notes: false` and replaced with changelog content extracted from `CHANGELOG.md`.

### Security

- `Test-PPMFDeployment.ps1` stores `$ClientSecret` as `[SecureString]`; plain text is extracted only at point of use and overwritten immediately after.
- `[ValidatePattern('^https://')]` enforced on `-EnvironmentUrl` to prevent token exfiltration to arbitrary hosts.
- CI pipeline wraps `PP_CLIENT_SECRET` with `ConvertTo-SecureString` before passing to the script.
- PAC CLI exit codes checked before `ConvertFrom-Json` in all code paths.
- `-TimeoutSec 30` added to all `Invoke-RestMethod` calls.

---

## [1.0.0.10]

### Added

- SharePoint writing mode — `ppmf_WritingMode` environment variable with values `Dataverse`, `SharePoint`, `Both`.
- `PPMF-Child-FlowErrorHandler-SharePoint` and `PPMF-Child-FlowWritetoIntakeList` child flows for SharePoint writes.
- `PPMF-Sync-SharePointErrorsToDataverse` recurrence flow to promote SharePoint errors into Dataverse.
- `ppmf_DataverseSyncEnabled`, `ppmf_SyncIntervalMinutes`, `ppmf_SyncBatchSize` environment variables.
- `scripts/New-PPMFSharePointList.ps1` provisioning script.

---

## [1.0.0.9]

### Added

- `ppmf_AlertThrottleMinutes` environment variable — configurable suppression window for repeat Teams alerts from the same flow.
- Alert Route (`ppmf_AlertRoute`) table and management views — route specific solutions to dedicated Teams channels.
- `PPMF - Reader` security role.

---

## [1.0.0.8]

### Added

- Initial release.
- `ppmf_ErrorEvent` and `ppmf_ErrorNote` Dataverse tables.
- `PPMF-Child-FlowErrorHandler-JSON` and `PPMF-Child-FlowErrorHandler-Parameters` child flows.
- `PPMF-Child-ProcessFlowError`, `PPMF-Delete-Old-Errors`, `PPMF-Get-Environment-Info` flows.
- `PPMF-Power-Apps-Error-Handler-JSON` Canvas App error handler.
- `PPMF-Demo-Flow-Failure` demo flow.
- PPMF Platform Monitor model-driven app with triage views, documentation page, and release notes page.
- `PPMF - Admin`, `PPMF - Triager`, `PPMF - Service Account` security roles.
- 9 environment variables: `ppmf_TeamID`, `ppmf_FlowAlertsChannelID`, `ppmf_EnvironmentName`, `ppmf_PortalBaseUrl`, `ppmf_RetentionDays`, `ppmf_SharePointSiteUrl`, `ppmf_SharePointListName`.
