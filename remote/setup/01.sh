#!/bin/bash
set -eu

# ==================================================================================== #
# VARIABLES
# ==================================================================================== #

TIMEZONE=Asia/Ho_Chi_Minh

USERNAME=greenlight

# note: can't seem to set a Postgres DB user password that has dollar sign characters when creating new user
# (set the password manually using \password meta command is OK though)
read -p "Enter password for greenlight DB user: " DB_PASSWORD

# force all output to be presented in en_US for the duration of this script
# this avoids any "setting locale failed" errors before installing support for all locales
# do not change this setting!
export LC_ALL=en_US.UTF-8

# ==================================================================================== #
# SCRIPT LOGIC
# ==================================================================================== #

# enable the "universe" repository
# https://help.ubuntu.com/community/Repositories/Ubuntu
add-apt-repository --yes universe

# update all software packages 
# --force-confnew flag means that configuration files will be replaced if newer ones are available
apt update
apt --yes -o Dpkg::Options::="--force-confnew" upgrade

# set timezone and install all locales
timedatectl set-timezone ${TIMEZONE}
apt --yes install locales-all

# add new user and give them sudo privileges
useradd --create-home --shell "/bin/bash" --groups sudo "${USERNAME}"

# force a password to be set for the new user the first time they log in
passwd --delete "${USERNAME}"
chage --lastday 0 "${USERNAME}"

# copy the SSH keys from the root user to the new user
rsync --archive --chown=${USERNAME}:${USERNAME} /root/.ssh /home/${USERNAME}

# configure the firewall to allow SSH, HTTP and HTTPS traffic
ufw allow 22
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# install fail2ban
apt --yes install fail2ban

# install golang-migrate
curl -L https://github.com/golang-migrate/migrate/releases/download/v4.14.1/migrate.linux-amd64.tar.gz | tar xvz
mv migrate.linux-amd64 /usr/local/bin/migrate

# install PostgreSQL
apt --yes install postgresql

# set up the DB and create a user account
sudo -i -u postgres psql -c "CREATE DATABASE greenlight"
sudo -i -u postgres psql -d greenlight -c "CREATE EXTENSION IF NOT EXISTS citext"
sudo -i -u postgres psql -d greenlight -c "CREATE ROLE greenlight WITH LOGIN PASSWORD '${DB_PASSWORD}'"

# add a DSN to system-wide environment variables
echo "GREENLIGHT_DB_DSN='postgres://greenlight:${DB_PASSWORD}@localhost/greenlight'" >> /etc/environment

# install Caddy
# https://caddyserver.com/docs/install#debian-ubuntu-raspbian
apt --yes install -y debian-keyring debian-archive-keyring apt-transport-https
curl -L https://dl.cloudsmith.io/public/caddy/stable/gpg.key | sudo apt-key add -
curl -L https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt | sudo tee -a /etc/apt/sources.list.d/caddy-stable.list
apt update
apt --yes install caddy

echo "Script complete! Rebooting..."
reboot
