#!/usr/bin/env bash
STACK_NAME=${STACK_NAME:=cde}
aws cloudformation describe-stacks --stack-name=$STACK_NAME
if [[ $? -ne 0 ]]; then
    echo "Stack not exits"
    exit 1
fi

aws cloudformation delete-stack --stack-name=$STACK_NAME
COMPLETE_EVENT=$(aws --output=text cloudformation describe-stack-events --stack-name=$STACK_NAME --query "StackEvents[?ResourceStatus=='DELETE_COMPLETE' && ResourceType=='AWS::CloudFormation::Stack']")
if [[ $? -ne 0 ]] && [[ $(echo $COMPLETE_EVENT|grep "not exist") -eq 0 ]]; then
  echo "Stack $STACK_NAME not found"
  exit 1
fi

until [[ $(echo $COMPLETE_EVENT|wc -l) -eq 1 ]] && [[ ! -z $COMPLETE_EVENT ]] && [[ $COMPLETE_EVENT != " " ]]; do
  COMPLETE_EVENT=$(aws --output=text cloudformation describe-stack-events --stack-name=$STACK_NAME --query "StackEvents[?ResourceStatus=='DELETE_COMPLETE' && ResourceType=='AWS::CloudFormation::Stack']" 2>&1)
  if [[ $? -ne 0 ]] && [[ $(echo $COMPLETE_EVENT|grep "not exist") -eq 0 ]]; then
    echo "Stack $STACK_NAME has been deprovisioned"
    exit 0
  fi

  echo "Waitting for stack deprovision complete"
  if [[ $(aws --output=text cloudformation describe-stack-events --stack-name=$STACK_NAME --query "StackEvents[?ResourceStatus=='DELETE_FAILED' && ResourceType=='AWS::CloudFormation::Stack']"|wc -l) -eq 1 ]]; then
    echo "Stack Deprovision failed"
    exit 1
  fi
  sleep 1
done
