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

// ServiceMonitor: metrics-port discovery, defaults, and central metric relabelings.
local svc = {
  metadata: { name: 'test', namespace: 'test', labels: {
    name: 'test', app: 'test', repo: 'test', reporting_team: 'fnd-pc',
  } },
  spec: { ports: [
    { name: 'grpc', port: 5000, targetPort: 'grpc' },
    // targetPort 'metrics' with a name that sorts after it: exercises the
    // std.member fix (std.setMember misdetected this as absent).
    { name: 'zzz', port: 8000, targetPort: 'metrics' },
  ] },
};

local sm = k.ServiceMonitor('test', 'test') { target_service:: svc };
assert std.length(sm.spec.endpoints) == 1;
// port discovered by targetPort == 'metrics' regardless of name ordering
assert sm.spec.endpoints[0].targetPort == 'metrics';
// honorLabels defaults to true
assert sm.spec.endpoints[0].honorLabels == true;
// interval defaults to 30s
assert sm.spec.endpoints[0].interval == '30s';
// no relabelings by default -> key omitted (clean output)
assert !std.objectHas(sm.spec.endpoints[0], 'metricRelabelings');
// all Service labels are copied onto the series (not filtered)
assert sm.spec.targetLabels == ['app', 'name', 'repo', 'reporting_team'];
// selector matches only the Service identity, not the full label set
assert sm.spec.selector.matchLabels == { name: 'test' };
// no scrape marker label (TA selector is open; the label only confused readers)
assert !std.objectHas(sm.metadata.labels, 'monitoring.outreach.io/otel-scrape');
assert !std.objectHas(sm.metadata.labels, 'prometheus.io/scrape');

// interval is overridable via the constructor arg
local smInterval = k.ServiceMonitor('test', 'test', interval='60s') { target_service:: svc };
assert smInterval.spec.endpoints[0].interval == '60s';

// single-port service with no 'metrics' port falls back to that sole port
// (apps serving /metrics on their only port, e.g. via endpoints_ override).
local svcSinglePort = {
  metadata: { name: 'test', namespace: 'test', labels: { name: 'test', app: 'test' } },
  spec: { ports: [{ name: 'http', port: 8000, targetPort: 'http' }] },
};
local smSinglePort = k.ServiceMonitor('test', 'test') {
  target_service:: svcSinglePort,
  spec+: { endpoints_+:: { http+: { interval: '15s' } } },
};
assert std.length(smSinglePort.spec.endpoints) == 1;
assert smSinglePort.spec.endpoints[0].targetPort == 'http';
assert smSinglePort.spec.endpoints[0].interval == '15s';

// central rules run last; caller rules (via endpoints_) run first.
local smRelabel = k.ServiceMonitor('test', 'test') {
  target_service:: svc,
  centralMetricRelabelings:: [{ regex: 'central', action: 'drop' }],
  spec+: { endpoints_:: { metrics: { metricRelabelings: [{ regex: 'team', action: 'keep' }] } } },
};
assert smRelabel.spec.endpoints[0].metricRelabelings == [
  { regex: 'team', action: 'keep' },
  { regex: 'central', action: 'drop' },
];

resources
