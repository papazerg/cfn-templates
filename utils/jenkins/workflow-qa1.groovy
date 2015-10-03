def workflow_env = 'qa1'

def build_step(step, params) {
  build job: step,
  parameters: [
    [
      $class: 'TextParameterValue', name: 'environment', value: workflow_env
    ],
    [
      $class: 'TextParameterValue', name: 'region', value: workflow_aws_region
    ],
    [
      $class: 'CredentialsParameterValue', description: '', name: 'workflow_aws_access_key_id', value: workflow_aws_access_key_id
    ],
    [
      $class: 'CredentialsParameterValue', description: '', name: 'workflow_aws_secret_access_key', value: workflow_aws_secret_access_key
    ],
    params
  ]
}

build_step('100-launch-vpc', [[$class: "StringParameterValue", name: "allow_ssh", value: '207.250.246.0/24']])
parallel first: {
  build_step('110-launch-nexus-rds', [[$class: 'TextParameterValue', name: 'instance_type', value: 'db.t2.micro']])
}, second: {
  try {
    build_step ('210-launch-vpn', [[$class: 'TextParameterValue', name: 'instance_type', value: 't2.micro']])
  } catch (Exception e) {
    echo 'Whoops.  Launching the vpn failed: ' + e
  }
}