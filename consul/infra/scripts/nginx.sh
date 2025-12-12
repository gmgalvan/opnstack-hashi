# Install nginx
sudo apt update
sudo apt install -y nginx

# Start nginx
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify it's running
curl localhost