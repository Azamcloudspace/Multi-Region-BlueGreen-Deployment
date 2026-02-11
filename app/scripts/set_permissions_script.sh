#!/bin/bash
# scripts/set_permissions.sh
# Set correct permissions for the new GREEN deployment

echo "=== Setting permissions for GREEN deployment ==="

# Set ownership
chown -R root:root /var/www/html/index.html

# Set file permissions
chmod 644 /var/www/html/index.html

# Ensure backup directory is accessible
if [ -d /var/www/html/backup ]; then
    chmod 755 /var/www/html/backup
fi

echo "Permissions set successfully"