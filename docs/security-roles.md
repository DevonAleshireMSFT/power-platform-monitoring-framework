# Security Roles

PPMF includes four purpose-built security roles. Assign them from **Settings → Users + Permissions → Security Roles** in your environment, or from the Power Platform admin centre.

---

## Role Reference

| Role | Assign To | Permissions |
|---|---|---|
| **PPMF - Admin** | Power Platform administrators and solution owners | Full Create/Read/Write/Delete/Append/Assign/Share at Organization level on all three PPMF tables |
| **PPMF - Triager** | Support analysts and developers investigating errors | Read/Write on `ppmf_ErrorEvent` (Org scope); Create/Read/Write/Delete on own `ppmf_ErrorNote` records; Read-only on `ppmf_AlertRoute` |
| **PPMF - Reader** | Stakeholders and auditors requiring visibility only | Read-only access to all three PPMF tables. No create, write, or delete privileges |
| **PPMF - Service Account** | Dataverse application user (service principal) — **do not assign to human users** | Create/Read on `ppmf_ErrorEvent`; Create/Append on `ppmf_ErrorNote`; Read-only on `ppmf_AlertRoute` |

---

## Service Principal Setup

**PPMF - Service Account** is designed for a Dataverse **application user** backed by an Azure AD / Entra ID app registration. It does not require a Power Platform license.

1. **Register an app in Entra ID.** No API permissions are required for the Dataverse application user — the Dataverse role grants the necessary access.
2. **Create a Dataverse application user.** In the Power Platform admin centre, go to the target environment → **Settings → Users + Permissions → Application Users → New app user**. Select the app registration created in step 1.
3. **Assign the PPMF - Service Account role** to the application user.
4. Store the client ID and secret securely (e.g. GitHub Actions secrets, Azure Key Vault). Never commit credentials to source control.

> Assigning the **PPMF - Service Account** role to a human user will prevent that user from accessing the PPMF Platform Monitor model-driven app, as the role does not include the access required to open the application. Use **PPMF - Admin**, **PPMF - Triager**, or **PPMF - Reader** for human users.

---

## Role Design Notes

- All three human-facing roles (**Admin**, **Triager**, **Reader**) grant sufficient access to open and use the PPMF Platform Monitor app.
- **Triager** is scoped to write on their own notes only — this prevents analysts from modifying other people's triage notes while still allowing full write access to error event fields (status, assignment, root cause, etc.).
- **Reader** is entirely non-destructive and is appropriate for stakeholders who need visibility into error trends without the ability to change records.
- None of the PPMF roles grant access to tables outside the PPMF solution. They can be combined with existing environment security roles without conflict.
