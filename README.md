# 📦 Easy & Automated Backup Script!

This script automates backups of essential files and SQL databases with configurable intervals and Telegram based storage.

---

## 🚀 Quick Start

Installation:

```bash
curl -sL https://raw.githubusercontent.com/MsHerni/backup-manager/main/install.sh -o install.sh; sudo bash install.sh
```

Uninstallation:

```bash
curl -sL https://raw.githubusercontent.com/MsHerni/backup-manager/main/uninstall.sh -o uninstall.sh; sudo bash uninstall.sh
```

## 📝 Features

- **Flexible Backup Scheduling**: Set backup interval in hours, down to a precision of 5 seconds, up to 1 year interval.
- **Selective Directory Backup**: Choose specific directories to back up and exclude certain folders within them.
- **SQL Database Backup**: Select specific databases to back up or exclude, with support for all databases by default.
- **Webserver Configurations Backup**: Optionally include Apache or NGINX configuration files in your backup.
- **Telegram Storing**: Receive backups as compressed files via Telegram.
- **Auto-start Service**: Creates a Systemd service for auto-starting and background operation.

---
## ⚙️ Configuration File

The configuration file is generated during installation. This file has multiple sections for customizing backups.

Example of conf.ini:
```ini
[settings]
; General settings for backup configuration

; Interval in hours between backups
; You can choose a float value for smaller intervals (e.g., 0.5 for 30 minutes)
; Default value is 24 (Hours)
BACKUP_INTERVAL_HOURS = 24


[destination]
; Define the destination of the backup files.
; Supported destination type(s): TELEGRAM

; TELEGRAM Section
; TOKEN and CHAT_ID are required; TOPIC_ID is optional.
; --------------------
TYPE = TELEGRAM
TOKEN = your_telegram_bot_token
CHAT_ID = your_chat_id
TOPIC_ID = your_topic_id  # optional


[backup]
; Define the backup main options.

; FILES_BACKUP: Set to true to enable, false to disable
FILES_BACKUP = true

; BASE_DIRS: List of directories to back up, separated by commas
BASE_DIRS = /var/www, /home/user/documents

; EXCEPTION_DIRS: Directories within BASE_DIRS to exclude, separated by commas
EXCEPTION_DIRS = */vendor

; SQL_BACKUP: Set to true to enable, false to disable
; Supported structures: MySQL, MariaDB
SQL_BACKUP = true

; SQL_BASE_DBS: Databases to back up, default "". Exclusions should be defined in SQL_EXP_DBS
; Use "" for all databases or list specific databases separated by commas.
SQL_BASE_DBS = database1, database2

; SQL_EXP_DBS: Databases to exclude from backup, separated by commas
; These databases are excluded by default: information_schema, performance_schema, mysql, sys, test
SQL_EXP_DBS = excluded_db1, excluded_db2

; WEBSERVER_BACKUP: Set to true to enable, false to disable
; Supported servers: Apache, nginx
WEBSERVER_BACKUP = true
```

## 📋 To-Do List

- Additional backup destinations (e.g., Another Server)
