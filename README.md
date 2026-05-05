# Power Platform Monitoring Framework (PPMF)

> **v1.0.0.10** · Unmanaged solution · Requires Microsoft Teams · Dataverse optional (SharePoint mode available)

PPMF is an enterprise-ready observability solution for the Microsoft Power Platform. When a Power Automate flow fails or a Canvas App encounters an error, PPMF automatically captures structured error data into Dataverse, sends a formatted adaptive card alert to a Microsoft Teams channel, and creates a trackable triage record — without requiring any significant changes to your existing flows.

Teams are alerted the moment something breaks. Every failure is logged and triaged. Nothing gets lost.

Compatible with **Commercial**, **GCC**, **GCC High**, and **DoD** cloud environments.

---

## Why PPMF

Power Platform environments often have dozens or hundreds of flows running across multiple solutions, with no centralized visibility into failures. When a flow breaks, it typically goes unnoticed until a user reports an issue — by which time business processes may already be impacted.

PPMF solves this by:

- **Alerting immediately** — a formatted Teams card is posted the moment a failure is detected, with a direct link to the failed flow run
- **Logging everything** — every failure creates a Dataverse record, whether or not an alert was sent
- **Routing intelligently** — different solutions can be directed to dedicated Teams channels with configurable severity thresholds
- **Preventing noise** — a configurable throttle window suppresses repeat alerts for the same failing flow
- **Enabling structured triage** — error records move through a tracked workflow (New → In Progress → Fixed) with fields for root cause, suggested fix, work item links, and assignment
- **Cleaning itself up** — a weekly maintenance flow automatically deletes resolved records past the configured retention threshold

---

## What's Included

| Component | Description |
|---|---|
| **3 Dataverse tables** | `ppmf_errorevent` (error records), `ppmf_alertroute` (routing rules), `ppmf_errornote` (triage notes) |
| **11 Power Automate flows** | Error capture, Teams alerting, Canvas App handling, SharePoint write, SharePoint sync, demo flow, and weekly maintenance |
| **12 Environment variables** | All runtime configuration in one place — no flow edits required |
| **4 Security roles** | Admin, Triager, Reader, Service Account |
| **Model-driven app** | PPMF Platform Monitor — triage views, alert route management, and configuration |
| **In-app documentation** | Full architecture overview, integration guides, and field reference |
| **In-app release notes** | Changelog accessible from the Documentation page |

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Microsoft Teams | Required. The connection account must be a member of the target team |
| Power Platform environment with Dataverse | Required for `Dataverse` or `Both` writing mode. Not required when using `SharePoint` mode |
| SharePoint site with Contribute access | Required for `SharePoint` or `Both` writing mode. Not required when using `Dataverse` mode |
| System Administrator or solution importer role | Required to import the solution |

---

## Import

1. Go to [make.powerapps.com](https://make.powerapps.com) (or your sovereign cloud equivalent) and select your target environment.
2. Navigate to **Solutions → Import solution**.
3. Upload `PowerPlatformMonitoringFramework.zip` and complete the import wizard.
4. Once the import completes, open the **PPMF Platform Monitor** app from the Apps list.

---

## Getting Started

The solution includes a guided setup experience. After import:

1. Open **Configuration → Setup & Configuration** inside the PPMF Platform Monitor app.
2. Follow the on-screen checklist — it covers connection references, flow activation, and environment variable configuration.
3. If deploying without Dataverse, set `ppmf_WritingMode` to `SharePoint`, configure the SharePoint site URL and list name, and assign the SharePoint connection reference. See the **SharePoint Error Store** section of the Setup page.
4. The page runs 11 automated checks and displays a pass/warn/fail result for each. All checks must be green before PPMF will reliably process errors.
5. Run the built-in demo flow to confirm end-to-end alerting works before integrating your first production flow.

For full instructions, integration guides, and field reference documentation, open **Help → Documentation** inside the app.

---

## Flow Activation Order

> **Important:** Flows must be activated in the correct order. Each child flow is called by the flow above it in the pipeline. If a parent flow is turned on before its children are active, activation will fail with a `ChildFlowNeverPublished` error and error handling will not work.

**Navigate to:** Solutions → Power Platform Monitoring Framework → Cloud flows → select each flow → **Turn on**. Wait for **On** status before activating the next flow.

### Dataverse mode — activate in this exact order:

| # | Flow |
|---|---|
| 1 | `PPMF-Child-FlowWritetoIntakeList` |
| 2 | `PPMF-Child-ProcessFlowError` |
| 3 | `PPMF-Child-FlowErrorHandler-JSON` |
| 4 | `PPMF-Child-FlowErrorHandler-Parameters` |
| 5 | `PPMF-Delete-Old-Errors` |
| 6 | `PPMF-Demo-Flow-Failure` ← activate last |

### SharePoint or Both mode — add these before step 4 above:

| # | Flow |
|---|---|
| 1 | `PPMF-Child-WriteErrorToSharePoint` ← innermost, activate first |
| 2 | `PPMF-Child-FlowErrorHandler-SharePoint` |

### Canvas App error handling — also activate:
- `PPMF-Power-Apps-Error-Handler-JSON` — activate before the demo flow

> If a flow fails to activate with **"ChildFlowNeverPublished"**, one of its dependencies is still Off. Return to the bottom of the list and work upward again.

---

## Security & Access Control

Four purpose-built security roles are included in the solution. Assign from **Settings → Users + Permissions → Security Roles** in your environment.

| Role | Assign To | Permissions |
|---|---|---|
| **PPMF - Admin** | Power Platform administrators and solution owners | Full Create/Read/Write/Delete/Append/Assign/Share at Organization level on all three PPMF tables |
| **PPMF - Triager** | Support analysts and developers investigating errors | Read/Write on `ppmf_ErrorEvent` (Org); Create/Read/Write/Delete on own `ppmf_ErrorNote` records; Read-only on `ppmf_AlertRoute` |
| **PPMF - Reader** | Stakeholders and auditors requiring visibility only | Read-only access to all three PPMF tables. No create, write, or delete privileges |
| **PPMF - Service Account** | Dataverse application user backed by an **Azure AD app registration (service principal)** — **do not assign to human users** | Create/Read on `ppmf_ErrorEvent`; Create/Append on `ppmf_ErrorNote`; Read-only on `ppmf_AlertRoute` |

> **Service principal, not a licensed service account:** This role is designed for a Dataverse **application user** created from an Azure AD app registration. A service principal does not require a Power Platform license. Do not create a licensed user account for this purpose. To set this up: register an app in Azure AD, create a Dataverse application user linked to that app registration, and assign it the **PPMF - Service Account** role. Assigning this role to a human user will prevent that user from accessing the PPMF Platform Monitor app.

---

## Contributing

This solution is stored in PAC-unpacked format for source control. To contribute:

1. Fork or clone the repository.
2. Make changes to the unpacked files.
3. Pack and import to test: `pac solution pack --folder . --zipFile ..\test.zip --packagetype Unmanaged`
4. Submit a pull request with a clear description of the change.

---

*Built with assistance from [GitHub Copilot](https://github.com/features/copilot) (Claude Sonnet 4.6). All output reviewed by a human.*
