require 'sparkle_formation'
require_relative '../../../utils/environment'
require_relative '../../../utils/lookup'

ENV['net_type'] ||= 'Private'
ENV['sg']       ||= 'private_sg'
ENV['run_list'] ||= 'role[base],role[squabbler]'

lookup = Indigo::CFN::Lookups.new
vpc = lookup.get_vpc

SparkleFormation.new('squabbler').load(:precise_ruby223_ami, :ssh_key_pair, :chef_validator_key_bucket).overrides do
  set!('AWSTemplateFormatVersion', '2010-09-09')
  description <<EOF
Creates auto scaling groups for squabbler daemons.  Each instance is
given an IAM instance profile, which allows the instance to get objects from the Chef Validator Key Bucket.

Run this template while running the compute and webserver templates.  Depends on the rabbitmq
and databases stacks.
EOF

  dynamic!(:iam_instance_profile, 'default', :policy_statements => [ :chef_bucket_access ])

  dynamic!(:launch_config_chef_bootstrap, 'squabbler', :instance_type => 't2.small', :create_ebs_volumes => false, :security_groups => lookup.get_security_group_ids(vpc), :chef_run_list => ENV['run_list'])
  dynamic!(:auto_scaling_group, 'squabbler', :launch_config => :squabbler_launch_config, :subnets => lookup.get_subnets(vpc), :notification_topic => lookup.get_notification_topic)
end
