#!/bin/bash
# Restart Apache for GREEN deployment

set -e

echo "=== Restarting web server for GREEN deployment ==="

# Ensure httpd is installed
if ! command -v httpd >/dev/null 2>&1; then
    echo "ERROR: httpd is not installed"
    exit 1
fi

# Restart httpd cleanly
echo "Restarting httpd..."
systemctl restart httpd

# Enable it (in case it wasn't)
systemctl enable httpd

# Verify it is running
STATUS=$(systemctl is-active httpd)

if [ "$STATUS" != "active" ]; then
    echo "ERROR: httpd failed to start"
    systemctl status httpd
    exit 1
fi

echo "httpd is running successfully"
