#!/bin/sh -e

echo "packer: nginx"
echo "deb http://nginx.org/packages/mainline/ubuntu/ trusty nginx" | sudo tee -a /etc/apt/sources.list
echo "deb-src http://nginx.org/packages/mainline/ubuntu/ trusty nginx" | sudo tee -a /etc/apt/sources.list
cd /etc/apt
sudo wget http://nginx.org/keys/nginx_signing.key
sudo apt-key add nginx_signing.key
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C
sudo apt-get -y update
sudo apt-get -y install nginx
sudo service nginx stop || true

echo "packer: download consul-template"
curl -o /tmp/consul-template_0.14.0_linux_amd64.zip https://releases.hashicorp.com/consul-template/0.14.0/consul-template_0.14.0_linux_amd64.zip
