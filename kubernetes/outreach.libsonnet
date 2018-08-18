local k = import 'kube.libsonnet';
local kubecfg = import 'kubecfg.libsonnet';

k + kubecfg {
  cluster:: self.parseYaml(importstr 'clusters.yaml')[0][std.extVar('cluster')] {
    fqdn: '%s.%s.%s.%s' % [self.name, self.region, self.cloud_provider, self.dns_zone],
  },
  ContourIngress(
    name,
    namespace,
    app=name,
    contour='contour',  // which contour instance/subdomain to use
    contourDomain='outreach.cloud',  // which domain contour's dns record lives in
    ingressDomain='outreach.cloud',  // which domain to write dns to
    serviceName=name,
    servicePort='http',
    tlsSecret=null,
  ): self.Ingress(name, namespace, app=app) {
    local this = self,

    host:: '%s.%s.%s' % [name, $.cluster.name, ingressDomain],
    local target = '%s.%s.%s' % [contour, $.cluster.name, contourDomain],
    local rule = {
      host: this.host,
      http: {
        paths: [{
          backend: {
            serviceName: serviceName,
            servicePort: servicePort,
          },
        }],
      },
    },
    local tls = {
      hosts: [this.host],
      secretName: tlsSecret,
    },
    local tlsAnnotations = {
      'certmanager.k8s.io/acme-http01-edit-in-place': 'false',
      'ingress.kubernetes.io/force-ssl-redirect': 'true',
      'kubernetes.io/tls-acme': 'true',
    },

    metadata+: {
      annotations+: {
        'external-dns.alpha.kubernetes.io/target': target,
        'kubernetes.io/ingress.class': 'contour',
      } + (if tlsSecret != null then tlsAnnotations else {}),
    },
    spec+: {
      rules: [rule],
      [if tlsSecret != null then 'tls']: [tls],
    },
  },
}
