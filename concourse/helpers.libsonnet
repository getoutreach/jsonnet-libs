// Outreach-specific helpers for concourse

{
  appClusters():: [
    {
      name: 'staging.us-east-2',
      environment: 'staging',
      passed: null
    },
    {
      name: 'production.us-west-2',
      environment: 'production',
      passed: 'staging.us-east-2'
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
  stagingBentos():: [
    {
      name: 'staging1a',
      cluster: 'staging.us-east-2',
      channel: 'white',
      environment: 'staging',
      region: 'us-east-2',
      passed: null
    },
  ],
  appBentos():: [
    {
      name: 'staging1a',
      cluster: 'staging.us-east-2',
      channel: 'white',
      environment: 'staging',
      region: 'us-east-2',
      passed: null,
      next: 'app1d'
    },
    {
      name: 'app1d',
      cluster: 'production.us-west-2',
      channel: 'orange',
      environment: 'production',
      region: 'us-west-2',
      passed: 'staging1a',
      next: 'app1b'
    },
    {
      name: 'app1b',
      cluster: 'production.us-west-2',
      channel: 'yellow',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1d',
      next: 'app1e'
    },
    {
      name: 'app1e',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1b',
      next: 'app1a'
    },
    {
      name: 'app1a',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1e',
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
      name: 'app1f',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1a',
      next: 'app2a'
    },
    {
      name: 'app2a',
      cluster: 'production.us-east-1',
      channel: 'green',
      environment: 'production',
      region: 'us-east-1',
      passed: 'app1b',
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
