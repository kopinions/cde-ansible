#!/bin/sh -e

echo "packer: install mesos"
sudo apt-get -y install wget curl unzip python-setuptools python-dev
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv E56151BF

DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
CODENAME=$(lsb_release -cs)
echo "deb http://repos.mesosphere.com/${DISTRO} ${CODENAME} main" | sudo tee /etc/apt/sources.list.d/mesosphere.list
sudo apt-get -y update
sudo apt-get -y install mesos=0.25.0-0.2.70.ubuntu1404
sudo service mesos-master stop || true
sudo service mesos-slave stop || true