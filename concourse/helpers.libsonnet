// Outreach-specific helpers for concourse

{
  appClusters():: [
    {
      name: 'staging.us-east-2',
      environment: 'staging',
      passed: null
    },
    {
      name: 'staging.us-west-2',
      environment: 'staging',
      passed: 'staging.us-east-2'
    },
    {
      name: 'production.us-west-2',
      environment: 'production',
      passed: 'staging.us-west-2'
    },
    {
      name: 'production.us-east-1',
      environment: 'production',
      passed: 'production.us-west-2'
    },
  ],
  infraClusters():: [
    {
      name: 'ops.us-west-2',
      environment: 'production',
      passed: null
    },
  ],
  stagingBentos():: [],
  appBentos():: [
    {
      name: 'app1a',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: null,
      next: 'app1c'
    },
    {
      name: 'app1c',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1a',
      next: 'app1f'
    },
    {
      name: 'app2a',
      cluster: 'production.us-east-1',
      channel: 'green',
      environment: 'production',
      region: 'us-east-1',
      passed: 'app1a',
      next: 'app2b'
    },
    {
      name: 'app2b',
      cluster: 'production.us-east-1',
      channel: 'green',
      environment: 'production',
      region: 'us-east-1',
      passed: 'app2a',
      next: 'app2c'
    },
    {
      name: 'app2c',
      cluster: 'production.us-east-1',
      channel: 'green',
      environment: 'production',
      region: 'us-east-1',
      passed: 'app2b',
      next: null
    },
  ],
}
