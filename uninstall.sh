#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run the installer as root or use sudo."
    exit 1
fi

systemctl stop backup.service > /dev/null 2>&1
systemctl disable backup.service > /dev/null 2>&1

rm /etc/systemd/system/backup.service > /dev/null 2>&1
rm -rf /etc/backup > /dev/null 2>&1

systemctl daemon-reload
rm "$0"
