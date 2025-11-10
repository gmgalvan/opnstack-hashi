#!/bin/bash
# scripts/install-nginx.sh

set -e

echo "Installing Nginx..."

# Update package list
apt-get update

# Install Nginx
apt-get install -y nginx

# Configure Nginx
echo 'daemon off;' >> /etc/nginx/nginx.conf

# Clean up
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "Nginx installation completed!"