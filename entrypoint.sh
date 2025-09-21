# Create entrypoint script that generates htpasswd from environment variables
#!/bin/sh
set -e

echo "=== Certificate Server Startup ==="
echo "Creating credentials for user: $CERT_USER"

# Generate htpasswd entry from environment variables
if [ -z "$CERT_USER" ] || [ -z "$CERT_PASS" ]; then
    echo "ERROR: CERT_USER and CERT_PASS environment variables must be set!"
    exit 1
fi

# Create htpasswd file with hash
HASH=$(echo "$CERT_PASS" | openssl passwd -apr1 -stdin)
echo "$CERT_USER:$HASH" > /var/lib/nginx/htpasswd

# Set permissions
chmod 644 /var/lib/nginx/htpasswd

echo "✅ htpasswd created for user: $CERT_USER"

# Create cert directory
mkdir -p /var/www/certsrv
chmod 755 /var/www/certsrv

# Test nginx config
nginx -t || exit 1

echo "✅ Starting nginx..."

# Start nginx
exec nginx -g "daemon off;"
