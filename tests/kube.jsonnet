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

// ServiceMonitor: metrics-port discovery, defaults, and relabelings.
local svc = {
  metadata: { name: 'test', namespace: 'test', labels: {
    name: 'test',
    app: 'test',
    repo: 'test',
    reporting_team: 'fnd-pc',
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
// default scrape-interval label is stamped on the endpoint (spec-level
// metricRelabelings does not exist in the ServiceMonitor CRD)
assert sm.spec.endpoints[0].metricRelabelings == [
  { targetLabel: 'outreach_metric_collection_interval', replacement: '30' },
];
assert !std.objectHas(sm.spec, 'metricRelabelings');
// all Service labels are copied onto the series (not filtered)
assert sm.spec.targetLabels == ['app', 'name', 'repo', 'reporting_team'];
// selector matches only the Service identity, not the full label set
assert sm.spec.selector.matchLabels == { name: 'test' };
// no scrape marker label (TA selector is open; the label only confused readers)
assert !std.objectHas(sm.metadata.labels, 'monitoring.outreach.io/otel-scrape');
assert !std.objectHas(sm.metadata.labels, 'prometheus.io/scrape');

// interval is overridable via the constructor arg and reflected in the stamp
local smInterval = k.ServiceMonitor('test', 'test', interval='60s') { target_service:: svc };
assert smInterval.spec.endpoints[0].interval == '60s';
assert smInterval.spec.endpoints[0].metricRelabelings[0].replacement == '60';

// minute-based intervals convert to whole seconds
local smMinute = k.ServiceMonitor('test', 'test', interval='2m') { target_service:: svc };
assert smMinute.spec.endpoints[0].metricRelabelings[0].replacement == '120';

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
// per-endpoint interval override is reflected in the stamp
assert smSinglePort.spec.endpoints[0].metricRelabelings[0].replacement == '15';

// per-endpoint metricRelabelings pass through via endpoints_, appended after
// the interval stamp.
local smRelabel = k.ServiceMonitor('test', 'test') {
  target_service:: svc,
  spec+: { endpoints_+:: { metrics+: { metricRelabelings: [{ regex: 'team', action: 'drop' }] } } },
};
assert smRelabel.spec.endpoints[0].metricRelabelings == [
  { targetLabel: 'outreach_metric_collection_interval', replacement: '30' },
  { regex: 'team', action: 'drop' },
];

// PodMonitor: metrics-port discovery from container ports, defaults, hooks.
// Stencil-shaped pod: metrics container port is named 'http-prom' (not 'metrics').
local podTmpl = {
  metadata: { labels: { name: 'test', app: 'test', repo: 'test', reporting_team: 'fnd-pc' } },
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
// honorLabels defaults to true
assert pm.spec.podMetricsEndpoints[0].honorLabels == true;
// interval defaults to 30s
assert pm.spec.podMetricsEndpoints[0].interval == '30s';
// default scrape-interval label is stamped on the endpoint (spec-level
// metricRelabelings does not exist in the PodMonitor CRD)
assert pm.spec.podMetricsEndpoints[0].metricRelabelings == [
  { targetLabel: 'outreach_metric_collection_interval', replacement: '30' },
];
assert !std.objectHas(pm.spec, 'metricRelabelings');
// all pod labels are copied onto the series (not filtered)
assert pm.spec.podTargetLabels == ['app', 'name', 'repo', 'reporting_team'];
assert pm.spec.selector.matchLabels == { name: 'test' };
// no scrape marker label (TA selector is open)
assert !std.objectHas(pm.metadata.labels, 'monitoring.outreach.io/otel-scrape');

// interval is overridable via the constructor arg and reflected in the stamp
local pmInterval = k.PodMonitor('test', 'test', interval='60s') { target_pod:: podTmpl };
assert pmInterval.spec.podMetricsEndpoints[0].interval == '60s';
assert pmInterval.spec.podMetricsEndpoints[0].metricRelabelings[0].replacement == '60';

// single-port pod with no metrics-named port falls back to that sole port.
local pmSingle = k.PodMonitor('test', 'test') {
  target_pod:: {
    metadata: { labels: { name: 'test', app: 'test' } },
    spec: { containers: [{ name: 'c', ports: [{ name: 'web', containerPort: 9000 }] }] },
  },
};
assert pmSingle.spec.podMetricsEndpoints[0].port == 'web';

// per-endpoint metricRelabelings pass through via podMetricsEndpoints_,
// appended after the interval stamp.
local pmRelabel = k.PodMonitor('test', 'test') {
  target_pod:: podTmpl,
  spec+: { podMetricsEndpoints_+:: { 'http-prom': { metricRelabelings: [{ regex: 'team', action: 'drop' }] } } },
};
assert pmRelabel.spec.podMetricsEndpoints[0].metricRelabelings == [
  { targetLabel: 'outreach_metric_collection_interval', replacement: '30' },
  { regex: 'team', action: 'drop' },
];

resources
