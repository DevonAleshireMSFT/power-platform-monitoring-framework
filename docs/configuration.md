# Configuration

All PPMF runtime configuration is managed through **environment variables** in the solution. No flow edits are required. Values are set from **Solutions → [Solution] → Environment Variables** or from the **Setup & Configuration** page in the PPMF Platform Monitor app.

---

## Environment Variables

### Required

These must be configured before PPMF will reliably process errors.

| Schema Name | Display Name | Default | Description |
|---|---|---|---|
| `ppmf_EnvironmentName` | Environment Name | *(none)* | A short label identifying this environment in Teams alerts and error records — e.g. `Production`, `UAT`, `Dev`. Shown in the subject line of every alert message. |
| `ppmf_TeamID` | Team ID | *(none)* | The Azure AD group ID (GUID) of the Microsoft Teams team where alerts will be posted. Find it in Teams Admin Center under the team details, or from the `groupId` query parameter in the Teams client URL. |
| `ppmf_FlowAlertsChannelID` | Flow Alerts Channel ID | *(none)* | The internal Teams channel ID (starts with `19:`) for the default alert destination. Visible in the channel URL after `/channel/` — URL-decode `%3A` → `:` and `%40` → `@`. Used as fallback when no Alert Route matches. |
| `ppmf_PortalBaseUrl` | Portal Base URL | *(none)* | Base URL of the Power Automate portal used to construct deep links in alert messages. Do not include a trailing slash. See cloud values below. |
| `ppmf_WritingMode` | Writing Mode | `Dataverse` | Controls where error events are written. See [Writing Modes](#writing-modes). |

### Optional / Advanced

| Schema Name | Display Name | Default | Description |
|---|---|---|---|
| `ppmf_AlertThrottleMinutes` | Alert Throttle Window (Minutes) | `15` | Suppression window that prevents repeat Teams alerts for the same failing flow within this period. Failures are still logged to Dataverse; only the alert is suppressed. Set to `0` to disable throttling. |
| `ppmf_RetentionDays` | Error Retention Days | `90` | Days to retain resolved error records before the weekly maintenance flow deletes them. Only records with status Fixed, Duplicate, Won't Fix, or Closed and an occurrence date older than this threshold are deleted. Set to `0` to disable automatic deletion. |

### SharePoint (required when Writing Mode is `SharePoint` or `Both`)

| Schema Name | Display Name | Default | Description |
|---|---|---|---|
| `ppmf_SharePointSiteUrl` | SharePoint Site URL | *(none)* | Full URL of the SharePoint site hosting the PPMF error list. Example: `https://contoso.sharepoint.com/sites/PPMF`. No trailing slash. The SharePoint connection account must have Contribute access. |
| `ppmf_SharePointListName` | SharePoint List Name | `PPMF Error Events` | Exact display name of the SharePoint list. The list must be provisioned before the first flow run in SharePoint or Both mode. |

### SharePoint sync (required when `ppmf_DataverseSyncEnabled` is `Yes`)

| Schema Name | Display Name | Default | Description |
|---|---|---|---|
| `ppmf_DataverseSyncEnabled` | Dataverse Sync Enabled | `No` | Set to `Yes` to enable the `PPMF-Sync-SharePointErrorsToDataverse` recurrence flow. Only enable after Dataverse tables are provisioned and the Dataverse connection reference is assigned. |
| `ppmf_SyncIntervalMinutes` | Sync Interval Minutes | `15` | Documents the intended sync frequency. The trigger interval is fixed at 15 minutes in the flow definition; edit the flow directly to change it. |
| `ppmf_SyncBatchSize` | Sync Batch Size | `100` | Maximum number of SharePoint items processed per sync run. Reduce if Dataverse or SharePoint throttle errors appear in the sync flow run history. |

---

## Writing Modes

The `ppmf_WritingMode` environment variable controls where error events are persisted. Accepted values are **case-sensitive**.

| Value | Behaviour | Requirements |
|---|---|---|
| `Dataverse` | Writes only to the `ppmf_ErrorEvent` Dataverse table. | Dataverse environment; Dataverse connection reference assigned. |
| `SharePoint` | Writes only to the configured SharePoint list. Use in environments without Dataverse. | SharePoint site and list provisioned; `ppmf_SharePointSiteUrl` and `ppmf_SharePointListName` configured; SharePoint connection reference assigned. |
| `Both` | Writes to both Dataverse and SharePoint simultaneously. Use during migration or for dual-store redundancy. | All requirements for both `Dataverse` and `SharePoint` modes. |

---

## Portal Base URL (by cloud)

Set `ppmf_PortalBaseUrl` to the correct value for your cloud so that deep links in Teams alert messages work.

| Cloud | Value |
|---|---|
| Commercial | `https://make.powerautomate.com` |
| GCC | `https://make.powerautomate.com` |
| GCC High | `https://make.powerautomate.appsplatform.us` |
| DoD | `https://make.powerautomate.appsplatform.mil` |

---

## SharePoint List Provisioning

The PPMF SharePoint list must be created before the first flow run in `SharePoint` or `Both` mode. Use the included provisioning script to create it with the correct column schema:

```powershell
.\scripts\New-PPMFSharePointList.ps1 `
    -SiteUrl  "https://contoso.sharepoint.com/sites/PPMF" `
    -ListName "PPMF Error Events"
```

The script requires the [PnP.PowerShell](https://pnp.github.io/powershell/) module and prompts for interactive authentication. Run it once per environment. After the list is created, set `ppmf_SharePointSiteUrl` and `ppmf_SharePointListName` to match, set `ppmf_WritingMode` to `SharePoint` or `Both`, and assign the SharePoint connection reference.

---

## Connection References

Three connection references must be assigned before activating flows:

| Logical Name | Connector | Required For |
|---|---|---|
| `ppmf_DataverseConnectionReference` | Microsoft Dataverse | All Dataverse writes; skip if `ppmf_WritingMode` is `SharePoint` |
| `ppmf_TeamsConnectionReference` | Microsoft Teams | All Teams alert messages |
| `ppmf_SharePointConnectionReference` | SharePoint | SharePoint writes and sync; skip if `ppmf_WritingMode` is `Dataverse` |

Open **Configuration → Connection References** in the PPMF Platform Monitor app to verify assignment status. The page shows the owner, solution membership, and dependent flow count for every connection reference in the environment.
