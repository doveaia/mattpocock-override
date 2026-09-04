---
name: triage
description: Run Matt Pocock's triage skill, extended so every issue or PR it touches is filed onto a GitHub Projects board and every state role is mirrored to a Status column.
disable-model-invocation: true
---

# Triage (board-backed)

This skill is a **thin layer over the upstream `mattpocock-skills:triage` skill**. It owns no copy of the triage state machine, the agent-brief guidance, or the out-of-scope rules: those stay upstream and arrive with upstream's updates.

What it adds: triage never leaves an item off the board, and every state change is mirrored to a GitHub Projects (v2) Status column.

## How to run this skill

Follow these three phases in order. Phase 2 is the whole upstream skill; phases 1 and 3 are this layer.

### Phase 1: pre-flight (before delegating)

1. **Read the board config**, `docs/agents/github-project.md`.

   If it is missing, this is the first run: do the setup in [PROJECT-BOARD.md](PROJECT-BOARD.md) (§ First run) now, before any triage work. It resolves the project, field, and option IDs by `gh` call and writes them down. Never guess an ID.

2. **Check the `project` OAuth scope** (`gh auth status`). If it is absent, tell the maintainer to run `gh auth refresh -s project --hostname github.com`, and ask whether to continue label-only. A missing scope is never a reason to skip the triage itself.

### Phase 2: delegate to upstream

Call the Skill tool with the skill name **`mattpocock-skills:triage`**, and run the maintainer's request through it as written.

Use that fully qualified name. Never invoke a bare `triage`, and never `mattpocock-skills-override:triage`: both can resolve back to *this* skill and loop.

If the tool reports that no such skill exists, the upstream plugin isn't installed. Stop and tell the maintainer:

```
/plugin install mattpocock-skills
```

This layer has nothing to run without it.

### Phase 3: board rules (in force for the whole session)

Upstream's instructions govern the triage. These rules sit on top of them and stay in force from the moment this skill is invoked until the session ends. Where the two touch, these win.

**Every state role change is also a board move.** Upstream applies a state role by writing a label. Here, that action has a second half: ensure the item has a card on the project, then set its Status to the column mapped from that role ([PROJECT-BOARD.md](PROJECT-BOARD.md) § Status mapping, § Recipes). Labels first, board second. Report the card alongside the label change.

**Issues that triage creates are born on the board.** Add `--project "<project title>"` to any `gh issue create`, then set the Status the same way.

**Labels are the source of truth; the board is a projection.** When a card's Status disagrees with its labels, someone moved the card by hand. Report it and ask which side the maintainer means. Do not silently reconcile either way.

**A board failure never rolls back label work.** If a board call fails, say which step failed, leave the labels applied, and offer to retry the board write.

**Read the board where it answers better than a label query.** When the maintainer asks what needs attention, add a short fourth bucket after upstream's three: **drift**, meaning items whose labels and Status disagree, plus triaged items with no card. Offer to reconcile them in one approved pass. When they ask about the board directly ("what's on the board?", "what's in Ready for Agent?"), answer grouped by Status column.

**Board language means the same thing as label language.** "Move #42 to the Ready for Agent column" is upstream's "move #42 to ready-for-agent": it changes the labels too, not just the card.

**Only what triage touches gets filed.** No bulk import of a backlog unless the maintainer asks for it in so many words.

## Reference

- [PROJECT-BOARD.md](PROJECT-BOARD.md): board config file, `gh` recipes, Status mapping, failure modes
- Everything else (roles, states, agent briefs, `.out-of-scope/`) lives in the upstream skill.
