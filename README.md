# Backup Scripts
This repository contains scripts for backing up various data and configurations. The scripts are designed to automate the backup process and ensure that important data is safely stored.

Some of the scripts backup to a git repositories, while others may use different methods for storage. The scripts are organized in a way that allows for easy maintenance and updates.

## Auto-update this repo
Crontab:
```crontab
@hourly git -C /path/to/repo/backup-scripts pull
```

## [Git Backups](git)
The `git` directory contains scripts specifically for backing up data to git repositories. These scripts can be used to automate the process of committing and pushing changes to a remote repository.