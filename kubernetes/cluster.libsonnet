local kubecfg = import 'kubecfg.libsonnet';

kubecfg.parseYaml(importstr 'clusters.yaml')[0][std.extVar('cluster')] {
  fqdn: '%s.%s.%s' % [self.global_name, self.cloud_provider, self.dns_zone],
  global_name: if std.objectHas(self, 'stub_name') then self.stub_name else '%s.%s' % [self.environment, self.region],
  cloud_account_id: "1234",
}
