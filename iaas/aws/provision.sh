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


MASTER_SCALE_GROUP=$(aws --output=text cloudformation describe-stack-resources --stack-name=${STACK_NAME} --query="StackResources[?LogicalResourceId=='MasterGroup'].PhysicalResourceId")
MASTER_HEALTH_COUNT=$(aws autoscaling  describe-auto-scaling-groups --auto-scaling-group-names=${MASTER_SCALE_GROUP} --query "AutoScalingGroups[].Instances[?HealthStatus=='Healthy'][]" |jq 'length')
MASTER_COUNT=$(aws --output=text cloudformation describe-stacks --stack-name=${STACK_NAME} --query="Stacks[][Parameters][][?ParameterKey=='MasterCount'].ParameterValue")
echo "Wait master init"
until [[ $MASTER_HEALTH_COUNT -eq "$MASTER_COUNT" ]]; do
    echo "Wait master init"
    MASTER_HEALTH_COUNT=$(aws autoscaling  describe-auto-scaling-groups --auto-scaling-group-names=${MASTER_SCALE_GROUP} --query "AutoScalingGroups[].Instances[?HealthStatus=='Healthy'][]"|jq 'length')
done


SLAVE_SCALE_GROUP=$(aws --output=text cloudformation describe-stack-resources --stack-name=${STACK_NAME} --query="StackResources[?LogicalResourceId=='SlaveGroup'].PhysicalResourceId")
SLAVE_HEALTH_COUNT=$(aws autoscaling  describe-auto-scaling-groups --auto-scaling-group-names=${SLAVE_SCALE_GROUP} --query "AutoScalingGroups[].Instances[?HealthStatus=='Healthy'][]"|jq 'length')
SLAVE_COUNT=$(aws --output=text cloudformation describe-stacks --stack-name=${STACK_NAME} --query="Stacks[][Parameters][][?ParameterKey=='SlaveCount'].ParameterValue")
echo "Wait slave init"
until [[ $SLAVE_HEALTH_COUNT -eq $SLAVE_COUNT ]]; do
    echo "Wait slave init"
    SLAVE_HEALTH_COUNT=$(aws autoscaling  describe-auto-scaling-groups --auto-scaling-group-names=${SLAVE_SCALE_GROUP} --query "AutoScalingGroups[].Instances[?HealthStatus=='Healthy'][]"|jq 'length')
done

echo "All instance are initilized"
MASTERS_IDS=$(aws --output=text autoscaling  describe-auto-scaling-groups --auto-scaling-group-names=${MASTER_SCALE_GROUP} --query "AutoScalingGroups[].Instances[].InstanceId")
SLAVE_IDS=$(aws --output=text autoscaling  describe-auto-scaling-groups --auto-scaling-group-names=${SLAVE_SCALE_GROUP} --query "AutoScalingGroups[].Instances[].InstanceId")

MASTER_JSON=$(aws ec2 describe-instances --instance-ids $MASTERS_IDS --query="Reservations[].Instances[]"|jq 'map({"public":.PublicIpAddress, "private": .PrivateIpAddress})')
SLAVE_JSON=$(aws ec2 describe-instances --instance-ids $SLAVE_IDS --query="Reservations[].Instances[]"|jq 'map({"public":.PublicIpAddress, "private": .PrivateIpAddress})')

jq -n --argjson master "$MASTER_JSON" --argjson slave "$SLAVE_JSON" '{"master": $master, "slave": $slave}' > infrastructure.json
echo "Address all in the infrastructure.json file"
