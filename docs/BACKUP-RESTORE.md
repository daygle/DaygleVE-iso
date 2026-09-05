# DaygleVE backup and restore

## Scope

The backend stores backups as ZFS send streams below `DAYGLEVE_BACKUP_DIR`
(default `/var/lib/daygleve/backups`). A plan can capture a ZFS dataset, a VM's
backing datasets, or an LXC root filesystem. Each run:

1. Creates a temporary `daygleve-backup-*` ZFS snapshot.
2. Writes one stream per source dataset to the plan's relative destination.
3. Computes SHA-256 for every stream and optionally verifies it immediately.
4. Persists the artifact manifest under `/var/lib/daygleve/backup_artifacts`.
5. Applies retention to the newest successful artifacts.
6. Removes the temporary source snapshots.

The API exposes plan creation and scheduling under `/api/v1/backups`. Scheduled
plans are checked every 30 seconds; the minimum interval is 60 seconds. Jobs are
recorded in the normal Operations journal and can be polled from the Operations
page.

## Storage policy

Use a dedicated ZFS dataset or a separate mounted filesystem for the backup
root. Do not place the only copy of a backup on the same pool as the guest data:
a pool failure, host loss, or accidental destruction can otherwise remove both
source and backup. The current implementation is local-only; off-node ZFS
replication, object storage, encryption-at-rest, and key management are required
for production disaster recovery.

Plan destinations are relative to the configured backup root. The backend rejects
absolute paths, traversal components, backslashes, and shell metacharacters.
CIFS/NFS shares are not accepted as backup destinations by the API.

## Restore procedure

1. Confirm the artifact is marked **Verified** in the Backups page.
2. Confirm the target dataset and the expected impact with the owner.
3. Stop any guest using the target dataset.
4. Choose **Restore**, enter the target dataset, and explicitly confirm replacement
   only when the target is disposable or has its own current backup.
5. Poll the operation until it is `succeeded`; inspect the operation error if it
   fails. The backend verifies the stored SHA-256 before starting `zfs receive`.
6. Reconcile the host and start the guest only after validating its configuration.

A restore never replaces an existing dataset unless `force: true` is supplied.
Forced restore destroys the target recursively before receiving the stream and is
therefore destructive. The current baseline supports one-dataset artifacts; VM
and multi-disk restore orchestration will be expanded with guest stop/start and
configuration validation before being considered production-ready.

## Recovery after a host failure

Reinstall or boot a replacement DaygleVE host, configure ZFS and libvirt/LXC,
mount the backup storage at the configured backup root, and restore datasets with
the Backups API. Recreate or import guest definitions as needed, then run host
reconciliation. Keep a copy of the backend state directory because it contains
plan and artifact manifests, but treat those manifests as metadata: the ZFS
streams are the recoverable data.

After an interrupted backup or restore, do not retry blindly. Check the ZFS pool,
source/target datasets, stream files, and Operations journal. Jobs left active at
backend shutdown are marked `needs_review`; verify host state before cleanup or
retry. Never delete a source snapshot or stream until its artifact has been
verified and an independent copy exists.

## Testing requirements

Before production use, test a complete cycle on disposable guests: scheduled
backup, checksum failure, retention pruning, restore to a new dataset, forced
replacement, pool-full failure, interrupted transfer, and host reboot during a
job. Add off-node replication and periodically perform a documented bare-metal
restore drill.
