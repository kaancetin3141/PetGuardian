#!/usr/bin/env bash
# PetGuardian — one-time EC2/Ubuntu server setup.
# Run ON THE SERVER as a sudo-capable user:
#   bash setup-server.sh
# Idempotent: safe to re-run.
set -euo pipefail

APP=petguardian
WWW_ROOT=/var/www/$APP

echo "==> packages (nginx + rsync for deploys + ufw + certbot later)"
sudo apt-get update -y
sudo apt-get install -y nginx rsync ufw

echo "==> release directory layout (atomic symlink swap => instant rollback)"
sudo mkdir -p "$WWW_ROOT/releases"
# NOTE: current/ is intentionally NOT created here as a real directory.
# ln -sfn into an existing real directory nests the link INSIDE it
# (current/releases/<ts>) instead of replacing it — the first deploy would
# silently point nginx at an empty root. server-deploy.sh creates the
# symlink itself; nginx starts fine without the root existing.
sudo chown -R "$USER:$USER" "$WWW_ROOT/releases"

echo "==> nginx site"
sudo cp "$(dirname "$0")/petguardian.nginx.conf" /etc/nginx/sites-available/$APP
sudo ln -sfn /etc/nginx/sites-available/$APP /etc/nginx/sites-enabled/$APP
# The stock "default" site competes for port 80 on the same root.
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl reload nginx

echo "==> firewall (SSH stays open; tighten the 22 rule to your IP in AWS SG too)"
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo "==> swap (t3.micro has 1 GB RAM; 1G swap prevents OOM during apt/nginx)"
if ! swapon --show | grep -q .; then
  sudo fallocate -l 1G /swapfile || sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
  echo '/etc/swappiness set to 10'
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-petguardian.conf
  sudo sysctl --system
fi

echo
echo "DONE. Next: run deploy/server-deploy.sh after uploading a build,"
echo "then open port 80 from your browser: http://<public-dns>"
