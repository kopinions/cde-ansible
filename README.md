# CDE PAAS 

### Requirements
1. Ansible 2.0.0

```
  brew install ansible
```
	
### Sample extravars

```
{
  "ansible_user": "vagrant",
  "zookeeper_hosts": [
    {
      "address": "192.168.50.201",
      "id": 1
    }
  ],
  "consul_servers": [
    "192.168.50.201"
  ],
  "consul_bootstrap_expect": 1,
  "mesos_quorum": 1,
  "elasticsearch_masters": [
    "192.168.50.201"
  ],
  "java": "oracle-java8-installer",
  "marathon_env_java_opts": "-Xmx256m",
  "ipaddr": "{{ansible_eth1.ipv4.address}}",
  "ceph_stable": "true",
  "journal_collocation": "true",
  "journal_size": 100,
  "monitor_interface": "eth1",
  "cluster_network": "192.168.50.0/24",
  "public_network": "192.168.50.0/24",
  "devices": [
    "/dev/sdb"
  ],
  "os_tuning_params": [
    {
      "name": "kernel.pid_max",
      "value": 4194303
    },
    {
      "name": "fs.file-max",
      "value": 26234859
    }
  ],
  "control_hostname": "192.168.50.101"
}
```
上面的json文件描述了集群里的一些常用的配置，可以进行适当的更改


### Local env
1. VirtualBox latest
2. Vagrant 1.5 or later

	```
	brew install cask
	brew cask install vagrant
	vagrant plugin install vagrant-hostmanager
	```
3. Startup

	```
	vagrant up
	```
4. 准备host文件
	在项目的根目录下，有两个示例的host配置文件，```local_standalone```, ```local_ha```, 分别为本地的单机方案，和本地的高可用方案。可以使用根据自己的需要进行相应的修改
	
4. 初始化

	```
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/master.yml
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/elasticsearch.yml
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/slave.yml
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/ceph.yml
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/flocker-agent.yml
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/elasticsearch.yml
	ansible-playbook --extra-vars="@.extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/local_standalone -s -vvvv playbooks/flocker-control.yml
	```