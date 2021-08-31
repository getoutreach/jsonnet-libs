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
  Engine(version, parameter_group_family): {
        version: version,
        parameter_group_family: parameter_group_family,
  },
  PostgresqlDatabaseCluster(name, app, namespace):  k._Object('databases.outreach.io/v1', 'PostgresqlDatabaseCluster', name, app=app, namespace=namespace) {
    database_name:: error 'database_name is required',
    engine:: error 'engine is required',
    instance_class:: error 'instance_class is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    local this = self,
    spec: {
      name: name,
      database_name: this.database_name,
      instance_class: this.instance_class,
      engine+: this.engine,
      team: this.team,
      tier: this.tier,
      personal_information: this.personal_information
    },
  },
}