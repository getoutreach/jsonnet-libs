local k = import 'kubernetes/kube.libsonnet';
{
  DatabaseCredential(name, app, namespace): k._Object('databases.outreach.io/v1', 'DatabaseCredential', name, app=app, namespace=namespace) {
    username:: error 'username is required',
    local this = self,
    spec: {
      username: this.username,
      grants: this.grants,
    },
  },
  Grant(privilege, pattern): { 
    assert privilege != "": 'privilege is required',
    assert  pattern != "": 'pattern is required',
    privilege: privilege,
    pattern: pattern,
  },
}
