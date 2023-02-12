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
  appBentos():: [],
}
