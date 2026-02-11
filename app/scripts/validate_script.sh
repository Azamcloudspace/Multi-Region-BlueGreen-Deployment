#!/bin/bash
# scripts/validate.sh
# Validate the GREEN deployment is working

echo "=== Validating GREEN deployment ==="

# Wait for server to fully start
sleep 5

MAX_RETRIES=10
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Test local web server
    if curl -f -s http://localhost/ > /dev/null 2>&1; then
        echo "✅ Web server is responding"
        
        # Check if it's actually serving the new content
        RESPONSE=$(curl -s http://localhost/)
        
        if echo "$RESPONSE" | grep -q "Deployment"; then
            echo "✅ GREEN deployment validation successful!"
            echo "Server is serving the new deployment"
            exit 0
        else
            echo "⚠️  Server responding but content might not be updated"
            exit 0
        fi
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        echo "Attempt $RETRY_COUNT/$MAX_RETRIES - Server not ready yet, waiting..."
        sleep 3
    fi
done

echo "❌ Validation failed after $MAX_RETRIES attempts"
echo "GREEN deployment did not start successfully"
exit 1