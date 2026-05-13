# Contributing

Thanks for your interest in contributing to PPMF. This page covers the development workflow, branch strategy, and pull request guidelines.

---

## Prerequisites

- [Power Platform CLI (PAC)](https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction) installed and authenticated (`pac auth create`)
- PowerShell 7.0 or later
- A non-production Power Platform environment for testing

---

## Repository Structure

The solution is stored in **PAC CLI unpacked format** for source control. This means the `PowerPlatformMonitoringFramework/` folder contains individual XML, JSON, and data files — not a zip file.

```
PowerPlatformMonitoringFramework/   ← PAC-unpacked solution source
  Entities/
  Workflows/
  WebResources/
  environmentvariabledefinitions/
  Other/
    Solution.xml                    ← contains solution version
    Customizations.xml
  ...
scripts/                            ← deployment and validation scripts
docs/                               ← documentation
.github/workflows/                  ← CI/CD pipelines
```

---

## Development Workflow

### 1. Branch

Create a feature branch from `dev`:

```bash
git checkout dev
git pull
git checkout -b feature/your-feature-name
```

### 2. Make changes in the environment

Make your changes in a non-production environment using the Power Apps / Power Automate makers, then export the solution.

### 3. Unpack the solution

Export the solution as an **unmanaged** zip from your environment, then unpack it with PAC CLI:

```powershell
pac solution unpack `
    --zipFile  .\PowerPlatformMonitoringFramework_unmanaged.zip `
    --folder   .\PowerPlatformMonitoringFramework `
    --packageType Unmanaged `
    --allowDelete
```

> `--allowDelete` removes files from the unpacked folder that no longer exist in the solution. Omit it if you are making targeted manual edits and want to preserve uncommitted changes.

### 4. Update the solution version

Increment the version in `PowerPlatformMonitoringFramework/Other/Solution.xml`:

```xml
<Version>1.0.0.12</Version>
```

Use semantic versioning: `MAJOR.MINOR.PATCH.BUILD`. For most changes, increment the `PATCH` or `BUILD` segment.

### 5. Pack and test locally

```powershell
pac solution pack `
    --folder      .\PowerPlatformMonitoringFramework `
    --zipFile     .\out\test.zip `
    --packageType Unmanaged

pac solution import `
    --path .\out\test.zip `
    --environment-url "https://your-test-env.crm.dynamics.com" `
    --force-overwrite
```

Run the health check script to validate the import:

```powershell
.\scripts\Test-PPMFDeployment.ps1 `
    -EnvironmentUrl  "https://your-test-env.crm.dynamics.com" `
    -ExpectedVersion "1.0.0.12"
```

### 6. Commit and push

```bash
git add PowerPlatformMonitoringFramework/
git commit -m "feat: description of change"
git push -u origin HEAD
```

### 7. Open a pull request

Target `dev`. See [Pull Request Guidelines](#pull-request-guidelines) below.

---

## Branch Strategy

| Branch | Purpose |
|---|---|
| `main` | Stable, release-tagged code. Only merged into from `dev` via a release PR |
| `dev` | Integration branch and default branch. All feature branches merge here. Triggers the dev CI pipeline on push |
| `feature/*` | Feature or fix branches. Branch from `dev`, merge back to `dev` |
| `fix/*` | Bug fix branches. Branch from `dev`, merge back to `dev` |

After merging a release PR (`dev → main`) and pushing a tag, the release pipeline automatically merges `main` back into `dev` to keep branch histories aligned. No manual sync is required.

---

## Release Process

1. Increment `<Version>` in `PowerPlatformMonitoringFramework/Other/Solution.xml`
2. Add a `## [version]` section to `CHANGELOG.md`
3. Update the in-app release notes web resource (`ppmf_releasenotes`)
4. Merge `dev → main` via a release PR
5. Tag `main` with an annotated tag:
   ```bash
   git checkout main && git pull
   git tag -a v1.0.0.11 -m "Release v1.0.0.11 — brief description"
   git push origin v1.0.0.11
   ```
6. The release pipeline (`release.yml`) triggers automatically and handles packaging, GitHub Release creation, production import, flow re-activation, health check, and syncing `main` back into `dev`.

---

## Pull Request Guidelines

- Target `dev` for all feature and fix PRs.
- Include a short description of what changed and why.
- If the change affects flows, connection references, or environment variables, note whether the health check script needs updating (`scripts/Test-PPMFDeployment.ps1`).
- If the change increments the solution version, update `CHANGELOG.md` with the new version entry.
- The dev CI pipeline (`deploy-dev.yml`) runs automatically on merge to `dev` and will fail if the health check does not pass.

---

## Web Resource Development

Web resources (HTML/JS pages in the model-driven app) live under `PowerPlatformMonitoringFramework/WebResources/`. Each resource has a companion `.data.xml` file that contains metadata.

To test a web resource change locally:
1. Edit the file in the unpacked folder.
2. Pack and import to your test environment (steps 5–6 above), or upload the individual file via **Solutions → [Solution] → Web Resources** in the maker portal.
3. Clear the browser cache and refresh the model-driven app.

---

## Scripts

| Script | Description |
|---|---|
| `scripts/Test-PPMFDeployment.ps1` | Post-deploy validation — verifies the solution is complete and configured. See [Deployment](docs/deployment.md#post-deploy-health-check). |
| `scripts/New-PPMFSharePointList.ps1` | Provisions the PPMF SharePoint list with the required column schema. Requires PnP.PowerShell. |
