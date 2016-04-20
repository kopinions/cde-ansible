# CDE PAAS 

### Requirements
1. Ansible 2.0.0

```
  brew install ansible
```
	
### <a name="extravars">基础配置文件</a>

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
5. 获取依赖的ansible role
	
	```
	git clone https://github.com/sjkyspa/stacks.git $GOPATH/src/github.com/sjkyspa/stacks
	cd $GOPATH/src/github.com/sjkyspa/stacks
	ansible-galaxy install -r playbooks/roles.yml -p playbooks/roles --force
	```	
6. 基础环境部署

	```
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/master.yml
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/elasticsearch.yml
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/slave.yml
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/ceph.yml
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/flocker-agent.yml
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/elasticsearch.yml
	ansible-playbook --extra-vars="@extravars_standlone.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_standalone -s -vvvv playbooks/flocker-control.yml
	```

### AWS
1. install aws client and depends tools
	
	```
    brew install awscli
    brew install jq
	```
2. config aws client

	```
	aws configure
	```
3.  初始化aws机器

	```
    ./provision.sh cde
	```
4. 准备aws hosts 文件
   在运行过```./provision.sh cde```之后,会在iaas/aws/目录下生成当前基础结构的ip,文件名为```infrastructure.json```,根据机器的IP来准备相应的hosts文件,可以参考```hosts_ha```进行相应的准备
5. 准备相应的extravars.json 文件
    根据生成的infrastructure.json 来准备相应的extravars.json 文件,具体参照<a href="#extravars">基础配置文件</a>
5. 基础环境部署

	```
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/master.yml
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/elasticsearch.yml
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/slave.yml
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/ceph.yml
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/flocker-agent.yml
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/elasticsearch.yml
	ansible-playbook --extra-vars="@extravars_ha.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=playbooks/hosts_ha -s -vvvv playbooks/flocker-control.yml
	```