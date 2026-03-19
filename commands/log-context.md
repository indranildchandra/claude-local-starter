---
description: Write a detailed session snapshot to tasks/tracker.md before compaction or on demand. Preserves enough context for a cold-start in the next session.
---

You are writing a pre-compact context snapshot. Follow these steps exactly.

## Step 1 — Load the format

Read `aidlc-tracking` skill formats.md for the **pre-compact snapshot** entry format before writing anything.

## Step 2 — Gather session context

Reflect on the current conversation and identify:
- **Working on:** What is the current task or goal?
- **Completed this session:** What has been finished since the session started or since the last snapshot?
- **Key decisions:** What significant decisions were made and why?
- **Files changed:** Which files were created, modified, or deleted?
- **Open / in-progress:** What is unfinished or blocked?
- **Resume from:** The exact state a fresh session would need to pick up — specific file, function, step, or error being worked on. Be precise enough that no context is required from the conversation history.

## Step 3 — Write to tasks/tracker.md

Prepend the pre-compact snapshot entry to `tasks/tracker.md` so the newest entry is at the top.

If `tasks/tracker.md` does not exist: create it with the header from aidlc-tracking formats.md, then write the entry below the header.

If `tasks/tracker.md` already exists: insert the new entry immediately after the file header (first 3 lines), pushing all prior entries down. Do NOT append to the end of the file.

## Step 4 — Confirm

Tell the user: "Context logged to tasks/tracker.md — safe to /compact."
Show the **Resume from** line so the user can verify it captures the current state.
