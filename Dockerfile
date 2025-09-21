FROM alpine:latest

# Install nginx and WebDAV module from same Alpine repos
RUN apk update && \
    apk add --no-cache \
        nginx \
        nginx-mod-http-dav-ext \
        su-exec \
        openssl

# Create nginx user and group with specific UID and GID
RUN addgroup -g 1000 nginx-user && \
    adduser -D -u 1000 -G nginx-user nginx-user

USER nginx-user

# Create necessary directories with correct permissions
RUN mkdir -p /var/www/certsrv \
             /var/cache/nginx \
             /var/log/nginx \
             /var/lib/nginx \
             /run/nginx

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf

COPY entrypoint.sh /

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 8080

CMD ["/entrypoint.sh"]
