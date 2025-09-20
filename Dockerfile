FROM alpine:latest

# Install nginx and WebDAV module from same Alpine repos
RUN apk update && \
    apk add --no-cache \
        nginx \
        nginx-mod-http-dav-ext \
        su-exec \
        openssl

# Create nginx user and webdav directory
RUN addgroup -g 1000 nginx-user && \
    adduser -D -u 1000 -G nginx-user nginx-user

# Create necessary directories with correct permissions
RUN mkdir -p /var/www/certs \
             /var/cache/nginx \
             /var/log/nginx \
             /var/lib/nginx \
             /run/nginx && \
    chown -R 1000:1000 /var/www/certs \
                       /var/cache/nginx \
                       /var/log/nginx \
                       /var/lib/nginx \
                       /run/nginx

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf

# Create entrypoint script that generates htpasswd from environment variables
RUN cat > /entrypoint.sh << 'EOF'
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
mkdir -p /var/www/certs
chmod 755 /var/www/certs

# Test nginx config
nginx -t || exit 1

echo "✅ Starting nginx..."

# Start nginx
exec nginx -g "daemon off;"
EOF

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 8080

CMD ["/entrypoint.sh"]