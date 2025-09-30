#!/bin/sh
set -e

# Runtime UID/GID configuration
PUID=${PUID:-1000}
PGID=${PGID:-1000}

# Update nginx-user UID/GID if different from default
if [ "$PUID" != "1000" ] || [ "$PGID" != "1000" ]; then
    echo "=== Updating UID:GID to $PUID:$PGID ==="
    [ "$PGID" != "1000" ] && groupmod -g "$PGID" nginx-user
    [ "$PUID" != "1000" ] && usermod -u "$PUID" nginx-user
    
    # Fix ownership of nginx directories
    chown -R nginx-user:nginx-user \
        /var/www/CertEnroll \
        /var/cache/nginx \
        /var/log/nginx \
        /var/lib/nginx \
        /run/nginx
fi

echo "=== Certificate Server Startup ==="
echo "Running as UID:GID = $PUID:$PGID"

# Validate required environment variables
if [ -z "$USER_WEBDAV" ] || [ -z "$PASS_WEBDAV" ]; then
    echo "ERROR: USER_WEBDAV and PASS_WEBDAV environment variables must be set!"
    exit 1
fi

# Generate htpasswd file
echo "Creating credentials for user: $USER_WEBDAV"
HASH=$(echo "$PASS_WEBDAV" | openssl passwd -apr1 -stdin)
echo "$USER_WEBDAV:$HASH" > /var/lib/nginx/htpasswd
chmod 644 /var/lib/nginx/htpasswd
chown nginx-user:nginx-user /var/lib/nginx/htpasswd
echo "✅ htpasswd created"

# Ensure directories exist with correct permissions
mkdir -p /var/www/CertEnroll /var/lib/nginx/logs
chmod 755 /var/www/CertEnroll /var/lib/nginx/logs
chown nginx-user:nginx-user /var/www/CertEnroll

# Create error log file for nginx startup check
touch /var/lib/nginx/logs/error.log
chown nginx-user:nginx-user /var/lib/nginx/logs/error.log
chmod 644 /var/lib/nginx/logs/error.log

# Test nginx configuration
nginx -t || exit 1

echo "✅ Starting nginx..."
exec nginx -g "daemon off;"
