local k = import 'kubernetes/kube.libsonnet';
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
  PostgresqlDatabaseCluster(database_cluster_name, app, namespace):  k._Object('databases.outreach.io/v1', 'PostgresqlDatabaseCluster', name=database_cluster_name, app=app, namespace=namespace) {
    bento:: error 'bento is required',
    database_name:: error 'database_name is required',
    instance_class:: error 'instance_class is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    personal_information:: "",
    engine:: {
      version: error "engine.version is required",
      parameter_group_family: error "engine.parameter_group_family is requied",
    },
    instance_classes:: {
      default: error "missing instance_classes.default",
    },
    local this = self,
    spec: {
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
  WaitForDatabaseProvisioning(database_cluster_name, namespace):  k._Object('databases.outreach.io/v1', 'PostgresqlDatabaseCluster', name=database_cluster_name, namespace=namespace) {
    task: "Wait for database to deploy",
    local this = self,
    bento:: error 'bento is required',
    config: {
      platform: 'linux',
      image_resource: $.basicResources.task_image + { name:: null },
      inputs: [{ name: 'metadata' }, { name: 'source' }],
      outputs: [],
      run: {
        path: '/bin/bash',
        args: [
          '-c',
          |||
            set -euf -o pipefail
            DATABASECLUSTERNAME=%s
            BENTO=%s
            NAMESPACE=%s
            kubectl wait -n $NAMESPACE postgresqldatabaseclusters.databases.outreach.io/$DATABASECLUSTERNAME --for=condition=Ready
          ||| % [this.database_cluster_name, this.bento, this.namespace],
        ],
      },
    },
  },
}