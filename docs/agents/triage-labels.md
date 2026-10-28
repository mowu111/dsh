# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

This repo keeps the default vocabulary: each label string equals its role name.

## Wayfinder labels

`/wayfinder` uses a second, separate vocabulary. These are labels too, and are also created in the tracker:

| Label                 | Applies to                                        |
| --------------------- | ------------------------------------------------- |
| `wayfinder:map`       | The map issue (one per effort)                    |
| `wayfinder:research`  | A child ticket: go find out something             |
| `wayfinder:prototype` | A child ticket: build a throwaway to answer a question |
| `wayfinder:grilling`  | A child ticket: stress-test a decision with the user |
| `wayfinder:task`      | A child ticket: concrete, known implementation work |

Wayfinder labels are not triage labels. Do not force a wayfinder ticket to also carry a triage label unless the skill's own flow asks for it.

Edit the right-hand column of either table to match whatever vocabulary you actually use.
