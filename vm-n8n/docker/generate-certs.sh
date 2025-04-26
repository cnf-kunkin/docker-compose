#!/bin/bash

# Create directories if they don't exist
sudo mkdir -p /data/nginx/certs
sudo mkdir -p /data/n8n/{db,files}

# Generate SSL certificate
cd /data/nginx/certs
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout n8n.local.key -out n8n.local.crt \
    -subj "/C=KR/ST=Seoul/L=Seoul/O=Local/CN=n8n.local"

# Set proper permissions
sudo chmod 644 /data/nginx/certs/n8n.local.crt
sudo chmod 600 /data/nginx/certs/n8n.local.key
sudo chown -R root:root /data/nginx/certs

# Create data directories with proper permissions
sudo chown -R 1000:1000 /data/n8n
sudo chmod -R 755 /data/n8n

echo "Certificate generation complete!"
echo "Please add the following line to your hosts file:"
echo "172.16.10.12 n8n.local"