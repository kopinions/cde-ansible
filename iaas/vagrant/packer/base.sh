#!/bin/sh -e

echo "packer: create user cde"
sudo adduser --disabled-password --gecos "" cde
echo "cde ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers

echo "packer: enable swap"
sudo swapoff -a
sudo fallocate -l 4G /swap
sudo chmod 0600 /swap
sudo mkswap /swap
sudo sh -c "grep -q -F '/swap' /etc/fstab || echo '/swap none swap sw 0 0' >> /etc/fstab"
sudo swapon /swap

echo "packer: updating aptitude"
sudo apt-key update
sudo apt-get -y update
sudo apt-get -y remove apt-listchanges
sudo apt-get -y install python-software-properties
sudo add-apt-repository -y ppa:webupd8team/java
sudo apt-get -y update

echo "packer: install docker deps"
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo sh -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-trusty main" > /etc/apt/sources.list.d/docker.list'
sudo apt-get -y update
sudo apt-get -y install apparmor linux-image-extra-$(uname -r)
sudo apt-get -y install linux-image-generic-lts-trusty

echo "packer: enable cgroups for docker"
sudo sed -ie '/GRUB_CMDLINE_LINUX/d' /etc/default/grub
sudo sh -c "echo 'GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"' >> /etc/default/grub"
sudo update-grub
sudo sh -c "sed -i '/^kernel/ s/$/ cgroup_enable=memory swapaccount=1 /' /boot/grub/menu.lst"
sleep 240

echo "packer: install docker"
sudo apt-get -y install docker-engine=1.9.1-0~trusty
sudo service docker stop || true

echo "pakcer: install jdk"
sudo sh -c "echo oracle-java8-installer shared/accepted-oracle-license-v1-1 select true | /usr/bin/debconf-set-selections"
sudo apt-get -y install oracle-java8-installer
sudo apt-get -y install oracle-java8-set-default

echo "packer: install dnsmasq"
sudo apt-get -y install dnsmasq
sudo service dnsmasq stop || true

echo "packer: install consul"
sudo apt-get -y install unzip jq
curl -jksSL -o /tmp/consul_0.6.3_linux_amd64.zip "https://releases.hashicorp.com/consul/0.6.3/consul_0.6.3_linux_amd64.zip"
sudo mkdir -p /opt/consul/bin/
sudo unzip /tmp/consul_0.6.3_linux_amd64.zip -d /opt/consul/bin/

echo "packer: install logstash && topbeat"
curl https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
echo 'deb http://packages.elastic.co/logstash/2.2/debian stable main' | sudo tee -a /etc/apt/sources.list
sudo apt-get -y update && sudo apt-get -y install logstash
sudo service logstash stop || true

echo "packer: install topbeat"
curl https://packages.elasticsearch.org/GPG-KEY-elasticsearch | sudo apt-key add -
echo 'deb https://packages.elastic.co/beats/apt stable main' | sudo tee -a /etc/apt/sources.list.d/beats.list
sudo apt-get -y update && sudo apt-get -y install topbeat
sudo service topbeat stop || true
