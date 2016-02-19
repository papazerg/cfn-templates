require 'sparkle_formation'
require_relative '../../../utils/environment'
require_relative '../../../utils/lookup'

ENV['net_type'] ||= 'Private'
ENV['sg']       ||= 'private_sg'
ENV['run_list'] ||= 'role[base],role[couchbase_server]'

lookup = Indigo::CFN::Lookups.new
vpc = lookup.get_vpc

SparkleFormation.new('vanilla_precise').load(:precise_ami, :subnet_names_to_ids, :sg_names_to_ids, :ssh_key_pair, :chef_validator_key_bucket).overrides do
  set!('AWSTemplateFormatVersion', '2010-09-09')
  description <<EOF
Creates a single server.  The instance is given an IAM instance profile, which
allows the instance to get objects from the Chef Validator Key Bucket.

Depends on the VPC template.
EOF
  dynamic!(:iam_instance_profile, 'default', :policy_statements => [ :chef_bucket_access, :modify_route53 ])
  dynamic!(:ec2_instance, 'vanilla', :security_groups => lookup.get_security_group_names(vpc, '*'), :subnets => lookup.get_private_subnet_names(vpc))
end