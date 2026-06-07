#!/bin/bash
set -ex
exec > /var/log/user-data.log 2>&1

echo "=== Starting setup at $(date) ==="

# Update packages
dnf update -y
dnf install -y git

# Install Node.js 18 from NodeSource
curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
dnf install -y nodejs

# Verify Node.js installed
node --version
npm --version

# Install Nginx
dnf install -y nginx
systemctl start nginx
systemctl enable nginx

# Clone the Todo app
cd /home/ec2-user
git clone https://github.com/Himanshu-Sangshetti/Todo-Two-Tier.git
cd Todo-Two-Tier

# Create .env file with RDS and ALB details
# These values are injected by Terraform templatefile()
cat > .env << ENVEOF
DB_HOST="${db_host}"
DB_USER="${db_user}"
DB_PASSWORD="${db_pass}"
DB_NAME="${db_name}"
PORT="3306"
API_BASE_URL="http://${alb_dns}"
ENVEOF

echo "=== .env file created ==="
cat .env

# Install app dependencies
npm install

# Install PM2 to keep app running
npm install -g pm2
pm2 start index.js --name todo-app
pm2 startup systemd -u ec2-user --hp /home/ec2-user
env PATH=$PATH:/usr/bin pm2 startup systemd -u ec2-user --hp /home/ec2-user
pm2 save

# Fix file ownership
chown -R ec2-user:ec2-user /home/ec2-user/Todo-Two-Tier

# Configure Nginx as reverse proxy
cat > /etc/nginx/nginx.conf << 'NGINXEOF'
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }

        location /static/ {
            root /home/ec2-user/Todo-Two-Tier/public;
        }
    }
}
NGINXEOF

# Test and restart Nginx
nginx -t
systemctl restart nginx

echo "=== Setup complete at $(date) ==="
