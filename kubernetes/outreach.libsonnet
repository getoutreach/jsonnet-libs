local k = import 'kube.libsonnet';
local kubecfg = import 'kubecfg.libsonnet';

k + kubecfg {
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
    cluster_info=null,
  ): self.Ingress(name, namespace, app=app) {
    local this = self,
    local cluster = if cluster_info == null then import 'cluster.libsonnet' else cluster_info,
    host:: '%s.%s.%s' % [subdomain, cluster.global_name, ingressDomain],
    local target = '%s.%s.%s' % [contour, cluster.global_name, contourDomain],
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
      'acme.cert-manager.io/http01-edit-in-place': 'false',
      'ingress.kubernetes.io/force-ssl-redirect': 'true',
      'kubernetes.io/tls-acme': 'true',
      'projectcontour.io/tls-minimum-protocol-version': '1.2',
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

  ContourHttpProxy(
    name, 
    namespace
  ): self._Object('projectcontour.io/v1','HTTPProxy', name, namespace=namespace) {
  serviceName_:: error 'serviceName_ is required to map httpProxy to a service',
  fqdn_:: error 'fqdn_ is required',
  tlsPassthrough_:: error 'tlsPassthrough_ is required. Either set true or false.',
  tcpProxyPort_:: error 'tcpProxyPort_ is required',
  routePort_:: error 'routePort_ is required',
  routePrefix_:: error 'routePrefix_ is required',

  local this = self,
    spec: {
      virtualhost: {
        fqdn: this.fqdn_,
        tls: {
          passthrough: this.tlsPassthrough_,
        },
      },
      tcpproxy: {
        services: [
          {
            name: this.serviceName_,
            port: this.tcpProxyPort_,
          },
        ],
      },
      routes: [
        {
          services: [
            {
              name: this.serviceName_,
              port: this.routePort_,
            },
          ],
          conditions: [
            {
              prefix: this.routePrefix_,
            },
          ],
        },
      ],
    },
  },

  ALBIngress(    
    name,
    namespace,
    app=name,
    subdomain=name,
    ingressDomain='outreach.cloud',  // which domain to write dns to
    serviceName=name,
    servicePort='http',
    createTls=false,
    clusterALB=false,
    cluster_info=null,
  ): self.Ingress(name, namespace, app=app) {
    local this = self,
    local cluster = if cluster_info == null then import 'cluster.libsonnet' else cluster_info,
    host:: '%s.%s.%s' % [subdomain, cluster.global_name, ingressDomain],
    local rule = {
      host: this.host,
      http: {
        paths: [ 
          {
            path: '/*',
            backend: {
              serviceName: 'ssl-redirect',
              servicePort: 'use-annotation',
            },
          },
          {
            backend: {
              serviceName: serviceName,
              servicePort: servicePort,
            },
          },
        ],
      },
    },

    // acm-manager ignores tls if there's a secret declared
    local tls = {
      hosts: [this.host],
    },

    local tlsAnnotations = {
      'acm-manager.io/enable': 'true',
    },


    metadata+: {
      annotations+: {
        # ALB ANNOTATIONS
        'kubernetes.io/ingress.class': 'alb',
        'alb.ingress.kubernetes.io/group.name': if clusterALB != false then cluster.global_name else this.host, // IngressGroup feature enables you to group multiple Ingress resources together and use a single ALB
        'alb.ingress.kubernetes.io/tags': 'cost=ingress_alb,outreach:environment=%s,kubernetesCluster=%s,outreach:application=%s,namespace=%s' % [cluster.environment, cluster.fqdn, name, namespace], 
        'alb.ingress.kubernetes.io/listen-ports': '[{"HTTP":80},{"HTTPS":443}]',
        'alb.ingress.kubernetes.io/actions.ssl-redirect': '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}', // Redirect http to https
        'alb.ingress.kubernetes.io/scheme': 'internet-facing',
        'alb.ingress.kubernetes.io/load-balancer-attributes': 'routing.http.drop_invalid_header_fields.enabled=true,access_logs.s3.enabled=true,access_logs.s3.bucket=outreach-aws-lb-controller-logs-%s,access_logs.s3.prefix=%s' % [cluster.region, if clusterALB != false then cluster.global_name else this.host], 
        'alb.ingress.kubernetes.io/success-codes': '200-399',
        'external-dns.alpha.kubernetes.io/hostname': this.host,
      } + (if createTls != false then tlsAnnotations else {})
    },
    spec+: {
      rules: [
        rule
      ],
      [if createTls != false then 'tls']: [tls],
    },
  },
}
