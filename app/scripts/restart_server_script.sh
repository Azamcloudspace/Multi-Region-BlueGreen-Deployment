#!/bin/bash
# scripts/restart_server.sh
# Restart web server to serve the new GREEN deployment

echo "=== Restarting web server for GREEN deployment ==="

# Determine which web server is running and restart it
if systemctl is-active --quiet httpd; then
    echo "Restarting Apache (httpd)..."
    systemctl restart httpd
    systemctl enable httpd
    echo "Apache restarted"
    
elif systemctl is-active --quiet apache2; then
    echo "Restarting Apache2..."
    systemctl restart apache2
    systemctl enable apache2
    echo "Apache2 restarted"
    
elif systemctl is-active --quiet nginx; then
    echo "Restarting Nginx..."
    systemctl restart nginx
    systemctl enable nginx
    echo "Nginx restarted"
    
else
    # No server running, try to start one
    echo "No running web server found. Attempting to start..."
    
    if command -v httpd &> /dev/null; then
        systemctl start httpd
        systemctl enable httpd
        echo "Apache (httpd) started"
        
    elif command -v apache2 &> /dev/null; then
        systemctl start apache2
        systemctl enable apache2
        echo "Apache2 started"
        
    elif command -v nginx &> /dev/null; then
        systemctl start nginx
        systemctl enable nginx
        echo "Nginx started"
    else
        echo "ERROR: No web server found!"
        exit 1
    fi
fi

echo "Web server restart complete"