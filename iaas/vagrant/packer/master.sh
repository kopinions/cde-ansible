#!/bin/sh -e

echo "packer: install zookeeper"
sudo apt-get -y install zookeeper zookeeperd
sudo sed -i 's/start\ on\ runlevel\ \[2345\]/start\ on\ runlevel\ \[\]/' /etc/init/zookeeper.conf

echo "packer: install mesos marathon"
sudo apt-get -y install wget curl unzip python-setuptools python-dev
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)

echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" |  sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update
sudo apt-get -y install mesos=0.25.0-0.2.70.ubuntu1404 marathon=0.15.3-1.0.463.ubuntu1404
sudo service mesos-master stop || true
sudo service mesos-slave stop || true
sudo service marathon stop || true
sudo sed -i 's/start\ on\ stopped\ rc\ RUNLEVEL=\[2345\]/start\ on\ stopped\ rc\ RUNLEVEL=\[\]/' /etc/init/mesos-slave.conf
sudo sed -i 's/start\ on\ stopped\ rc\ RUNLEVEL=\[2345\]/start\ on\ stopped\ rc\ RUNLEVEL=\[\]/' /etc/init/mesos-master.conf
