# Power Platform Monitoring Framework (PPMF)

> Unmanaged solution · Requires Microsoft Teams · Dataverse optional (SharePoint mode available)

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
| **Model-driven app** | PPMF Platform Monitor — triage views, alert route management, connection reference review, and configuration |
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

## Documentation

| Topic | Description |
|---|---|
| [Deployment](docs/deployment.md) | Manual import, CI/CD pipeline setup, GitHub Actions secrets, post-deploy health check |
| [Configuration](docs/configuration.md) | All 12 environment variables, writing modes, SharePoint list provisioning |
| [Security Roles](docs/security-roles.md) | Role reference, assignment guide, service principal setup |

---

## Quick Start

1. Import the solution — see [Deployment](docs/deployment.md).
2. Open **Configuration → Setup & Configuration** inside the PPMF Platform Monitor app and follow the on-screen checklist.
3. Run the built-in demo flow to confirm end-to-end alerting works.

For full instructions, integration guides, and field reference documentation, open **Help → Documentation** inside the app.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

---

*Built with assistance from [GitHub Copilot](https://github.com/features/copilot) (Claude Sonnet 4.6). All output reviewed by a human.*
