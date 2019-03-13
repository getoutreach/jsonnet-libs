local kubecfg = import 'kubecfg.libsonnet';

kubecfg.parseYaml(importstr 'clusters.yaml')[0][std.extVar('cluster')] {
  fqdn: '%s.%s.%s' % [self.global_name, self.cloud_provider, self.dns_zone],
  global_name: '%s.%s' % [self.environment, self.region],
}
