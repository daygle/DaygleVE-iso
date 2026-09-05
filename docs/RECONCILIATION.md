# Reconciliation and drift repair

Reconciliation is deliberately two-phase:

1. **Dry run** (`POST /api/v1/operations/reconcile` with `{"mode":"dry_run"}`)
   inventories live KVM, LXC, network, storage, share, and GPU state against
   DaygleVE's durable records. It does not mutate the host or adopt resources;
   unmanaged findings are persisted as pending quarantine records for review.
2. **Review** the completed operation's `findings` and the quarantine list at
   `GET /api/v1/operations/quarantine`.
3. **Repair** only after review by submitting `{"mode":"repair",
   "approval_id":"<successful-dry-run-id>","quarantine_unmanaged":true}`.
   The repair operation uses the exact findings from that dry run, recreates only
   supported non-destructive definitions, and records unmanaged host resources
   as pending quarantine items.
4. **Decide explicitly** for each quarantine record with
   `PATCH /api/v1/operations/quarantine/<id>` and either
   `{"decision":"adopt"}` or `{"decision":"release"}`. Decisions include the
   authenticated user and timestamp in the durable record. Adoption is currently
   supported for bridges; VM, container, storage, and device imports remain
   intentionally manual until their metadata can be reconstructed safely.

The backend also performs a read-only dry run during startup. Interrupted jobs
are marked `needs_review` after restart instead of being assumed successful.

## Safety rules

- A repair without a successful dry-run approval is rejected.
- Repairs never delete newer host state, destroy unmanaged resources, or adopt
  resources implicitly.
- Missing VM definitions and missing bridges/VLAN registrations are eligible for
  non-destructive repair. Missing LXC definitions and storage/device state are
  reported for manual restore/import because recreating them without their
  original metadata could destroy or overwrite data.
- Repeat scans do not create duplicate pending quarantine records.
- Review and decision endpoints require the operations RBAC permissions.

## Real-host validation

Run `scripts/validate-host.sh` on a disposable installed Linux appliance. The
manual self-hosted workflow `.github/workflows/validate-host.yml` runs the same
checks when a runner is registered with the `daygleve-validation` label. Set
`DAYGLEVE_API_URL` and `DAYGLEVE_API_TOKEN` to additionally verify that the
broker posture endpoint reports `current_execution=broker`.

After the boundary checks pass, run a dry run, inspect findings, perform a repair
with the dry-run ID, and verify the operation and quarantine records survive a
backend restart. Exercise only disposable VM/container/network/storage objects.
