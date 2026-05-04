# Power Platform Monitoring Framework (PPMF)

> **v1.0.0.9** · Unmanaged solution · Requires Dataverse and Microsoft Teams

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
| **8 Power Automate flows** | Error capture, Teams alerting, Canvas App handling, demo flow, and weekly maintenance |
| **6 Environment variables** | All runtime configuration in one place — no flow edits required |
| **4 Security roles** | Admin, Triager, Reader, Service Account |
| **Model-driven app** | PPMF Platform Monitor — triage views, alert route management, and configuration |
| **In-app documentation** | Full architecture overview, integration guides, and field reference |
| **In-app release notes** | Changelog accessible from the Documentation page |

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Power Platform environment with Dataverse | Commercial, GCC, GCC High, or DoD |
| Microsoft Teams | The connection account must be a member of the target team |
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
3. The page runs 8 automated checks and displays a pass/warn/fail result for each. All checks must be green before PPMF will reliably process errors.
4. Run the built-in demo flow to confirm end-to-end alerting works before integrating your first production flow.

For full instructions, integration guides, and field reference documentation, open **Help → Documentation** inside the app.

---

## Contributing

This solution is stored in PAC-unpacked format for source control. To contribute:

1. Fork or clone the repository.
2. Make changes to the unpacked files.
3. Pack and import to test: `pac solution pack --folder . --zipFile ..\test.zip --packagetype Unmanaged`
4. Submit a pull request with a clear description of the change.

---

*Built with assistance from [GitHub Copilot](https://github.com/features/copilot) (Claude Sonnet 4.6). All output reviewed by a human.*
