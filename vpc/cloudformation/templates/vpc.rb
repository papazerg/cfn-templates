require 'sparkle_formation'
require_relative '../../../utils/environment'
require_relative '../../../utils/lookup'

lookup = Indigo::CFN::Lookups.new
azs = lookup.get_azs

SparkleFormation.new('vpc').load(:vpc_cidr_blocks, :igw, :ssh_key_pair, :nat_ami, :nat_instance_iam).overrides do
  set!('AWSTemplateFormatVersion', '2010-09-09')
  description <<EOF
VPC, including a NAT instance, security groups, and an internal hosted DNS zone.
EOF

  parameters(:allow_ssh_from) do
    type 'String'
    allowed_pattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
    default '127.0.0.1/32'
    description 'Network to allow SSH from, to NAT instances. Note that the default of 127.0.0.1/32 effectively disables SSH access.'
    constraint_description 'Must follow IP/mask notation (e.g. 192.168.1.0/24)'
  end

  parameters(:allow_udp_1194_from) do
    type 'String'
    allowed_pattern "(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})\\.(\\d{1,3})/(\\d{1,2})"
    default '0.0.0.0/0'
    description 'Network to allow UDP port 1194 from, to VPN instances.'
    constraint_description 'Must follow IP/mask notation (e.g. 192.168.1.0/24)'
  end

  dynamic!(:vpc, ENV['vpc_name'])

  public_subnets = Array.new
  azs.each do |az|
    dynamic!(:subnet, "public_#{az}", :az => az, :type => :public)
    public_subnets << "public_#{az}_subnet".gsub('-','_').to_sym
    dynamic!(:subnet, "private_#{az}", :az => az, :type => :private)
  end

  dynamic!(:route53_hosted_zone, "#{ENV['private_domain'].gsub('.','_')}", :vpcs => [ { :id => ref!(:vpc), :region => ref!('AWS::Region') } ] )

  dynamic!(:vpc_security_group, 'nat',
           :ingress_rules => [
             { 'cidr_ip' => ref!(:allow_ssh_from), 'ip_protocol' => 'tcp', 'from_port' => '22', 'to_port' => '22'}
           ],
           :allow_icmp => false
  )

  dynamic!(:vpc_security_group, 'public_elb',
           :ingress_rules => [
             { 'cidr_ip' => '0.0.0.0/0', 'ip_protocol' => 'tcp', 'from_port' => '80', 'to_port' => '80'},
             { 'cidr_ip' => '0.0.0.0/0', 'ip_protocol' => 'tcp', 'from_port' => '443', 'to_port' => '443'}
           ],
          :allow_icmp => false
  )

  dynamic!(:vpc_security_group, 'empire_public', :ingress_rules => [], :allow_icmp => false)

  dynamic!(:vpc_security_group, 'vpn',
           :ingress_rules => [
             { 'cidr_ip' => ref!(:allow_ssh_from), 'ip_protocol' => 'tcp', 'from_port' => '22', 'to_port' => '22'},
             { 'cidr_ip' => ref!(:allow_udp_1194_from), 'ip_protocol' => 'udp', 'from_port' => '1194', 'to_port' => '1194'}
           ],
           :allow_icmp => true
  )

  dynamic!(:vpc_security_group, 'private', :ingress_rules => [])
  dynamic!(:vpc_security_group, 'nginx', :ingress_rules => [])
  dynamic!(:vpc_security_group, 'web', :ingress_rules => [])
  dynamic!(:vpc_security_group, 'empire', :ingress_rules => [])

  # Inbound
  dynamic!(:sg_ingress, 'public-elb-to-nginx-http', :source_sg => :public_elb_sg, :ip_protocol => 'tcp', :from_port => '80', :to_port => '80', :target_sg => :nginx_sg)
  dynamic!(:sg_ingress, 'public-elb-to-nginx-http-8080', :source_sg => :public_elb_sg, :ip_protocol => 'tcp', :from_port => '8080', :to_port => '8080', :target_sg => :nginx_sg)
  dynamic!(:sg_ingress, 'public-elb-to-nginx-https', :source_sg => :public_elb_sg, :ip_protocol => 'tcp', :from_port => '443', :to_port => '443', :target_sg => :nginx_sg)

  dynamic!(:sg_ingress, 'empire-public-to-empire-9000-10000', :source_sg => :empire_public_sg, :ip_protocol => 'tcp', :from_port => '9000', :to_port => '10000', :target_sg => :empire_sg)

  dynamic!(:sg_ingress, 'nginx-to-web-http', :source_sg => :nginx_sg, :ip_protocol => 'tcp', :from_port => '80', :to_port => '80', :target_sg => :web_sg)
  dynamic!(:sg_ingress, 'nginx-to-web-http-alt-8080', :source_sg => :nginx_sg, :ip_protocol => 'tcp', :from_port => '8080', :to_port => '8080', :target_sg => :web_sg)
  dynamic!(:sg_ingress, 'nginx-to-web-http-alt-9080', :source_sg => :nginx_sg, :ip_protocol => 'tcp', :from_port => '9080', :to_port => '9080', :target_sg => :web_sg)
  dynamic!(:sg_ingress, 'nginx-to-empire-http', :source_sg => :nginx_sg, :ip_protocol => 'tcp', :from_port => '80', :to_port => '80', :target_sg => :empire_sg)
  dynamic!(:sg_ingress, 'nginx-to-empire-https', :source_sg => :nginx_sg, :ip_protocol => 'tcp', :from_port => '443', :to_port => '443', :target_sg => :empire_sg)

  dynamic!(:sg_ingress, 'nat-to-nginx-all', :source_sg => :nat_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :nginx_sg)
  dynamic!(:sg_ingress, 'nat-to-web-all', :source_sg => :nat_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :web_sg)
  dynamic!(:sg_ingress, 'nat-to-empire-all', :source_sg => :nat_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :empire_sg)
  dynamic!(:sg_ingress, 'nat-to-private-all', :source_sg => :nat_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :private_sg)

  dynamic!(:sg_ingress, 'vpn-to-nginx-all', :source_sg => :vpn_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :nginx_sg)
  dynamic!(:sg_ingress, 'vpn-to-web-all', :source_sg => :vpn_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :web_sg)
  dynamic!(:sg_ingress, 'vpn-to-empire-all', :source_sg => :vpn_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :empire_sg)
  dynamic!(:sg_ingress, 'vpn-to-private-all', :source_sg => :vpn_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :private_sg)

  dynamic!(:sg_ingress, 'web-to-private-all', :source_sg => :web_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :private_sg)

  dynamic!(:sg_ingress, 'empire-to-private-all', :source_sg => :empire_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :private_sg)

  # Outbound
  dynamic!(:sg_ingress, 'private-to-web-all', :source_sg => :private_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :web_sg)
  dynamic!(:sg_ingress, 'private-to-empire-all', :source_sg => :private_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :empire_sg)
  dynamic!(:sg_ingress, 'private-to-nat-all', :source_sg => :private_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :nat_sg)
  dynamic!(:sg_ingress, 'private-to-vpn-all', :source_sg => :private_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :vpn_sg)

  dynamic!(:sg_ingress, 'web-to-nat-all', :source_sg => :web_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :nat_sg)
  dynamic!(:sg_ingress, 'web-to-vpn-all', :source_sg => :web_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :vpn_sg)

  dynamic!(:sg_ingress, 'empire-to-nat-all', :source_sg => :empire_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :nat_sg)
  dynamic!(:sg_ingress, 'empire-to-vpn-all', :source_sg => :empire_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :vpn_sg)

  dynamic!(:sg_ingress, 'nginx-to-nat-all', :source_sg => :nginx_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :nat_sg)
  dynamic!(:sg_ingress, 'nginx-to-vpn-all', :source_sg => :nginx_sg, :ip_protocol => '-1', :from_port => '-1', :to_port => '-1', :target_sg => :vpn_sg)

  dynamic!(:launch_config, 'nat_instances', :public_ips => true, :instance_id => :nat_instance, :security_groups => [:nat_sg])
  dynamic!(:auto_scaling_group, 'nat_instances', :launch_config => :nat_instances_launch_config, :subnets => public_subnets )
end
