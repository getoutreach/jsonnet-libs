local k = import 'kube.libsonnet';
local kubecfg = import 'kubecfg.libsonnet';

k + kubecfg {
  cluster:: kubecfg.parseYaml(importstr 'clusters.yaml')[0][std.extVar('cluster')] {
    fqdn: '%s.%s.%s.%s' % [self.name, self.region, self.cloud_provider, self.dns_zone],
  },
  ContourIngress(
    name,
    namespace,
    app=name,
    subdomain=name,
    contour='contour',  // which contour instance/subdomain to use
    contourDomain='outreach.cloud',  // which domain contour's dns record lives in
    ingressDomain='outreach.cloud',  // which domain to write dns to
    serviceName=name,
    servicePort='http',
    tlsSecret=null,
    forceDisableTLS=false,
  ): self.Ingress(name, namespace, app=app) {
    local this = self,

    host:: '%s.%s.%s' % [subdomain, $.cluster.name, ingressDomain],

    # in default scenarios, for external ingresses
    # tls will be enabled
    local resolvedTlsSecret = 
      if tlsSecret != null
      then tlsSecret
      else
        if contour == 'contour' then "%s-tls" % name else null,
    local tlsEnabled = if forceDisableTLS || resolvedTlsSecret != null then false else true,
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
      secretName: resolvedTlsSecret,
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
      } + (if tlsEnabled == true then tlsAnnotations else {}),
    },
    spec+: {
      rules: [rule],
      [if tlsEnabled == true then 'tls']: [tls],
    },
  },
}
