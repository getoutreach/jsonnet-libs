// This file contains a helper for creating oauth2-proxy instances.
local ok = import 'kubernetes/kube.libsonnet';
local appImageRegistry = std.extVar('appImageRegistry');

{
  // Container returns an oauth2-proxy corev1.Container (see kube.libsonnet).
  // The container listens on port 8080 and proxies to the service on the
  // provided servicePort.
  Container(
    // serviceName is the name of the service that the oauth2-proxy
    // is proxying. This is used for the cookie name. This is required.
    serviceName=error 'serviceName must be set',

    // servicePort is the port on the service that the oauth2-proxy.
    // This is required.
    //
    // Note: This is different that the service port as the container
    // runs in the same network namespace as the service, this would be
    // whatever port the local service listens on.
    servicePort=error 'servicePort must be set',

    // secret is a corev1.Secret that contains the oauth2-proxy
    // cookie secret. This is required and must contain the following keys:
    //
    // - OAUTH2_PROXY_COOKIE_SECRET: https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/overview#generating-a-cookie-secret
    // - OAUTH2_PROXY_CLIENT_ID: Client ID of your IT provided Okta ODIC app
    // - OAUTH2_PROXY_CLIENT_SECRET: Client Secret of your IT provided Okta ODIC app
    secret=error 'secret must be set',

    // domain is the fully qualified domain name that the oauth2-proxy
    // should use for the cookie domain. This is required.
    domain=error 'domain must be set',

    // listenPort is the port that the oauth2-proxy should listen on.
    listenPort=8080,

    // oidceIssuerURL is the URL of the OIDC issuer.
    oidcIssuerURL='https://outreach.okta.com'
  ):: ok.Container('oauth2-proxy') {
    local this = self,
    // Map to listen_port so we can easily access this in other functions
    listen_port:: listenPort,

    image: '%s/quay.io/oauth2-proxy/oauth2-proxy:v7.5.1' % appImageRegistry,
    args: [
      '--upstream=http://localhost:%d/' % servicePort,
      '--provider=oidc',
      '--cookie-name=%s_oauth2_proxy' % serviceName,
      '--cookie-secure=true',
      '--cookie-expire=168h0m',
      '--cookie-refresh=8h',
      '--cookie-domain=' + domain,
      '--http-address=0.0.0.0:%d' % this.listen_port,
      '--oidc-issuer-url=%s' % oidcIssuerURL,
      '--redirect-url=https://%s/oauth2/callback' % domain,
      '--email-domain=outreach.io',
      '--pass-access-token=true',
      '--pass-user-headers=true',
      '--skip-provider-button=true',
      '--request-logging=false',
      '--silence-ping-logging=true',
    ],
    envFrom: [
      { secretRef: { name: secret.metadata.name } },
    ],
    ports_:: {
      'http-o2p': { containerPort: this.listen_port },
    },
    resources: {
      limits: {
        cpu: '300m',
        memory: '200Mi',
      },
      requests: {
        cpu: '100m',
        memory: '110Mi',
      },
    },
  },

  // ServicePort returns an entry for the oauth2-proxy container to be
  // used in a Service. The only required argument is 'container' which
  // is the oauth2-proxy container created by Container().
  ServicePort(
    // container is the oauth2-proxy container created by Container().
    container=error 'container must be set',

    // port is the port that the oauth2-proxy should use for the service
    // (this is not the container port)
    port=80,
  ):: {
    port: port,
    targetPort: container.listen_port,
    protocol: 'TCP',
    name: 'http-o2p',
  },

  // IngressRule returns an entry for the oauth2-proxy container to be
  // used in an Ingress.
  IngressRule(
    // container is the oauth2-proxy container created by Container().
    container=error 'container must be set',

    // serviceName is the name of the Kubernetes service that the oauth2-proxy
    // is on.
    serviceName=error 'serviceName must be set',
  ):: {
    path: '/*',
    backend: {
      serviceName: serviceName,
      servicePort: 'http-o2p',
    },
  },

  // IngressRuleV1 returns a networking.k8s.io/v1 compatible entry for the oauth2-proxy container to be
  // used in an Ingress.
  IngressRuleV1(
    // container is the oauth2-proxy container created by Container().
    container=error 'container must be set',

    // serviceName is the name of the Kubernetes service that the oauth2-proxy
    // is on.
    serviceName=error 'serviceName must be set',
  ):: {
    path: '/',
    pathType: 'Prefix',
    backend: {
      service: {
        name: serviceName,
        port: {
          name: 'http-o2p',
        },
      },
    },
  },

  // ALBIngressAnnotations returns a set of annotations that are helpful when
  // using the oauth2-proxy with an ALB Ingress Controller.
  ALBIngressAnnotations():: {
    'alb.ingress.kubernetes.io/load-balancer-attributes'+: ',routing.http.preserve_host_header.enabled=true',
    'alb.ingress.kubernetes.io/healthcheck-path': '/ping',
  },
}
