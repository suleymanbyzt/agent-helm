# Integration Brief: <slug>

**Audience:** <mobile / frontend / service X team>
**Date:** YYYY-MM-DD
**Status:** <deployed to dev / staging / prod — where can they test against it>

## What changed and why

<Two or three sentences. What capability changed, what it enables.>

## Contract

| | Before | After |
|---|--------|-------|
| Endpoint / event | | |
| Method | | |
| New fields | — | |
| Changed fields | | |
| Removed fields | | — |

<Exact names and types. Mark nullable fields.>

## Example

Request:

```
<a real, copy-paste-ready request — verified against the actual implementation>
```

Response:

```
<the actual response>
```

## Errors and edge cases

- `<status/code>` — <when it happens, what the body looks like>
- <nullable / empty / limit cases the integrator must handle>

## Migration notes

<Is the old shape still accepted? Until when? What breaks if they do nothing?>

## Open questions

<Decisions the integrating team must make — or "None".>
