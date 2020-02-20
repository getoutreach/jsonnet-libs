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
      name: 'production.us-west-2',
      environment: 'production',
      passed: 'production.us-west-2'
    },
  ],
  appBentos():: [
    {
      name: 'staging1a',
      cluster: 'staging.us-east-2',
      channel: 'white',
      environment: 'staging',
      region: 'us-east-2',
      passed: null
    },
    {
      name: 'staging2',
      cluster: 'staging.us-west-2',
      channel: 'red',
      environment: 'staging',
      region: 'us-west-2',
      passed: 'staging1a'
    },
    {
      name: 'app1d',
      cluster: 'production.us-west-2',
      channel: 'orange',
      environment: 'production',
      region: 'us-west-2',
      passed: 'staging2'
    },
    {
      name: 'app1e',
      cluster: 'production.us-west-2',
      channel: 'amber',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1d'
    },
    {
      name: 'app1b',
      cluster: 'production.us-west-2',
      channel: 'yellow',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1e'
    },
    {
      name: 'app1a',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1b'
    },
    {
      name: 'app1c',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1a'
    },
    {
      name: 'app1f',
      cluster: 'production.us-west-2',
      channel: 'green',
      environment: 'production',
      region: 'us-west-2',
      passed: 'app1a'
    },
    {
      name: 'app2a',
      cluster: 'production.us-east-1',
      channel: 'green',
      environment: 'production',
      region: 'us-east-1',
      passed: 'app1b'
    },
    {
      name: 'app2b',
      cluster: 'production.us-east-1',
      channel: 'green',
      environment: 'production',
      region: 'us-east-1',
      passed: 'app2a'
    },
  ],
}
