# Collaboration: Notion, GitHub issues, diagrams

## Notion and issues

Yes. Use Notion as the board people look at every day, and GitHub issues as
the per-module discussion thread. They link by module id (`B1`, `C2`, …).

Recommended shape:

```
modules.yaml  ──import──►  Notion database "NiB modules"
                                  │
                                  │ relation / URL
                                  ▼
                            GitHub issues (one per module)
```

### Notion database

1. In Notion: **Import → CSV** → [`modules.csv`](modules.csv).
2. After import, add properties if missing:
   - `Owner` (Person)
   - `Reviewer` (Person)
   - `GitHub issue` (URL)
   - `Status` (Select: exists / design / planned / claimed / done)
   - `Role` (Select: interface / implementation / platform)
3. Views worth creating:
   - Board grouped by `Workstream`
   - Board grouped by `Owner`
   - Table filtered `Role = interface` (the two contract jobs B1 and C1)
   - Table filtered `Role = implementation` (datasets and models)

Interface rows are the scarce ones: B1 and C1 should each have a single
owner. Implementation rows (SEVIR, radar, WADEPre, …) can each have a
different owner. That is the split.

### GitHub issues

`.github/ISSUE_TEMPLATE/claim-module.md` already exists. Create one issue
per module, title `[B1] Data adapter interface`, paste the YAML `do` /
`done_when` into the body, put the issue URL back into Notion and into
`modules.yaml` `github_issue`.

### How they stay in sync

Notion's official GitHub connection:

- Paste a repo issues URL into Notion → **Paste as database** (synced
  database). That board is **one-way from GitHub**. Edit status on GitHub;
  Notion follows.
- Put a **GitHub issue URL** property on *your* Modules database and relate
  it to the synced issues database.

Two-way (edit owner in Notion, see it on the issue) needs Zapier / Make /
Unito, or a small script. For a review-and-claim round, URL + module id is
enough. Do not maintain owners in three places by hand — pick one:

| Surface | What it owns |
| --- | --- |
| `modules.yaml` | Canonical id, role, do, done_when (in git) |
| Notion | Who is doing it this week (people, board) |
| GitHub issue | Comments, review, PR links |

After a claim meeting, copy Owner from Notion back into `modules.yaml` in
one PR.

### Without GitHub

Notion still works. Import the CSV, assign Person, and comment on the
Notion row. Attach the edited `.drawio` file to the page.
