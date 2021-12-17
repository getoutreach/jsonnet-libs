local k = import 'kubernetes/kube.libsonnet';
local resources = import 'resources.libsonnet';

{
  DatabaseCredential(name, app, namespace): k._Object('databases.outreach.io/v1', 'DatabaseCredential', name, app=app, namespace=namespace) {
    username:: error 'username is required',
    local this = self,
    spec: {
      username: this.username,
      grants: this.grants,
      vault: this.vault,
    },
  },
  Grant(privileges, pattern): { 
    assert std.length(privileges) > 0: 'privileges(array of string) is required',
    assert  pattern != "": 'pattern is required',
    privileges: privileges,
    pattern: pattern,
  },
  PostgresqlDatabaseCluster(database_cluster_name, app, namespace, environment=''):  k._Object('databases.outreach.io/v1', 'PostgresqlDatabaseCluster', name=database_cluster_name, app=app, namespace=namespace) {
    local this = self,
    defaultStagingInstanceClass:: 'db.t4g.medium',
    defaultProductionInstanceClass:: 'db.t4g.medium',
    isDev:: environment == 'development' || environment == 'local_development',
    isProd:: environment == 'production',
    isStaging: environment == 'staging',

    provisioner::  if this.isDev then 'SharedDevenv' else 'AuroraRDS',
    bento:: error 'bento is required',
    database_name:: error 'database_name is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    personal_information:: "",
    engine:: {
      version: error "engine.version is required",
      parameter_group_family: error "engine.parameter_group_family is requied",
    },
    instance_classes:: {
      default: if this.isDev 
        then '' 
        else
          if this.isProd 
          then defaultProductionInstanceClass 
          else if this.isStaging
            then defaultStagingInstanceClass
            else error 'missing instance_class or one of the supported environment values',
    },
    spec: {
      provisioner: this.provisioner,
      bento: this.bento,
      name: database_cluster_name,
      database_name: this.database_name,
      engine: this.engine,
      team: this.team,
      tier: this.tier,
      personal_information: this.personal_information,
      instance_class: if std.objectHas(this.instance_classes, namespace) then this.instance_classes[namespace] else this.instance_classes['default'],
    },
  },
  WaitForDatabaseProvisioning(database_cluster_name, app, namespace):: {
    task: 'Wait for database to deploy',
    local this = self,
    kubernetes_cluster_name:: error 'k8 cluster name is required',
    gcr_registry_username:: '((gcr-service-account-username))',
    gcr_registry_password:: '((gcr-service-account-password))',

    config: {
      platform: 'linux',
      image_resource: {
        name: 'kubectl_task_image',
        type: 'registry-image',
        source: {
          repository: 'gcr.io/outreach-docker/alpine/tools',
          tag: 'latest',
          username: this.gcr_registry_username,
          password: this.gcr_registry_password,
        },
      },
      inputs: [{ name: 'metadata' }, { name: 'source' }, { name: 'kubeconfig' }],
      outputs: [],
      run: {
        path: '/bin/bash',
        args: [
          '-c',
          |||
            set -euf -o pipefail
            DATABASECLUSTERNAME=%s
            K8SCLUSTER=%s
            NAMESPACE=%s
            echo kubectl --kubeconfig ./kubeconfig/config --context $K8SCLUSTER wait -n $NAMESPACE postgresqldatabaseclusters.databases.outreach.io/$DATABASECLUSTERNAME --for=condition=Ready --timeout=1800s
            kubectl --kubeconfig ./kubeconfig/config --context $K8SCLUSTER wait -n $NAMESPACE postgresqldatabaseclusters.databases.outreach.io/$DATABASECLUSTERNAME --for=condition=Ready --timeout=1800s
          ||| % [database_cluster_name, this.kubernetes_cluster_name, namespace],
        ],
      },
    },
  },
}
