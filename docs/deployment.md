# Deployment

This page covers importing PMF manually and deploying it via the automated CI/CD pipeline.

---

## Manual Import

1. Go to [make.powerapps.com](https://make.powerapps.com) (or your sovereign cloud equivalent) and select your target environment.
2. Navigate to **Solutions → Import solution**.
3. Upload `PowerPlatformMonitoringFramework.zip` and complete the import wizard.
4. Once the import completes, open the **PMF Platform Monitor** app from the Apps list.
5. Open **Configuration → Setup & Configuration** and follow the on-screen checklist — it covers connection references, flow activation, and environment variable configuration.
6. Run the built-in demo flow to confirm end-to-end alerting works before integrating your first production flow.

> **Connection references:** Before activating flows, all three connection references must be assigned. Open **Configuration → Connection References** to verify assignment status. An unassigned reference will cause dependent flows to fail silently at runtime.

---

## CI/CD Pipeline

The repository includes a GitHub Actions workflow that automatically packs and imports the solution to a dev environment on every push to the `dev` branch.

**Workflow file:** `.github/workflows/deploy-dev.yml`

### Pipeline steps

| Step | What it does |
|---|---|
| Checkout | Checks out the repository |
| Extract solution version | Reads `Solution.xml` via XPath and exposes the version as a step output |
| Install PAC CLI | Installs the Power Platform CLI via `microsoft/powerplatform-actions/actions-install@v1` |
| Pack solution (unmanaged) | Packs `PowerPlatformMonitoringFramework/` into an unmanaged zip using `microsoft/powerplatform-actions/pack-solution@v1` |
| Generate deployment settings | Writes a `deploymentsettings.json` that maps connection reference logical names to connection IDs from secrets |
| Import to Dev environment | Imports the packed solution with force-overwrite and publish-changes enabled |
| Deployment health check | Runs `scripts/Test-PPMFDeployment.ps1` to validate the import was complete and at the expected version |

### Trigger

Pushes to `dev` that touch files under `PowerPlatformMonitoringFramework/**` or `.github/workflows/deploy-dev.yml`. Can also be triggered manually via `workflow_dispatch`.

### Required GitHub Secrets

Configure these under **Settings → Secrets and variables → Actions** in the repository.

| Secret | Description |
|---|---|
| `PP_CLIENT_ID` | Azure app registration client ID |
| `PP_CLIENT_SECRET` | Azure app registration client secret |
| `PP_TENANT_ID` | Azure AD / Entra ID tenant ID |
| `PP_DEV_ENVIRONMENT_URL` | Dev environment URL, e.g. `https://orgXXXXXXXX.crm.microsoftdynamics.us/` |
| `PP_DV_CONNECTION_ID` | Dataverse connection ID from the maker portal (Data → Connections → Dataverse → copy ID from URL) |
| `PP_TEAMS_CONNECTION_ID` | Teams connection ID from the maker portal |
| `PP_SP_CONNECTION_ID` | SharePoint connection ID from the maker portal |

### Service principal setup

1. Register an app in Entra ID.
2. In the Power Platform admin centre, add the app as an **application user** in the target environment and assign it the **System Administrator** role.
3. Store the client ID, secret, and tenant ID as the secrets above.

> The pipeline is currently configured for **GCC High** (`cloud: UsGovHigh`). For other clouds, update the `cloud` parameter in the workflow and in the health check step.

---

## Release Pipeline

The repository includes a second workflow that runs on every version tag push and handles the full production release.

**Workflow file:** `.github/workflows/release.yml`

### Pipeline steps

| Step | What it does |
|---|---|
| Extract version | Strips `v` prefix from the tag name and exposes it as a step output |
| Validate version | Asserts tag version matches `<Version>` in `Solution.xml` — fails if mismatched |
| Extract changelog entry | Reads the matching `## [version]` section from `CHANGELOG.md` for use as the release body — fails if no entry found |
| Install PAC CLI | Installs the Power Platform CLI |
| Pack (unmanaged) | Packs an unmanaged zip for source reference |
| Set Managed flag | Temporarily sets `<Managed>1</Managed>` in `Solution.xml` for the managed pack |
| Pack (managed) | Packs the managed zip for production import |
| Create GitHub Release | Publishes the release with both zips as assets and changelog content as the body |
| Generate deployment settings | Writes `deploymentsettings.json` mapping connection references to prod connection IDs |
| Import managed solution | Imports the managed zip to production with force-overwrite and publish-changes |
| Re-activate PMF flows | PATCHes the 9 production flows back to Active via the Dataverse API (managed imports always deactivate flows) |
| Deployment health check | Runs `scripts/Test-PPMFDeployment.ps1` against production |
| Sync main into dev | Merges `origin/main` back into `dev` to keep branch histories aligned |

### Trigger

Push of a tag matching `v#.#.#.#` (e.g. `v1.0.0.11`).

### Required additional secrets for production

| Secret | Description |
|---|---|
| `PP_PROD_ENVIRONMENT_URL` | Production environment URL |

The same `PP_CLIENT_ID`, `PP_CLIENT_SECRET`, `PP_TENANT_ID`, `PP_DV_CONNECTION_ID`, `PP_TEAMS_CONNECTION_ID`, and `PP_SP_CONNECTION_ID` secrets are shared with the dev pipeline — ensure the service principal and connection IDs are valid for the production environment.

### Pre-release checklist

Before pushing a tag:
1. Update `<Version>` in `PowerPlatformMonitoringFramework/Other/Solution.xml`
2. Add a `## [version]` entry to `CHANGELOG.md`
3. Update the in-app release notes web resource (`ppmf_releasenotes`)
4. Merge `feature/*` → `dev`, validate in dev, then merge `dev` → `main`
5. Tag `main`: `git tag -a v1.0.0.11 -m "Release v1.0.0.11" && git push origin v1.0.0.11`

---

## Post-Deploy Health Check

`scripts/Test-PPMFDeployment.ps1` validates that a PMF deployment is complete and correctly configured. It is run automatically at the end of the CI pipeline and can also be run locally.

### What it checks

| Category | Checks |
|---|---|
| Solution | Exists at the expected version |
| Flows | All 11 flows present; 9 active, 2 off by design |
| Connection references | All 3 present and assigned |
| Environment variables | All 12 schema names registered |
| Security roles | All 4 present |
| Web resources | `ppmf_` prefix present; 4 spot-checks |

**Exit codes:** `0` = all checks passed (or passed with warnings); `1` = one or more checks failed.

### Local usage (interactive auth)

Requires an active PAC CLI profile pointing at the target environment (`pac auth select`).

```powershell
.\scripts\Test-PPMFDeployment.ps1 -EnvironmentUrl "https://org.crm.dynamics.com"
```

For GCC High:

```powershell
.\scripts\Test-PPMFDeployment.ps1 `
    -EnvironmentUrl "https://org.crm.microsoftdynamics.us" `
    -Cloud          "UsGovHigh"
```

### CI usage (service principal)

```powershell
$secret = ConvertTo-SecureString $env:PP_CLIENT_SECRET -AsPlainText -Force

.\scripts\Test-PPMFDeployment.ps1 `
    -EnvironmentUrl  "https://org.crm.microsoftdynamics.us" `
    -ClientId        $env:PP_CLIENT_ID `
    -ClientSecret    $secret `
    -TenantId        $env:PP_TENANT_ID `
    -Cloud           "UsGovHigh" `
    -ExpectedVersion "1.0.0.11"
```

### Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `-EnvironmentUrl` | `string` | Yes | Environment URL. Must start with `https://` |
| `-ClientId` | `string` | CI only | App registration client ID |
| `-ClientSecret` | `SecureString` | CI only | App registration client secret as a SecureString |
| `-TenantId` | `string` | CI only | Entra ID tenant ID |
| `-Cloud` | `string` | No | `UsGov`, `UsGovHigh`, `UsGovDod`, or omit for Commercial |
| `-ExpectedVersion` | `string` | No | Solution version to assert. Defaults to `1.0.0.11` |

### Cloud values

The `-Cloud` parameter controls the Azure AD authority used for authentication. The OAuth2 resource is always set to the environment URL, which works across all cloud boundaries including sovereign tenants that do not have generic cloud-level service principals registered.

| Cloud | `-Cloud` value | Authority |
|---|---|---|
| Commercial | *(omit)* | `login.microsoftonline.com` |
| GCC | `UsGov` | `login.microsoftonline.us` |
| GCC High | `UsGovHigh` | `login.microsoftonline.us` |
| DoD | `UsGovDod` | `login.microsoftonline.us` |
