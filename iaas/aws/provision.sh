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
OUTPUTS=$(aws cloudformation describe-stacks --stack-name=$STACK_NAME --query "Stacks[?StackName=='"$STACK_NAME"'].Outputs")
MASTERS=$(echo "$OUTPUTS"|jq -r '.[0][0].OutputValue')
SLAVES=$(echo "$OUTPUTS"|jq -r '.[0][1].OutputValue')
MASTER_JSON=$(echo $MASTERS|jq -R 'split("|")|map(split(" ")|{"public":.[0], "private":.[1]})')
SLAVE_JSON=$(echo $SLAVES|jq -R 'split("|")|map(split(" ")|{"public":.[0], "private":.[1]})')
jq -n --argjson master "$MASTER_JSON" --argjson slave "$SLAVE_JSON" '{"master": $master, "slave": $slave}' > infrastructure.json

echo "Address all in the infrastructure.json file"
