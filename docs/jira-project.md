# Jira project

The lab is planned and tracked in Jira Cloud, project **`LNX` (Linux Admin Lab)**. The project doubles as Jira administration practice: each week adds one Jira skill alongside the Linux work.

## Setup

| Item | Value |
|---|---|
| Template | Scrum |
| Type | Company-managed (shared schemes, screens and field configurations) |
| Plan | Jira Free |
| Sprint length | 1 week |
| Estimation | Story points |

## Work types

A dedicated issue type scheme, `LNX: Issue Type Scheme`, keeps these changes away from the default scheme shared with other projects.

| Work type | Use |
|---|---|
| Epic | One per week of the roadmap (W00-W10) |
| Lab | Hands-on exercise on the lab VMs |
| Study | Reading, theory or exam objective review |
| Lab Issue | Something broke in the lab and needs troubleshooting |
| Task | Management and documentation work |
| Sub-task | Breakdown of any of the above |

## Jira skill roadmap

| Week | Jira skill |
|---|---|
| W00 | Issue type scheme, Scrum sprint, story points |
| W01 | Custom workflow and workflow scheme (`Backlog > Ready > In Lab > Documenting > Done`, plus `Blocked` and `Cancelled`) |
| W02 | Custom fields and separate create / edit / transition screens |
| W03 | Workflow conditions, validators and post-functions |
| W04 | Versions and release report |
| W05 | Automation rules |
| W06 | Jira forms (patch window checklist) |
| W07 | Advanced JQL, filters and dashboards |
| W08 | Components |
| W09 | Scheduled automation |
| W10 | Permission and notification schemes (needs a Standard plan trial) |

## Administration lessons

### Two story point fields

- **Symptom:** the backlog showed `-` for every estimate and the sprint total stayed at 0, although values were saved in the work items.
- **Cause:** the site has two fields, `Story point estimate` (`customfield_10016`, all work types) and `Story Points` (`customfield_10039`, only Epic and Story). The board estimates with `Story Points`, but the project had no Story work type, so the field was unavailable on Lab and Task.
- **Fix:** add a context for `Story Points` limited to project `LNX` and its work types, add the field to the project screen, and remove `Story point estimate` from that screen to avoid confusion.
- **Rule:** for a field to work on a work type it needs both a **context** that includes the work type and a place on the **screen**.

### Screen hierarchy

`Issue Type Screen Scheme` maps work types to a `Screen Scheme`, which maps operations (create, edit, view) to a `Screen`, which holds the fields. Epics use their own screen.

### Deleting work items on the Free plan

- **Symptom:** "You need permission from an admin first" when deleting a work item.
- **Cause:** the permission scheme grants *Delete Issues* to the project role Administrators, and on the Free plan project roles cannot be managed.
- **Approach:** do not delete. Close unwanted items with a `Cancelled` status and a *Won't Do* resolution (planned for W01). This also keeps the audit trail, which is common practice in production Jira sites.
- **Rule:** the permission scheme says which role gets a permission; the project says who is in each role.

### Making blockers visible

An *is blocked by* link records a dependency but does not show on the board card. Combine it with a **flag** on the blocked item, and a board quick filter:

```
issueLinkType = "is blocked by" AND statusCategory != Done
```

### Bulk changes

Bulk edits and moves (for example changing several items from Task to Lab) are done from the work item search with JQL, not from the backlog.
