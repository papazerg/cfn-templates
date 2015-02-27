require 'fog'
require 'sparkle_formation'

ENV['region'] ||= 'us-east-1'
ENV['vpc'] ||= 'MyVPC'
ENV['net_type'] ||= 'Private'
ENV['sg'] ||= 'private_sg' # TODO: fix the security group names in the VPC template

# Find subnets and security groups by VPC membership and network type.  These subnets
# and security groups will be passed into the ASG and launch config (respectively) so
# that the ASG knows where to launch instances.

def extract(response)
  response.body if response.status == 200
end

connection = Fog::Compute.new({ :provider => 'AWS', :region => ENV['region'] })

vpcs = extract(connection.describe_vpcs)['vpcSet']
vpc = vpcs.find { |vpc| vpc['tagSet'].fetch('Name', nil) == ENV['vpc']}['vpcId']

subnets = extract(connection.describe_subnets)['subnetSet']
subnets.collect! { |sn| sn['subnetId'] if sn['tagSet'].fetch('Network', nil) == ENV['net_type'] and sn['vpcId'] == vpc }.compact!

sgs = extract(connection.describe_security_groups)['securityGroupInfo']
sgs.collect! { |sg| sg['groupId'] if sg['tagSet'].fetch('Name', nil) == ENV['sg'] and sg['vpcId'] == vpc }.compact!

# TODO: You can automatically discover SNS topics.  I wonder if you can tag them?
sns = Fog::AWS::SNS.new
topics = extract(sns.list_topics)['Topics']
topic = topics.find { |e| e =~ /byebye/ }

# Build the template.

SparkleFormation.new('databases').load(:cfn_user, :chef_validator_key_bucket, :precise_ami, :ssh_key_pair, :iam_instance_policy, :iam_instance_role, :iam_instance_profile).overrides do
  set!('AWSTemplateFormatVersion', '2010-09-09')
  description <<EOF
This template creates an Auto Scaling Group in one AWS region.  The Auto Scaling Group
consists of three Ubuntu Precise (12.04.5) instances, each with a collection of EBS volumes
for persistent database storage.  The Launch Configuration for the ASG will run Chef client
on each instance.  Each instance will be launched in a private subnet in a VPC.

In addition to the Auto Scaling Group, this template will create an SNS notification topic
that covers instance termination, so that terminated instances can be automatically
deregistered from Chef and New Relic.

Finally, this template will associate an IAM instance profile to each instance, allowing
each instance to create snapshots of its own volumes using an IAM role.
EOF

  dynamic!(:launch_config_chef_bootstrap, 'database', :instance_type => 't2.small', :create_ebs_volumes => true, :volume_count => 4, :volume_size => 10, :security_groups => sgs)
  dynamic!(:auto_scaling_group, 'database', :launch_config => :database_launch_config, :subnets => subnets, :notification_topic => topic)
end