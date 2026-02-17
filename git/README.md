# Git backups scripts

A collection of scripts to backup stuff to git repositories. The scripts are designed to automate the backup process and ensure that important data is safely stored.

All scripts have a `--help` flag that will print usage information.

## Backup Arcane
Cron example usage:
```crontab
@hourly /path/to/repo/backup-scripts/git/backup-arcane.sh --path /data/compose/arcane/data/projects --user "Eric Falsett" --email eric.falsett@gmail.com --push
```