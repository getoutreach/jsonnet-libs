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
}
