# Journal Entry Formats

One file per finished task, half a page maximum. Location:
`docs/agent-journal/YYYY-MM-DD-<type>-<slug>.md` where `<type>` is
`feature`, `bug`, or `refactor`.

The journal is for the user and for future agent sessions: what happened and
why, without re-reading the diff. Plain language — write it so the project
owner understands it, not just another engineer.

---

## Feature

```markdown
# Feature: <short title>

**What was asked:** <the request, in one or two sentences>

**Plan:** <the approach that was approved, 2-3 sentences>

**What was done:** <files/areas touched, key choices made — bullets, max 5>

**How verified:** <tests written/run, behavior exercised>
```

## Bug

```markdown
# Bug: <short title>

**Problem:** <what was broken, as observed>

**How found:** <the evidence trail — reproduction, logs, source reading>

**Root cause:** <why it happened, one or two sentences>

**Fix:** <what was changed>

**Regression test:** <the test that now guards this>
```

## Refactor

```markdown
# Refactor: <short title>

**Why:** <what problem the old structure caused>

**Safety net:** <which tests existed, which characterization tests were added>

**Steps taken:** <the moves, as bullets, max 5>

**Behavior preserved — proof:** <suite results, diff review outcome>
```
