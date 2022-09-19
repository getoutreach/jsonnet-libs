local kubecfg = import 'kubecfg.libsonnet';

kubecfg.parseYaml(importstr 'aws-caller-identity.yaml'){
  account_id: self.account_id
}
