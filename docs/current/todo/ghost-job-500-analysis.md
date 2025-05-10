# Zombie-Job / Smart-Delete Incident – Root-Cause & Options

> File created per request to capture investigation details (May 2025)

## Context
* User swiped to delete job `05856d22-965c-497f-a822-6e2e80e4759e` in `JobListPlayground` (Smart-Delete path).
* `JobDeleterService.attemptSmartDelete()` invoked:
  * Job **has** `serverId` → triggers server-existence check.
  * GET `/jobs/{serverId}` returned **HTTP 500**.
* Spec logic (Cycle 0 sequence diagram) maps any **non-404** or network error to **mark job `pendingDeletion`**.
* Hive write emits through `watchJobs()` → Job re-appears in list with trash-can icon (the "ghost").

## Findings
1. **Backend returns 500, not 404** – This prevents immediate purge; we can't be sure job is gone.
2. Front-end logic works as coded/expected: falls back to `pendingDeletion` on error.
3. Logout-race fix (Cycle 4) unrelated; issue occurs pre-logout.
4. UI currently shows `pendingDeletion` jobs; hence the user sees the ghost.

## Options
| # | Approach | Pros | Cons |
|---|----------|------|------|
| A | **Backend Fix** – API returns 404 when job truly missing | Canonical; preserves data integrity | Requires backend work |
| B | **UI Filter** – Hide `SyncStatus.pendingDeletion` (and/or `JobStatus.pendingDeletion`) from list | Immediate UX win; keeps conservative data strategy | User loses visibility of queued deletions |
| C | **Client YOLO Purge** – Treat 5xx/timeouts as "gone" and delete locally | Ghost gone w/o backend help | Risky: may delete valid server data; violates conservative spec |

## Recommendation (Hard Bob)
* Push for **Option A** – correct status codes from backend.
* Implement **Option B** as interim UX polish (easy patch in `JobListCubit._handleJobEvent`).
* Avoid Option C unless product explicitly accepts potential data loss.

## Next Steps
1. File backend ticket: "`GET /jobs/{id}` returns 500 when record missing – should be 404".
2. If green-lit, patch UI filter in `JobListCubit` *(1-liner, unit test update)*.
3. Retest Smart-Delete flow once backend fixed.

---
Created by Hard Bob assistant. 💥 