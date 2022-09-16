local k = import 'kubernetes/kube.libsonnet';
local resources = import 'resources.libsonnet';

{
  DatabaseCredential(name, app, namespace): k._Object('databases.outreach.io/v1', 'DatabaseCredential', name, app=app, namespace=namespace) {
    username:: error 'username is required',
    vault:: null,
    auth:: 'mysql',
    local this = self,
    spec: {
      username: this.username,
      grants: this.grants,
      vault: this.vault,
      auth: this.iamauth,
    },
  },
  Grant(privileges, pattern): {
    assert std.length(privileges) > 0 : 'privileges(array of string) is required',
    assert pattern != '' : 'pattern is required',
    privileges: privileges,
    pattern: pattern,
  },
  PostgresqlDatabaseCluster(database_cluster_name, app, namespace, environment=''): k._Object('databases.outreach.io/v1', 'PostgresqlDatabaseCluster', name=database_cluster_name, app=app, namespace=namespace) {
    local this = self,
    // You can find instance class description here:
    // https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
    local defaultStagingInstanceClass = 'db.t4g.medium',
    local defaultProductionInstanceClass = 'db.t4g.medium',
    // instance_class unused in devenv
    local defaultDevInstanceClass = '',
    local isDev = environment == 'development' || environment == 'local_development',
    local isProd = environment == 'production',
    local isStaging = environment == 'staging',

    provisioner:: if isDev then 'SharedDevenv' else 'AuroraRDS',
    bento:: error 'bento is required',
    database_name:: error 'database_name is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    personal_information:: '',
    full_name:: '',
    temp_builtin_users:: false,
    engine:: {
      version: error 'engine.version is required',
      parameter_group_family: error 'engine.parameter_group_family is requied',
    },
    instance_classes:: {
      default: if isDev
      then defaultDevInstanceClass
      else if isProd
      then defaultProductionInstanceClass
      else if isStaging
      then defaultStagingInstanceClass
      else error 'missing instance_classes.default or one of the supported environment values',
    },
    cluster_parameters:: {
      default: [],
    },
    instance_parameters:: {
      default: [],
    },
    metadata+: {
      annotations+: {
        // DPO CR must be created before vault-secret-operator (which has sync wave-value of -5)
        'argocd.argoproj.io/sync-wave': '-6',
      },
    },
    spec: {
      provisioner: this.provisioner,
      bento: this.bento,
      app_name: app,
      full_name: this.full_name,
      name: database_cluster_name,
      database_name: this.database_name,
      engine: this.engine,
      team: this.team,
      tier: this.tier,
      personal_information: this.personal_information,
      temp_builtin_users: this.temp_builtin_users,
      instance_class: if std.objectHas(this.instance_classes, namespace) then this.instance_classes[namespace] else this.instance_classes.default,
      cluster_parameters: if std.objectHas(this.cluster_parameters, namespace) then this.cluster_parameters[namespace] else this.cluster_parameters.default,
      instance_parameters: if std.objectHas(this.instance_parameters, namespace) then this.instance_parameters[namespace] else this.instance_parameters.default,
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
