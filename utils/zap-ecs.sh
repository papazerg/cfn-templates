#!/bin/bash

environment=$1

for cluster in $(aws ecs list-clusters --query 'clusterArns[]' --output table | grep indigo-$environment-empire | awk '{print $2}'); do
  for service in $(aws ecs list-services --cluster $cluster --query 'serviceArns[]' --output text); do
    aws ecs update-service --cluster $cluster --service $service --desired-count 0
    aws ecs delete-service --cluster $cluster --service $service
  done
  for instance in $(aws ecs list-container-instances --cluster $cluster --query 'containerInstanceArns[]' --output text); do
    id=$(aws ecs describe-container-instances --cluster $cluster --container-instances $instance --query 'containerInstances[].ec2InstanceId' --output text)
    aws ecs deregister-container-instance --cluster $cluster --container-instance $instance
    answer='n'
    echo -n "Terminate instance $id? [Y/n] "
    read answer
    case $answer in
      Y|y)
        aws ec2 terminate-instances --instance-ids $id
      ;;
      *)
      ;;
    esac
  done
  aws ecs delete-cluster --cluster $cluster
done

# TODO: zap orphaned load balanacers.
