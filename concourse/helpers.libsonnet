// Outreach-specific helpers for concourse

{
  appClusters():: [
    {
      name: 'staging.us-east-2',
      env: 'staging',
      passed: null
    },
    {
      name: 'staging.us-west-2',
      env: 'staging',
      passed: 'staging.us-east-2'
    },
    {
      name: 'production.us-west-2',
      env: 'production',
      passed: 'staging.us-west-2'
    },
    {
      name: 'production.us-west-2',
      env: 'production',
      passed: 'production.us-west-2'
    },
  ],
  appBentos():: [
    {
      name: 'staging1a',
      cluster: 'staging.us-east-2',
      channel: 'white',
      passed: null
    },
    {
      name: 'staging2',
      cluster: 'staging.us-west-2',
      channel: 'red',
      passed: 'staging1a'
    },
    {
      name: 'app1d',
      cluster: 'production.us-west-2',
      channel: 'orange',
      passed: 'staging2'
    },
    {
      name: 'app1e',
      cluster: 'production.us-west-2',
      channel: 'amber',
      passed: 'app1d'
    },
    {
      name: 'app1b',
      cluster: 'production.us-west-2',
      channel: 'yellow',
      passed: 'app1e'
    },
    {
      name: 'app1a',
      cluster: 'production.us-west-2',
      channel: 'green',
      passed: 'app1b'
    },
    {
      name: 'app1c',
      cluster: 'production.us-west-2',
      channel: 'green',
      passed: 'app1a'
    },
    {
      name: 'app1f',
      cluster: 'production.us-west-2',
      channel: 'green',
      passed: 'app1a'
    },
    {
      name: 'app2a',
      cluster: 'production.us-east-1',
      channel: 'green',
      passed: 'app1b'
    },
    {
      name: 'app2b',
      cluster: 'production.us-east-1',
      channel: 'green',
      passed: 'app2a'
    },
  ],
}
