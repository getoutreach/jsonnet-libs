local k = import 'kubernetes/kube.libsonnet';

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
      auth: this.auth,
    },
  },
  Grant(privileges, pattern): {
    assert std.length(privileges) > 0 : 'privileges(array of string) is required',
    assert pattern != '' : 'pattern is required',
    privileges: privileges,
    pattern: pattern,
  },
  // PostgresqlClusterServiceAssignment is used to provision the resources for a service to be able to connect to a database cluster.
  PostgresqlClusterServiceAssignment(
    // name is the name of this k8s resource
    name,
    // app is the name of the application which needs to access the database cluster
    app,
    // namespace is the k8s namespace where this PostgresqlClusterServiceAssignment should be declared
    namespace,
  ): k._Object(
    'databases.outreach.io/v1',
    'PostgresqlClusterServiceAssignment',
    name,
    app=app,
    namespace=namespace,
  ) {
    local this = self,
    // bento is the bento which contains the database cluster and application
    bento:: error 'bento is required',
    // database_name is the name of the database to create within the postgresql cluster. Schemas for the application will be created in the provided datatabase. See https://www.postgresql.org/docs/current/ddl-schemas.html
    database_name:: error 'database_name is required',
    // database_cluster_name is the k8s resource name of the PostgresqlDatabaseCluster
    database_cluster_name:: error 'database_cluster_name is required',
    // database_cluster_namespace is the k8s namespace where the PostgresqlDatabaseCluster is declared.
    database_cluster_namespace:: error 'database_cluster_namespace is required',
    // resource_name is the name for the resource declared by the service
    resource_name:: this.database_name,
    // resource attribution tags (team, tier, personal_information)
    // https://outreach-io.atlassian.net/wiki/spaces/COR/pages/2173993240/Resource+Tagging+Standards+COR
    team:: error 'team is required',
    tier:: error 'tier is required',
    personal_information:: error 'personal_information is required',
    spec: std.prune({
      application_name: app,
      postgresql_database_cluster: {
        namespace: this.database_cluster_namespace,
        resource_name: this.database_cluster_name,
      },
      database_name: this.database_name,
      resource_name: this.resource_name,
      bento: this.bento,
      team: this.team,
      tier: this.tier,
      personal_information: this.personal_information,
    }),
  },
  PostgresqlDatabaseCluster(database_cluster_name, app, namespace, environment=''): k._Object('databases.outreach.io/v1', 'PostgresqlDatabaseCluster', name=database_cluster_name, app=app, namespace=namespace) {
    local this = self,
    // You can find instance class description here:
    // https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
    local defaultStagingInstanceClass = 'db.t4g.medium',
    local defaultProductionInstanceClass = 'db.t4g.medium',
    local defaultOpsInstanceClass = 'db.t4g.medium',
    // instance_class unused in devenv
    local defaultDevInstanceClass = '',
    local isDev = environment == 'development' || environment == 'local_development',
    local isProd = environment == 'production',
    local isOps = environment == 'ops',
    local isStaging = environment == 'staging',
    provisioner:: if isDev then 'SharedDevenv' else 'AuroraRDS',
    bento:: error 'bento is required',
    database_name:: error 'database_name is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    personal_information:: '',
    full_name:: '',
    temp_builtin_users:: null,
    engine:: {
      version: error 'engine.version is required',
      parameter_group_family: error 'engine.parameter_group_family is required',
    },
    instance_classes:: {
      default: if isDev
      then defaultDevInstanceClass
      else if isOps
      then defaultOpsInstanceClass
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
    io_optimized_storage:: null,
    metadata+: {
      annotations+: {
        // DPO CR must be created before vault-secret-operator (which has sync wave-value of -5)
        'argocd.argoproj.io/sync-wave': '-6',
      },
    },
    spec: std.prune({
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
      io_optimized_storage: if std.objectHas(this, 'io_optimized_storage') then this.io_optimized_storage else null,
      cluster_parameters: if std.objectHas(this.cluster_parameters, namespace) then this.cluster_parameters[namespace] else this.cluster_parameters.default,
      instance_parameters: if std.objectHas(this.instance_parameters, namespace) then this.instance_parameters[namespace] else this.instance_parameters.default,
      instance_class: if std.objectHas(this.instance_classes, namespace) then this.instance_classes[namespace] else this.instance_classes.default,
    }),
  },
}
