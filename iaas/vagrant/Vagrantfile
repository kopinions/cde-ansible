# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'
require 'open3'

Vagrant.require_version ">= 1.6.5"
BASEDIR=File.dirname(__FILE__)

MASTER_COUNT=1
SLAVE_COUNT=3

username = 'ubuntu'

$script = <<SCRIPT
sed -i 's#GRUB_CMDLINE_LINUX.*$#GRUB_CMDLINE_LINUX=\"cgroup_enable=memory swapaccount=1\"#' /etc/default/grub
update-grub
swapoff -a
fallocate -l 8G /swap
chmod 600 /swap
mkswap /swap
swapon /swap
grep -q -F '/swap' /etc/fstab || echo '/swap none swap sw 0 0' >> /etc/fstab

sed -i '/127.0.1.1/d' /etc/hosts

sudo su
adduser --disabled-password --gecos "" #{username}
echo "#{username} ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
su ubuntu
mkdir -p /home/#{username}/.ssh
chmod 700 /home/#{username}/.ssh
cp /home/vagrant/.ssh/authorized_keys /home/#{username}/.ssh/authorized_keys
chown #{username}:#{username} /home/#{username}/.ssh/authorized_keys
chmod 600 .ssh/authorized_keys
SCRIPT


unless Vagrant.has_plugin?("vagrant-triggers")
  raise Vagrant::Errors::VagrantError.new, "Please install the vagrant-triggers plugin running 'vagrant plugin install vagrant-triggers'"
end

ansible_extra_vars = {
    ansible_user: "vagrant",
    zookeeper_hosts: (1..MASTER_COUNT).collect { |i| {address: "192.168.50.#{200+i}", id: i} },
    consul_servers: (1..MASTER_COUNT).collect { |i| "192.168.50.#{200+i}" },
    consul_bootstrap_expect: 1,
    mesos_quorum: 1,
    elasticsearch_masters: (1..MASTER_COUNT).collect { |i| "192.168.50.#{200+i}" },
    java: "oracle-java8-installer",
    marathon_env_java_opts: "-Xmx256m",
    ipaddr: "{{ansible_eth1.ipv4.address}}",

    ceph_stable: 'true',
    journal_collocation: 'true',
    journal_size: 100,
    monitor_interface: 'eth1',
    cluster_network: "192.168.50.0/24",
    public_network: "192.168.50.0/24",
    devices: ['/dev/sdb'],
    os_tuning_params: [
      {name: 'kernel.pid_max', value: 4194303},
      {name: 'fs.file-max', value: 26234859}
    ],

    control_hostname: '192.168.50.101'
}

File.open("#{BASEDIR}/contrib/iaas/vagrant/.extravars.json", "w") {|file| file.puts JSON.pretty_generate(ansible_extra_vars) }

Vagrant.configure("2") do |config|
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  # always use Vagrants insecure key
  config.ssh.insert_key = false
  config.vm.synced_folder "/", "/vagrant", disabled: true

  config.vm.provider :virtualbox do |v|
    v.check_guest_additions = false
    v.functional_vboxsf = false
    v.gui = false
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  (1..MASTER_COUNT).each do |machine_id|
    config.vm.define "master#{machine_id}" do |vm|
	  vm.vm.box = "master"
      vm.vm.hostname = "192-168-50-#{200+machine_id}"
      vm.vm.network :private_network, ip: "192.168.50.#{200+machine_id}"
      vm.vm.provider :virtualbox do |vb|
        vb.memory = 1024
        vb.cpus = 1
        disk_file = "#{BASEDIR}/disk-master#{machine_id}.vdi"
        unless File.exist?(disk_file)
          vb.customize ['createhd', '--filename', disk_file, '--size', 20000]
        end
        vb.customize ['storageattach', :id,
              '--storagectl', 'SATAController',
              '--port', 3 + 0,
              '--device', 0,
              '--type', 'hdd',
              '--medium', "#{disk_file}"]
      end
      vm.vm.provision "shell" do |s|
        s.inline = $script
        s.privileged = true
      end
    end
  end

  (1..SLAVE_COUNT).each do |machine_id|
    config.vm.define "slave#{machine_id}" do |vm|
      vm.vm.box = "slave"
      vm.vm.hostname = "192-168-50-#{100+machine_id}"
      vm.vm.network :private_network, ip: "192.168.50.#{100+machine_id}"
      vm.vm.provider :virtualbox do |vb|
        vb.memory = 3072
        vb.cpus = 3
        disk_file = "#{BASEDIR}/disk-slave#{machine_id}.vdi"
        unless File.exist?(disk_file)
          vb.customize ['createhd', '--filename', disk_file, '--size', 20000]
        end
        vb.customize ['storageattach', :id,
              '--storagectl', 'SATAController',
              '--port', 3 + 0,
              '--device', 0,
              '--type', 'hdd',
              '--medium', "#{disk_file}"]
      end
      vm.vm.provision "shell" do |s|
        s.inline = $script
        s.privileged = true
      end
    end
  end
end
