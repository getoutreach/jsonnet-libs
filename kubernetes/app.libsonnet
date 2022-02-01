// Standard variables available to all deployments via
// Concourse or ArgoCD
local stdfields = {
  // name is the name of this application
  // it is set by fields(name)
  name: '',

  // namespace is the Kubernetes namespace this application should deploy into.
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

  // region is the region of the bento this applicdation is being deployed to
  region: std.extVar('region'),
  
  // version is the version of this application being deployed
  version: std.extVar('version'),

  // ts is when this application is being deployed as a timestamp.
  ts: std.extVar('ts'),
};


{
  // info returns the std fields with name set
  info(name):: stdfields { name: name },
}
