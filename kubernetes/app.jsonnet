// Standard variables available to all deployments via
// Concourse or ArgoCD
{
  // namespaces is the Kubernetes namespace this application should deploy into.
  //
  // Note: This should generally always be plumbed into namespaced resources
  // as empty namespaces may be deployed into `default` instead of the namespace
  // set here, which is not desired behaviour.
  namespace: std.extVar('namespace'),
  
  // environment is the environment of the bento that this application is being deployed into
  environment: std.extVar('environment'),
  
  // bento is the bento (cell) that this application is being deployed into
  bento: std.extVar('bento'),
  
  // cluster is the Kubernetes cluster this application is being deployed into
  cluster: std.extVar('cluster'),
  
  // channel is the channel of the bento this application is being deployed to
  channel: std.extVar('channel'),
  
  // version is the version of this application being deployed
  version: std.extVar('version'),
  
  // ts is when this application is being deployed as a timestamp.
  ts: std.extVar('ts')
}
