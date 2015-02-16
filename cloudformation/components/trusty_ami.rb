SparkleFormation.build do

  parameters(:instance_type) do
    type 'String'
    allowed_values ['c3.large',
                    'c3.xlarge',
                    'c3.2xlarge',
                    'c3.4xlarge',
                    'c3.8xlarge',
                    'c4.large',
                    'c4.xlarge',
                    'c4.2xlarge',
                    'c4.4xlarge',
                    'c4.8xlarge',
                    'i2.xlarge',
                    'i2.2xlarge',
                    'i2.4xlarge',
                    'i2.8xlarge',
                    'm3.medium',
                    'm3.large',
                    'm3.xlarge',
                    'm3.2xlarge',
                    'r3.large',
                    'r3.xlarge',
                    'r3.2xlarge',
                    'r3.4xlarge',
                    'r3.8xlarge',
                    't2.micro',
                    't2.small',
                    't2.medium'
                   ]
    default 't2.medium'
  end

  mappings.region_to_ami do
    _camel_keys_set(:auto_disable) # set! is capitalizing the first letter of each region name
    set!('us-east-1', :ami => 'ami-02f8b16a') # Release 20150209.1
    set!('us-west-1', :ami => 'ami-049d8641')
    set!('us-west-2', :ami => 'ami-870a2fb7')
    set!('eu-west-1', :ami => 'ami-73f97204')
    set!('eu-central-1', :ami => 'ami-ac83b0b1')
  end

end
