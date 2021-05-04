local k = import 'kubernetes/kube.libsonnet';
{
  DatabaseCredential(name, app, namespace): k._Object('databases.outreach.io/v1', 'DatabaseCredential', name=name, app=app, namespace=namespace) {
    username:: error 'username is required',
    local this = self,
    spec: {
      username: this.username,
      grants: this.grants,
      vault: {
        prefix: this.vault.prefix,
        usernameKey: this.vault.usernameKey,
        passwordKey: this.vault.passwordKey,
      },
    },
  },
  Grant(privilege, pattern): { 
    assert privilege != "": 'privilege is required',
    assert  pattern != "": 'pattern is required',
    privilege: privilege,
    pattern: pattern,
  },
}
