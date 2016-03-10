require 'sparkle_formation'
require_relative '../../../utils/environment'
require_relative '../../../utils/lookup'

ENV['lb_purpose'] ||= 'webserver_elb'
ENV['lb_name']    ||= "#{ENV['org']}-#{ENV['environment']}-web-elb"
ENV['net_type']   ||= 'Private'
ENV['sg']         ||= 'web_sg'
ENV['run_list']   ||= 'role[base],role[webserver]'

lookup = Indigo::CFN::Lookups.new
vpc = lookup.get_vpc

SparkleFormation.new('webserver').load(:precise_ruby22_ami, :ssh_key_pair, :chef_validator_key_bucket).overrides do
  set!('AWSTemplateFormatVersion', '2010-09-09')
  description <<EOF
Creates an auto scaling group containing webserver instances.  Each instance is given an IAM instance
profile, which allows the instance to get objects from the Chef Validator Key Bucket.

Run this template while running the compute, reporter and custom_reporter templates.  Depends on the rabbitmq
and databases templates.
EOF

  parameters(:load_balancer_purpose) do
    type 'String'
    allowed_pattern "[\\x20-\\x7E]*"
    default ENV['lb_purpose'] || 'none'
    description 'Load Balancer Purpose tag to match, to associate webserver instances.'
    constraint_description 'can only contain ASCII characters'
  end

  dynamic!(:elb, 'webserver',
           :listeners => [
               { :instance_port => '80', :instance_protocol => 'http', :load_balancer_port => '80', :protocol => 'http' }
           ],
           :security_groups => lookup.get_security_group_ids(vpc),
           :subnets => lookup.get_subnets(vpc),
           :lb_name => ENV['lb_name'],
           :idle_timeout => '600',
           :scheme => 'internal'
  )

  dynamic!(:iam_instance_profile, 'default', :policy_statements => [ :chef_bucket_access, :modify_elbs, :cloudfront_access, { :assets_bucket_access => { :bucket => 'AssetsS3Bucket'} } ])

  dynamic!(:launch_config_chef_bootstrap, 'webserver', :instance_type => 'm3.medium', :create_ebs_volumes => false, :security_groups => lookup.get_security_group_ids(vpc), :chef_run_list => ENV['run_list'])
  dynamic!(:auto_scaling_group, 'webserver', :launch_config => :webserver_launch_config, :subnets => lookup.get_subnets(vpc), :load_balancers => [ ref!('WebserverElb') ], :notification_topic => lookup.get_notification_topic)

  dynamic!(:route53_record_set, 'webserver_elb', :record => 'webserver', :target => :webserver_elb, :domain_name => ENV['private_domain'], :attr => 'DNSName', :ttl => '60')

  dynamic!(:s3_bucket, 'assets', :acl => 'PublicRead')
  dynamic!(:s3_owner_write_bucket_policy, 'assets', :bucket => 'AssetsS3Bucket')
  dynamic!(:cloudfront_distribution, 'assets', :bucket => 'AssetsS3Bucket', :origin => "vanilla.#{ENV['public_domain']}")
end
