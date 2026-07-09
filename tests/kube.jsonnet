local k = import '../kubernetes/kube.libsonnet';

local resources = { deployment: k.Deployment('test', 'test') {
  spec+: {
    template+: {
      spec+: {
        containers_:: {
          default: {},
          test: {
            image: 'test',
            envFrom: [
              { configMapRef: { name: 'test' } },
            ],
            ports: [
              {
                containerPort: 80,
              },
            ],
          },
        },
      },
    },
  },
} } + k.addEnvFromSecret(secretName='secret', key='deployment', container_name='test');


assert std.length(resources.deployment.spec.template.spec.containers_.test.envFrom) == 2;
assert std.objectHas(resources.deployment.spec.template.spec.containers_.test.envFrom[1], 'secretRef');
assert resources.deployment.spec.template.spec.containers_.test.envFrom[1].secretRef == { name: 'secret' };

// PodMonitor: metrics-port discovery from container ports, defaults, hooks.
// Stencil-shaped pod: metrics container port is named 'http-prom' (not 'metrics').
local podTmpl = {
  metadata: { labels: { name: 'test', app: 'test' } },
  spec: { containers: [{ name: 'default', ports: [
    { name: 'grpc', containerPort: 5000 },
    { name: 'http-prom', containerPort: 8000 },
    { name: 'http', containerPort: 8080 },
  ] }] },
};
local pm = k.PodMonitor('test', 'test') { target_pod:: podTmpl };
assert std.length(pm.spec.podMetricsEndpoints) == 1;
// 'http-prom' discovered even though no port is named 'metrics'
assert pm.spec.podMetricsEndpoints[0].port == 'http-prom';
assert pm.spec.podMetricsEndpoints[0].honorLabels == false;
assert !std.objectHas(pm.spec.podMetricsEndpoints[0], 'metricRelabelings');
assert pm.spec.podTargetLabels == ['app'];
assert pm.spec.selector.matchLabels == { name: 'test' };
assert pm.metadata.labels['monitoring.outreach.io/otel-scrape'] == 'true';

// single-port pod with no metrics-named port falls back to that sole port.
local pmSingle = k.PodMonitor('test', 'test') {
  target_pod:: { metadata: { labels: { name: 'test', app: 'test' } },
                 spec: { containers: [{ name: 'c', ports: [{ name: 'web', containerPort: 9000 }] }] } },
};
assert pmSingle.spec.podMetricsEndpoints[0].port == 'web';

// central rules run last; caller rules (via podMetricsEndpoints_) run first.
local pmRelabel = k.PodMonitor('test', 'test') {
  target_pod:: podTmpl,
  centralMetricRelabelings:: [{ regex: 'central', action: 'labeldrop' }],
  spec+: { podMetricsEndpoints_+:: { 'http-prom': { metricRelabelings: [{ regex: 'team', action: 'keep' }] } } },
};
assert pmRelabel.spec.podMetricsEndpoints[0].metricRelabelings == [
  { regex: 'team', action: 'keep' },
  { regex: 'central', action: 'labeldrop' },
];

resources
