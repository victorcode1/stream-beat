# Radio Browser backup

This private branch keeps a recoverable backup of the public Radio Browser GitLab projects.

## What is committed

- `radio-bundles/*.bundle`: Git bundle files with branches, tags, and history.
- `radio-bundles/manifest.tsv`: repo name, original GitLab URL, and bundle name.
- `scripts/update_radio_backups.sh`: updates local clones and regenerates bundles.
- `scripts/restore_radio_bundle.sh`: restores repos from bundles.

## What is not committed

- `radio/`: local working clones used only for updates.
- `radio-restored/`: optional restore output.

## Update backups

Run this from the private backup worktree:

```bash
cd /Users/victorflores/flow-music-private-backup
./scripts/update_radio_backups.sh
```

Then commit and push only to the private repository:

```bash
git add .gitignore docs/RADIO_BROWSER_BACKUP.md scripts/update_radio_backups.sh scripts/restore_radio_bundle.sh radio-bundles/
git commit -m "Update Radio Browser backup bundles"
git push origin private/full-backup
```

If SSH to GitHub times out:

```bash
gh auth setup-git -h github.com
git push https://github.com/victorcode1/stream-beat.git private/full-backup
```

Never push these private backup changes to `organization`.

## Restore all repos

Use this when the original GitLab repos still exist, or when they were deleted and you need to recover from the private backup.

```bash
cd /Users/victorflores/flow-music-private-backup
./scripts/restore_radio_bundle.sh
```

Restored repos are created in:

```text
radio-restored/
```

Each restored repo gets its original GitLab URL as `origin`, so if GitLab is still available you can fetch updates later.

If GitLab deleted the original repositories, the restore still works because the code comes from the local `.bundle` files. In that case, `git fetch origin` will fail later because the original remote no longer exists, but the restored local repos are still usable.

## Restore one repo

```bash
./scripts/restore_radio_bundle.sh radio-database
```

Examples:

```bash
./scripts/restore_radio_bundle.sh radiobrowser-api-rust
./scripts/restore_radio_bundle.sh api-radio-browser-info
./scripts/restore_radio_bundle.sh radiobrowser-web-angular
```

## Manual restore

```bash
git clone radio-bundles/radio-database.bundle radio-database
cd radio-database
git remote remove origin
git remote add origin https://gitlab.com/radiobrowser/radio-database.git
```

If GitLab is gone, skip the `git remote add origin ...` step or replace it with a new remote that you control.

Manual restore for the key projects:

```bash
git clone radio-bundles/radiobrowser-api-rust.bundle radiobrowser-api-rust
git clone radio-bundles/api-radio-browser-info.bundle api-radio-browser-info
git clone radio-bundles/radiobrowser-web-angular.bundle radiobrowser-web-angular
```

## Restore on a new computer if GitLab is gone

First clone the private Flow Music backup:

```bash
git clone git@github.com:victorcode1/stream-beat.git
cd stream-beat
git checkout private/full-backup
```

Then restore Radio Browser repos from the committed bundles:

```bash
./scripts/restore_radio_bundle.sh
```

The restored projects will be available under:

```text
radio-restored/
```

For example:

```text
radio-restored/radio-database
radio-restored/radiobrowser-api-rust
radio-restored/api-radio-browser-info
radio-restored/radiobrowser-web-angular
```

To restore only the three most important projects:

```bash
./scripts/restore_radio_bundle.sh radiobrowser-api-rust
./scripts/restore_radio_bundle.sh api-radio-browser-info
./scripts/restore_radio_bundle.sh radiobrowser-web-angular
```

## Why bundles

Bundles are committed as normal files in this private repo. They preserve Git history without embedding nested `.git` directories or relying on Git submodules.
