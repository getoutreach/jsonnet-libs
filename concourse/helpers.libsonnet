// Outreach-specific helpers for concourse

{
  appClusters: [
    {
      name: 'staging.us-east-2',
      env: 'staging',
      passed: null
    },
    {
      name: 'staging.us-west-2',
      env: 'staging',
      passed: ['Deploy staging.us-east-2']
    },
    {
      name: 'production.us-west-2',
      env: 'production',
      passed: ['Deploy staging.us-west-2']
    },
    {
      name: 'production.us-west-2',
      env: 'production',
      passed: ['Deploy production.us-west-2']
    },
  ],
  appBentos: [
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
      passed: ['Deploy staging1a']
    },
    {
      name: 'app1d',
      cluster: 'production.us-west-2',
      channel: 'orange',
      passed: ['Deploy staging2']
    },
    {
      name: 'app1e',
      cluster: 'production.us-west-2',
      channel: 'amber',
      passed: ['Deploy app1d']
    },
    {
      name: 'app1b',
      cluster: 'production.us-west-2',
      channel: 'yellow',
      passed: ['Deploy app1e']
    },
    {
      name: 'app1a',
      cluster: 'production.us-west-2',
      channel: 'green',
      passed: ['Deploy app1b']
    },
    {
      name: 'app1c',
      cluster: 'production.us-west-2',
      channel: 'green',
      passed: ['Deploy app1a']
    },
    {
      name: 'app1f',
      cluster: 'production.us-west-2',
      channel: 'green',
      passed: ['Deploy app1a']
    },
    {
      name: 'app2a',
      cluster: 'production.us-east-1',
      channel: 'green',
      passed: ['Deploy app1b']
    },
    {
      name: 'app2b',
      cluster: 'production.us-east-1',
      channel: 'green',
      passed: ['Deploy app2a']
    },
  ],
}
