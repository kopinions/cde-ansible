# CDE PAAS 

## 系统部署架构
![](./assets/infra.jpg)

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
上面的json文件描述了集群里的一些常用的配置，可以进行适当的更改. 其中具体配置项的意思如下表所示:

|字段(以jsonpath的方式描述)|说明|参数值|备注|
|---|---|---|---|
|ansible_user|这个值用来设置ansible部署的时候采用的登陆用户|ubuntu/vagrant| |
|zookeeper_hosts|这个用来配置zookeeper的集群的结构,并且mesos master和marathon需要依赖这个变量来进行ha|[{"address":"xxx", "id":"1"}]| zookeeper的内网IP和对应机器的ID|
|consul_servers|consul master机器IP列表|["ip1", "ip2"]||
|consul_bootstrap_expect|当consul server台数达到多少台的时候，进行master的选举|一般等于consul server 的数量||
|mesos_quorum|quorum是举行投票的法定最低人数|floor(master count /2+1)|总是mesos master 数量一般多一，mesos master的数量为奇数|
|elasticsearch_masters|elasticsearch 的主控节点|master的ip数组||
| java |java在ubuntu下的软件包名|oracle-java8-installer|||
| marathon_env_java_opts| marathon 的java 的虚拟机配置|-Xmx521m||
|ipaddr|机器的ip|当使用aws机器的时候，只有一张网卡，使用{{ansible_eth0.ipv4.address}}，当使用vagrant的时候有两张网卡，eth0是只能被host和vm通信的网卡，所以使用{{ansible_eth1.ipv4.address}}||
| ceph_stable |是否使用ceph的stable version|true/false||
|monitor_interface|ceph monitor监听的网络接口|当使用aws机器的时候，只有一张网卡，使用eth0，当使用vagrant的时候有两张网卡，"eth0"是只能被host和vm通信的网卡，所以使用"eth1"|
|cluster_network||||
|public_network||||
|devices|ceph osd 用来放置数据的单独的磁盘名|在vagrant里面单独加入的磁盘以sd[b,c,d...]的形式存在，所以vagrant可以使用的值为：["/dev/sdb"],使用aws单独添加的磁盘以xvd[b,c,d..]方式存在所以可以使用的值为["/dev/xvdb"]||
| control_hostname |flocker control的机器ip|ip|参见host文件里的ip|



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
3. 配置aws机器以及类型

	```
	vim iaas/aws/customization.json
	```
	更改相应的变量配置
4. 初始化aws机器

	```
    ./provision.sh cde
	```
5. 准备aws hosts 文件
   在运行过```./provision.sh cde```之后,运行  
   ```
   ./prepare_hosts.sh   
   ```  
   来准备相应的hosts文件
   
6. 在运行过```./prepare_hosts.sh ```之后,运行  
      ```
      ./prepare_extravars.sh 
      ```  
    来准备相应的extravars.json 文件
    
    手动添加ansible_ssh_private_key_file至extravars.json文件
    
7. 获取依赖的ansible role  
    到```/contrib/ansible```目录下执行
	
	```
	ansible-galaxy install -r playbooks/roles.yml -p playbooks/roles --force
	```

根据所起机器的资源，更改```/playbook/group_vars/```中mesos-master, mesos-slave的cpus, mem, disk
等配置。

8. 基础环境部署

	```
	ansible-playbook --extra-vars="@../iaas/aws/extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=../iaas/aws/hosts playbooks/master.yml
	ansible-playbook --extra-vars="@../iaas/aws/extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=../iaas/aws/hosts playbooks/slave.yml
	ansible-playbook --extra-vars="@../iaas/aws/extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=../iaas/aws/hosts playbooks/ceph.yml
    暂时不执行以下命令
	ansible-playbook --extra-vars="@../iaas/aws/extravars.json" --connection=ssh --timeout=30 --limit='all' --inventory-file=../iaas/aws/hosts playbooks/elasticsearch.yml
	```
	ceph-ansible的role单独存在，需手动在ansible.cfg中添加action_plugins的path，用冒号分隔即可。
	
	机器启动之后，立刻设置master的安全策略！  
	EC2 > Security Group > check MasterSecurityGroup > Inbound > Edit > 8080, 5050, 8500 > My IP
	
9. 修改cdectl.json内IP地址，注意public，private地址之分
	
10. 修改cdectl.json内es的meta url，地址在Amazon Analytic Elasticsearch Service + ":80"

11. 修改cdectl.json内platform的cname value为相应域名

11. 修改registry-mirror.tmpl， builder.tmpl， registry.tmpl，controller.tmpl， launcher.tmpl文件，
删除rbd，例如：
```
{
  "id": "registry-mirror",
  "cpus": {{ component "registry-mirror" | attribute "cpu" }},
  "mem": {{ component "registry-mirror" | attribute "mem" }},
  "instances": 1,
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "{{ component "registry-mirror" | attribute "image" }}",
      "network": "BRIDGE",
      "portMappings": [
        { "containerPort": 5000, "hostPort": 31505 }
      ],
      "parameters": [
        {
          "key": "volume",
          "value": "/docker-registry-mirror:/var/lib/registry"
        }
      ]
    }
  },
  "constraints": [
    [
      "hostname",
      "LIKE",
      "172.31.16.211"
    ]
  ],
   "healthChecks": [
     {
       "path": "/",
       "portIndex": 0,
       "protocol": "HTTP",
       "gracePeriodSeconds": 120,
       "intervalSeconds": 5,
       "timeoutSeconds": 5,
       "maxConsecutiveFailures": 10
     }
   ]
}
```

load-balancer
Instance > Edit Instances > add slaves machines

12. cdectl deploy  
```
    export CDECTL_TUNNEL=13.115.248.191   #(master中leader的public IP)  
    export DEV_REGISTRY=hub.deepi.cn  
    export CDECTL_USERNAME=ubuntu  
    export CDECTL_CONFIG=/workplace/golang/src/github.com/sjkyspa/stacks/cdectl/conf/cdectl.json #（cdectl.json的绝对路径）  
    eval `ssh-agent -s`  
    ssh-add /datastore/nutstore/6-Career/solutions/paas/paas/morpheus_tk.pem #（key的绝对路径）  
    
    在stack根目录下运行  
    CDE_VERSION=git-xxxxxxx make deploy  
    xxx为需要部署的git log号  
```
	
	
9. 准备相应的desktop 用来访问相应的管理界面  
	在aws开一台服务器，然后配置desktop，然后访问管理界面
	配置desktop
	
	```
	sudo vim /etc/ssh/sshd_config # edit line "PasswordAuthentication" to yes
	sudo /etc/init.d/ssh restart
	sudo apt-get update
	sudo apt-get install ubuntu-desktop
	sudo apt-get install vnc4server
	vncserver

	vncserver -kill :1
	
	vim awsgui/.vnc/xstartup
   ``` 
   Then hit the Insert key, scroll around the text file with the keyboard arrows, and delete the pound (#) sign from the beginning of the two lines under the line that says "Uncomment the following two lines for normal desktop." And on the second line add "sh" so the line reads
   
	```
	exec sh /etc/X11/xinit/xinitrc.
	vncserver
	```

	config the security group make the desktop can access the masters and slaves.