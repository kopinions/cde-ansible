#!/usr/bin/env bash
pushd $(dirname $0) > /dev/null
BASEDIR=`pwd`
popd > /dev/null
STACK_NAME=${STACK_NAME:-cde}
aws cloudformation create-stack --stack-name=$STACK_NAME --template-body="$(<cde.json)" --parameters="$(<customization.json)"
CREATE_COMPLETE=$(aws --output=text cloudformation describe-stack-events --stack-name=$STACK_NAME --query "StackEvents[?ResourceStatus=='CREATE_COMPLETE' && ResourceType=='AWS::CloudFormation::Stack']")
if [[ $? -ne 0 ]] && [[ $(echo $CREATE_COMPLETE|grep "not exist") -eq 0 ]]; then
  echo "Stack $STACK_NAME not found"
  exit 1
fi

until [[ $(echo $CREATE_COMPLETE|wc -l) -eq 1 ]] && [[ ! -z $CREATE_COMPLETE ]] && [[ $CREATE_COMPLETE != " " ]]; do
  echo "Waitting for stack init complete"
  CREATE_COMPLETE=$(aws --output=text cloudformation describe-stack-events --stack-name=$STACK_NAME --query "StackEvents[?ResourceStatus=='CREATE_COMPLETE' && ResourceType=='AWS::CloudFormation::Stack']")
  if [[ $? -ne 0 ]]; then
    echo "Stack Create failed"
    exit 1
  fi

  CREATE_FAILED=$(aws --output=text cloudformation describe-stack-events --stack-name=$STACK_NAME --query "StackEvents[?ResourceStatus=='CREATE_FAILED' && ResourceType=='AWS::CloudFormation::Stack']")
  if [[ $? -ne 0 ]]; then
    echo "Stack Create failed"
    exit 1
  fi
  if [[ $(echo $CREATE_FAILED|wc -l) -eq 1 ]] && [[ ! -z $CREATE_FAILED ]] && [[ $CREATE_FAILED != " " ]]; then
    echo "Stack Create failed"
    exit 1
  fi

  sleep 1
done


INSTANCE_IDS=$(aws --output text \
  cloudformation describe-stack-resources --stack-name=$STACK_NAME \
  --query "StackResources[?ResourceType=='AWS::EC2::Instance'].PhysicalResourceId")
PASSED_INSTANCE_IDS=$(aws --output=text ec2 describe-instance-status \
    --filters Name=instance-status.reachability,Values=passed \
    --instance-ids $INSTANCE_IDS \
    --query 'InstanceStatuses[].[ InstanceId ]')
diff <(echo $INSTANCE_IDS|tr ' ' '\n' | sort) <(echo $PASSED_INSTANCE_IDS| tr ' ' '\n' | sort) &>/dev/null
INITILIZED=$?
until [[ $INITILIZED -eq 0 ]]; do
  PASSED_INSTANCE_IDS=$(aws --output=text ec2 describe-instance-status \
      --filters Name=instance-status.reachability,Values=passed \
      --instance-ids $INSTANCE_IDS \
      --query 'InstanceStatuses[].[ InstanceId ]')
  diff <(echo $INSTANCE_IDS|tr ' ' '\n' | sort) <(echo $PASSED_INSTANCE_IDS| tr ' ' '\n' | sort) &>/dev/null
  INITILIZED=$?
  echo "Waitting the instance initilizing"
  sleep 1
done

echo "All instance are initilized"
export ANSIBLE_HOST_KEY_CHECKING=False
OUTPUTS=$(aws --output=text cloudformation describe-stacks --stack-name=$STACK_NAME --query "Stacks[?StackName=='"$STACK_NAME"'].Outputs")
MASTERS=$(echo "$OUTPUTS"|grep "Masters"|sed -e 's/[a-zA-Z]*//g'|sed -e 's/^[[:blank:]]*//g'|tr '|' '\n'|sed -e 's/[[:blank:]]/|/g')
SLAVES=$(echo "$OUTPUTS"|grep "Slaves"|sed -e 's/[a-zA-Z]*//g'|sed -e 's/^[[:blank:]]*//g'|tr '|' '\n'|sed -e 's/[[:blank:]]/|/g')

cd ../../

PEM_PATH="$(pwd)/.env/awsgo.pem"

cd contrib/aws

FLOCKER_CONTROL=$(echo "$SLAVES"|awk -F'|' '{print $0}'|sed -ne '1p')
echo "$MASTERS"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[mesos-master]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' > hosts
echo "$MASTERS"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[mons]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$MASTERS"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[osds]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$SLAVES"|awk -v PEM_PATH=$PEM_PATH -F'|' '{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$MASTERS"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[marathon]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$MASTERS"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[consul-server]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$MASTERS"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[zookeeper]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$SLAVES"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[mesos-slave]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$SLAVES"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[flocker-agent]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts
echo "$FLOCKER_CONTROL"|awk -v PEM_PATH=$PEM_PATH -F'|' 'BEGIN {print "[flocker-control]"}{print $1 " ansible_ssh_user=ubuntu ansible_ssh_private_key_file=" PEM_PATH " privateip=" $2}' >> hosts

ZOOKEEPER_HOSTS=$(echo "$MASTERS"| awk -F'|' 'BEGIN{ORS = ""; print "[";} { print "\/\@"$2"\/\@"; } END { print "]"; }'| sed "s^\"^\\\\\"^g;s^\/\@\/\@^\", \"^g;s^\/\@^\"^g"|jq 'to_entries|map({address:.value, id: .key})|map(.id+=1)')
echo $ZOOKEEPER_HOST
CONSUL_HOSTS=$(echo "$MASTERS"| awk -F'|' 'BEGIN{ORS = ""; print "[";} { print "\/\@"$2"\/\@"; } END { print "]"; }'| sed "s^\"^\\\\\"^g;s^\/\@\/\@^\", \"^g;s^\/\@^\"^g")
CONTROL_HOSTNAME=$(echo "$FLOCKER_CONTROL"| awk -F'|' '{print $2}')
jq -n --argjson zk "$ZOOKEEPER_HOSTS" --argjson consul "$CONSUL_HOSTS" --arg control_hostname "$CONTROL_HOSTNAME" '{zookeeper_hosts:$zk, consul_servers:$consul, control_hostname:$control_hostname, devices: ["/dev/xvdb"]}' > .extra-vars.json

cd ../../

ansible-playbook --extra-vars="@$BASEDIR/.extra-vars.json" --connection=ssh --timeout=60 --inventory-file="$BASEDIR/hosts" -s playbooks/master.yml
ansible-playbook --extra-vars="@$BASEDIR/.extra-vars.json" --connection=ssh --timeout=60 --inventory-file="$BASEDIR/hosts" -s playbooks/slave.yml
cd playbooks
ansible-playbook --extra-vars="@$BASEDIR/.extra-vars.json" --connection=ssh --timeout=60 --inventory-file="$BASEDIR/hosts" -s ceph.yml -vvvv
cd ../
ansible-playbook --extra-vars="@$BASEDIR/.extra-vars.json" --connection=ssh --timeout=60 --inventory-file="$BASEDIR/hosts" -s playbooks/flocker-agent.yml
ansible-playbook --extra-vars="@$BASEDIR/.extra-vars.json" --connection=ssh --timeout=60 --inventory-file="$BASEDIR/hosts" -s playbooks/flocker-control.yml
