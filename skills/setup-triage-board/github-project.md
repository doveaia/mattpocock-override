## Rules

These rules bind every skill that changes a triage state label: `triage` first, but also `to-tickets` and anything else that files or moves an issue. They sit alongside the tracker conventions in `issue-tracker.md`.

**Every state label change is also a board move.** After applying, removing, or changing a triage state label on an issue or PR, call the Skill tool with `mattpocock-skills-override:sync-triage-board`, naming the item and the label now on it. It puts the card in the mapped column. Labels first, board second; mention the card when reporting the label change.

**Issues created during triage are born on the board.** Add `--project "<project title>"` to `gh issue create`, then call the same skill to set the column.

**Labels are the source of truth; the board is a projection.** When a card's Status disagrees with the item's labels, someone moved the card by hand or relabelled outside triage. Report it and ask which side is meant. Never silently reconcile in either direction.

**A board failure never rolls back label work.** If the board step fails, leave the labels as applied, say which step failed, and offer a retry. A missing `project` OAuth scope (`gh auth refresh -s project --hostname github.com`) is the usual cause, and never a reason to skip the triage itself.

**"Show what needs attention" gains a fourth bucket: drift.** After the usual three (unlabeled, `needs-triage`, `needs-info` with reporter activity), ask `sync-triage-board` for the items whose labels and Status disagree, plus labelled items with no card. Present them; reconciliation waits for approval and is never started unprompted.

**Board language means the same thing as label language.** "Move #42 to the Ready for Agent column" is "move #42 to `ready-for-agent`": change the labels too, not just the card.

**Category labels (`bug` / `enhancement`) stay labels.** Only state roles map to columns.

## Maintenance

How the moves are made (the `gh` recipes, the drift and backfill procedure, the failure modes) lives in the `sync-triage-board` skill, so it updates with the plugin. This file only has to stay true about the board's identity and the column mapping above. If a column is deleted and recreated its option ID changes and every board write fails: re-run `/mattpocock-skills-override:setup-triage-board` to resolve the IDs again.
