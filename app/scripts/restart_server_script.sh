#!/bin/bash
set -e

echo "=== Restarting web server for GREEN deployment ==="

# Install httpd if missing
if ! command -v httpd >/dev/null 2>&1; then
    echo "httpd not found. Installing..."
    yum install -y httpd
fi

# Start and enable httpd
systemctl enable httpd
systemctl restart httpd

# Verify
STATUS=$(systemctl is-active httpd)

if [ "$STATUS" != "active" ]; then
    echo "ERROR: httpd failed to start"
    systemctl status httpd
    exit 1
fi

echo "httpd is running successfully"
