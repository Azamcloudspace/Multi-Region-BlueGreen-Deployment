#!/bin/bash
# scripts/backup_blue.sh
# Backup the current BLUE deployment before installing GREEN

echo "=== Backing up BLUE deployment ==="

BACKUP_DIR="/var/www/html/backup"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Backup current index.html (BLUE version)
if [ -f /var/www/html/index.html ]; then
    echo "Backing up current BLUE deployment..."
    cp /var/www/html/index.html $BACKUP_DIR/index.html.blue.$TIMESTAMP
    echo "Backup saved to: $BACKUP_DIR/index.html.blue.$TIMESTAMP"
else
    echo "No existing index.html found (first deployment from user data)"
fi

echo "Backup complete"