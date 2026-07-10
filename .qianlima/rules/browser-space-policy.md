# Browser Space Policy

Version: v2.6.8
Updated: 2026-07-10
Source inspiration: citrolabs/ego-lite Space, Snapshot, ego-browser, and Skills docs.

## Purpose

Qianlima should treat browser automation as a controlled task space, not as a loose sequence of clicks.
This rule applies to Kimi WebBridge, Chrome DevTools, ego-lite style browsers, desktop agents, and any future tool that can read or operate a logged-in browser.

## Design Lessons

1. Task space first.
   Each browser task must declare a short task-space name, target site, user goal, allowed actions, forbidden actions, and owner takeover path before acting.

2. Snapshot before action.
   Prefer semantic snapshots or accessibility-style summaries over raw DOM, screenshots, or copied HTML. Raw HTML is high-token, noisy, and should only be used when the snapshot is insufficient.

3. Re-snapshot after state change.
   Any navigation, filter change, form fill, modal, export, upload, submit, or dynamic page refresh invalidates previous element references. The agent must re-read the current state before the next meaningful action.

4. Real login, real risk.
   If the browser session is logged in, even a click can become a business action. Publishing, sending, deleting, buying, exporting private data, changing price, changing bid, changing budget, account setting changes, and permission changes require confirmation gates from risk-rules.yaml.

5. User takeover is a feature.
   A task space must stay understandable enough that the user can inspect, stop, or take over. The trace must include current page, key actions, pending action, and confirmation status.

6. Experience becomes reusable workflow.
   Successful repeated browser paths should be distilled into site skills, workflow steps, or playbooks. The goal is fewer retries, fewer tokens, and lower cost on the next run.

## Required Trace Fields

Every non-trivial browser task should record:

- browser_tool
- task_space_name
- target_site
- logged_in_state: unknown | not_logged_in | logged_in
- pages_visited
- snapshot_count
- screenshot_count
- actions_taken
- downloads_created
- forms_filled
- submit_or_write_actions
- confirmations_required
- confirmations_received
- takeover_available
- current_page_or_tab
- pending_action
- cost_card

## Cost Principle

Browser automation is expensive when it loops blindly. The default savings order is:

1. Reuse task space and logged-in state when safe.
2. Use semantic snapshot before screenshot or raw DOM.
3. Batch navigation, extraction, filtering, and output into one planned browser pass when possible.
4. Convert repeated successful paths into reusable workflow steps.
5. Stop and ask when the next step is high-risk or low-confidence.

## Verification Gates

- task_space_declared: The task has a named space or equivalent run boundary.
- boundaries_declared: Allowed and forbidden actions are explicit.
- snapshot_before_action: A semantic snapshot or equivalent state read happened before actions.
- resnapshot_after_change: The state was refreshed after navigation, modal, submit, filter, or dynamic rerender.
- no_unconfirmed_write: No write, send, publish, delete, bid, budget, price, order, or permission change happened without confirmation.
- trace_resume_ready: Another agent or the user can understand the current page, pending action, and next safe step from the trace.
- cost_card_visible: The output includes cost and savings status for non-trivial runs.

## Private Data Boundary

Do not commit browser screenshots, exports, cookies, tokens, session IDs, private dashboard URLs, raw customer/order rows, or local download paths to the public repository.
Only commit generic rules, templates, and example schemas.
