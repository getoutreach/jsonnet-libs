// Generic library of Kubernetes objects
//
// Objects in this file follow the regular Kubernetes API object
// schema with two exceptions:
//
// ## Optional helpers
//
// A few objects have defaults or additional "helper" hidden
// (double-colon) fields that will help with common situations.  For
// example, `Service.target_pod` generates suitable `selector` and
// `ports` blocks for the common case of a single-pod/single-port
// service.  If for some reason you don't want the helper, just
// provide explicit values for the regular Kubernetes fields that the
// helper *would* have generated, and the helper logic will be
// ignored.
//
// ## The Underscore Convention:
//
// Various constructs in the Kubernetes API use JSON arrays to
// represent unordered sets or named key/value maps.  This is
// particularly annoying with jsonnet since we want to use jsonnet's
// powerful object merge operation with these constructs.
//
// To combat this, this library attempts to provide more "jsonnet
// native" variants of these arrays in alternative hidden fields that
// end with an underscore.  For example, the `env_` block in
// `Container`:
// ```
// kube.Container("foo") {
//   env_: { FOO: "bar" },
// }
// ```
// ... produces the expected `container.env` JSON array:
// ```
// {
//   "env": [
//     { "name": "FOO", "value": "bar" }
//   ]
// }
// ```
//
// If you are confused by the underscore versions, or don't want them
// in your situation then just ignore them and set the regular
// non-underscore field as usual.
//
//
// ## TODO
//
// TODO: Expand this to include all API objects.
//
// Should probably fill out all the defaults here too, so jsonnet can
// reference them.  In addition, jsonnet validation is more useful
// (client-side, and gives better line information).

// These are passed in as part of the pipeline
local environment = std.extVar('environment');
{
  // Returns array of values from given object.  Does not include hidden fields.
  objectValues(o):: [o[field] for field in std.objectFields(o)],

  // Returns array of [key, value] pairs from given object.  Does not include hidden fields.
  objectItems(o):: [[k, o[k]] for k in std.objectFields(o)],

  // Returns true if a value is not equal to null
  isNotNull(v):: v != null,

  // Replace all occurrences of `_` with `-`.
  hyphenate(s):: std.join('-', std.split(s, '_')),

  // Convert {foo: {a: b}} to [{name: foo, a: b}]
  mapToNamedList(o):: [{ name: $.hyphenate(n) } + o[n] for n in std.objectFields(o)],

  envList(map):: [
    if std.type(map[x]) == 'object' then { name: x, valueFrom: map[x] } else { name: x, value: map[x] }
    for x in std.objectFields(map)
  ],

  // Convert from SI unit suffixes to regular number
  siToNum(n):: (
    local convert =
      if std.endsWith(n, 'm') then [1, 0.001]
      else if std.endsWith(n, 'K') then [1, 1e3]
      else if std.endsWith(n, 'M') then [1, 1e6]
      else if std.endsWith(n, 'G') then [1, 1e9]
      else if std.endsWith(n, 'T') then [1, 1e12]
      else if std.endsWith(n, 'P') then [1, 1e15]
      else if std.endsWith(n, 'E') then [1, 1e18]
      else if std.endsWith(n, 'Ki') then [2, std.pow(2, 10)]
      else if std.endsWith(n, 'Mi') then [2, std.pow(2, 20)]
      else if std.endsWith(n, 'Gi') then [2, std.pow(2, 30)]
      else if std.endsWith(n, 'Ti') then [2, std.pow(2, 40)]
      else if std.endsWith(n, 'Pi') then [2, std.pow(2, 50)]
      else if std.endsWith(n, 'Ei') then [2, std.pow(2, 60)]
      else error 'Unknown numerical suffix in ' + n;
    local n_len = std.length(n);
    std.parseInt(std.substr(n, 0, n_len - convert[0])) * convert[1]
  ),

  _Object(apiVersion, kind, name, app=null, namespace=null):: {
    apiVersion: apiVersion,
    kind: kind,
    metadata: {
      annotations: {},
      labels: {
        name: name,
        [if app != null then 'app']: app,
        [if app != null && namespace == 'kube-system' then 'k8s-app']: app,
        // avoid label duplicates as in https://github.com/DataDog/datadog-agent/issues/2671
        // this line below ensures kube-state-metrics does not have 'app' label, but 'k8s-app' instead
        // if left with 'app' it will collide with labels gathered from kubernetes_state DD integration
        // COR-5785
        [if app != null && name == 'kube-state-metrics' then 'k8s-app']: app,
      },
      name: name,
      [if namespace != null then 'namespace']: namespace,
    },
  },

  CRD(kind, group, version):: (
    local names = {
      kind: kind,
      listKind: (kind + 'List'),
      plural: self.singular + 's',
      singular: std.asciiLower(kind),
      full:: self.plural + '.' + group,
    };
    $._Object('apiextensions.k8s.io/v1beta1', 'CustomResourceDefinition', names.full) {
      spec: {
        group: group,
        names: names,
        version: version,
      },
    }
  ),

  CRDv1(kind, group, apiVersion='apiextensions.k8s.io/v1', resourceVersions=['v1']):: (
    local names = {
      kind: kind,
      listKind: (kind + 'List'),
      plural: self.singular + 's',
      singular: std.asciiLower(kind),
      full:: self.plural + '.' + group,
    };
    $._Object(apiVersion, 'CustomResourceDefinition', names.full) {
      spec: {
        group: group,
        names: names,
        versions: resourceVersions,
      },
    }
  ),

  List(): {
    apiVersion: 'v1',
    kind: 'List',
    items_:: {},
    items: $.objectValues(self.items_),
  },

  // FilteredList is the same as List(), but it removes null from the array
  FilteredList(): {
    apiVersion: 'v1',
    kind: 'List',
    items_:: {},
    items: std.filter($.isNotNull, $.objectValues(self.items_)),
  },

  Namespace(name, istioAmbientMesh=false): $._Object('v1', 'Namespace', name,) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': '-10',
      },
      labels+: {
        [if istioAmbientMesh && environment == 'staging' then 'istio.io/dataplane-mode']: 'ambient',
      },
    },
  },

  Endpoints(name): $._Object('v1', 'Endpoints', name) {
    Ip(addr):: { ip: addr },
    Port(p):: { port: p },

    subsets: [],
  },

  Service(name, namespace, app=name):
    $._Object('v1', 'Service', name, app=app, namespace=namespace) {
      local service = self,

      target_pod:: error 'service target_pod required',
      port:: self.target_pod.spec.containers[0].ports[0].containerPort,

      // Helpers that format host:port in various ways
      http_url:: 'http://%s.%s:%s/' % [
        self.metadata.name,
        self.metadata.namespace,
        self.spec.ports[0].port,
      ],
      proxy_urlpath:: '/api/v1/proxy/namespaces/%s/services/%s/' % [
        self.metadata.namespace,
        self.metadata.name,
      ],
      // Useful in Ingress rules
      name_port:: {
        serviceName: service.metadata.name,
        servicePort: service.spec.ports[0].port,
      },

      // TODO(kaldorn): Update this for K8s 1.27 to `service.kubernetes.io/topology-mode: auto`
      // Source: https://kubernetes.io/docs/concepts/services-networking/topology-aware-routing
      // metadata+: {
      //   annotations+: {
      //     'service.kubernetes.io/topology-aware-hints': 'Auto',
      //   },
      // },

      spec: {
        selector: std.mergePatch(service.target_pod.metadata.labels, {
          // version was recently added to all services via stencil-golang
          // this is a tmp patch to remove it from the service selector
          // TODO(fnd-cor): consider a better long-term fix here to avoid
          // leaking any unwanted labels into service selectors
          version: null,
        }),
        ports: [
          {
            local target_port = service.target_pod.spec.containers[0].ports[0],
            name: target_port.name,
            port: service.port,
            targetPort: target_port.name,
          },
        ],
        type: 'ClusterIP',
      },
    },

  ExternalNameService(name, namespace, address):
    $._Object('v1', 'Service', name, app=name, namespace=namespace) {
      metadata+: { namespace: namespace },
      spec: {
        type: 'ExternalName',
        externalName: address,
      },
    },

  PersistentVolume(name): $._Object('v1', 'PersistentVolume', name) {
    spec: {},
  },

  PVCVolume(pvc): {
    persistentVolumeClaim: { claimName: pvc.metadata.name },
  },

  StorageClass(name): $._Object('storage.k8s.io/v1', 'StorageClass', name) {
    provisioner: 'ebs.csi.aws.com',
  },

  PersistentVolumeClaim(name, namespace, app=name):
    $._Object('v1', 'PersistentVolumeClaim', name, app=app, namespace=namespace) {
      local pvc = self,

      storageClass:: null,
      storage:: error 'storage required',

      spec: {
        accessModes: ['ReadWriteOnce'],
        resources: {
          requests: {
            storage: pvc.storage,
          },
        },
        [if pvc.storageClass != null then 'storageClassName']: pvc.storageClass,
      },
    },

  Container(name): {
    name: name,
    image: error 'container image value required',

    env_:: {},
    env: $.envList(self.env_),

    args_:: {},
    args: ['--%s=%s' % kv for kv in $.objectItems(self.args_)],

    ports_:: {},
    ports: $.mapToNamedList(self.ports_),

    volumeMounts_:: {},
    volumeMounts: $.mapToNamedList(self.volumeMounts_),

    stdin: false,
    tty: false,
    assert !self.tty || self.stdin : 'tty=true requires stdin=true',

    // This will capture the final logs before your container died and
    // record them as the reason for termination (visible in kubectl describe pod).
    // This is a saner default than the normal one,
    // which requires your application to write to /dev/termination-log before exiting.
    // https://kubernetes.io/docs/tasks/debug/debug-application/determine-reason-pod-failure/
    terminationMessagePolicy: 'FallbackToLogsOnError',
  },

  Pod(name): $._Object('v1', 'Pod', name) {
    spec: $.PodSpec,
  },

  PodSpec: {
    // The 'first' container is used in various defaults in k8s.
    local container_names = std.objectFields(self.containers_),
    default_container::
      if std.length(container_names) > 1 then 'default'
      else if std.length(container_names) == 1 then container_names[0]
      else null,  // this happens if we directly set self.containers, and then we don't use this
    containers_:: {},

    local container_names_ordered = [self.default_container] + [
      n
      for n in container_names
      if n != self.default_container
    ],
    containers: [
      { name: $.hyphenate(name) } + self.containers_[name]
      for name in container_names_ordered
      if name != null && self.containers_[name] != null
    ],


    // Note initContainers are inherently ordered, and using this
    // named object will lose that ordering.  If order matters, then
    // manipulate `initContainers` directly (perhaps
    // appending/prepending to `super.initContainers` to mix+match
    // both approaches)
    initContainers_:: {},
    initContainers: [{ name: $.hyphenate(name) } + self.initContainers_[name] for name in std.objectFields(self.initContainers_) if self.initContainers_[name] != null],

    volumes_:: {},
    volumes: $.mapToNamedList(self.volumes_),

    imagePullSecrets: [],

    terminationGracePeriodSeconds: 30,
    dnsConfig+: {
      options: [{ name: 'ndots', value: '1' }],
    },

    assert std.length(self.containers) > 0 : 'must have at least one container',
  },

  WeightedPodAffinityTerm(matchExpressions={}, matchLabels={}): {
    podAffinityTerm: {
      labelSelector: {
        [if std.length(matchExpressions) > 0 then 'matchExpressions']: $.mapToNamedList(matchExpressions),
        [if std.length(matchLabels) > 0 then 'matchLabels']: matchLabels,
      },
      topologyKey: 'kubernetes.io/hostname',
    },
    weight: 100,

    assert std.length(self.podAffinityTerm.labelSelector) == 1 : 'must pass either matchLabels or matchExpressions',
  },

  EmptyDirVolume(): {
    emptyDir: {},
  },

  HostPathVolume(path): {
    hostPath: { path: path },
  },

  GitRepoVolume(repository, revision): {
    gitRepo: {
      repository: repository,

      // "master" is possible, but should be avoided for production
      revision: revision,
    },
  },

  SecretVolume(secret): {
    secret: { secretName: secret.metadata.name },
  },

  ConfigMapVolume(configmap): {
    configMap: { name: configmap.metadata.name },
  },

  ConfigMap(name, namespace, app=name): $._Object('v1', 'ConfigMap', name, namespace=namespace, app=app) {
    local this = self,
    md5:: std.md5(std.toString(this.data)),
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': '-4',
      },
    },
    data: {},

    // I keep thinking data values can be any JSON type.  This check
    // will remind me that they must be strings :(
    local nonstrings = [
      k
      for k in std.objectFields(this.data)
      if std.type(this.data[k]) != 'string'
    ],
    assert std.length(nonstrings) == 0 : 'data contains non-string values: %s' % [nonstrings],
  },

  // subtype of EnvVarSource
  ConfigMapRef(configmap, key): {
    assert std.objectHas(configmap.data, key) : '%s not in configmap.data' % [key],
    configMapKeyRef: {
      name: configmap.metadata.name,
      key: key,
    },
  },

  Secret(name, namespace, app=name): $._Object('v1', 'Secret', name, app=app, namespace=namespace) {
    local secret = self,

    type: 'Opaque',
    md5:: std.md5(std.toString(secret.data_)),
    data_:: {},
    data: { [k]: std.base64(secret.data_[k]) for k in std.objectFields(secret.data_) },
  },

  // subtype of EnvVarSource
  SecretKeyRef(secret, key): {
    assert std.objectHas(secret.data, key) : '%s not in secret.data' % [key],
    secretKeyRef: {
      name: secret.metadata.name,
      key: key,
    },
  },

  local hashed = {
    local this = self,
    metadata+: {
      local hash = std.substr(this.md5, 0, 7),
      local orig_name = super.name,
      name: orig_name + '-' + hash,
      labels+: { name: orig_name },
    },
  },

  HashedConfigMap(name, namespace, app=name):
    $.ConfigMap(name, namespace, app=app) + hashed,

  HashedSecret(name, namespace, app=name):
    $.Secret(name, namespace, app=app) + hashed,

  // subtype of EnvVarSource
  FieldRef(key): {
    fieldRef: {
      apiVersion: 'v1',
      fieldPath: key,
    },
  },

  // subtype of EnvVarSource
  ResourceFieldRef(key): {
    resourceFieldRef: {
      resource: key,
      divisor_:: 1,
      divisor: std.toString(self.divisor_),
    },
  },

  VersionedDeployment(name, namespace, version, app=name):
    $.Deployment(name + '-' + version, namespace, app) {
      metadata+: { labels+: { version: version } },
    },

  Deployment(name, namespace, app=name):
    $._Object('apps/v1', 'Deployment', name, app=app, namespace=namespace) {
      local deployment = self,

      spec: {
        selector: {
          matchLabels: {
            [if app != null then 'app']: app,
            [if app != null && namespace == 'kube-system' then 'k8s-app']: app,
          },
        },
        template: {
          spec: if environment == 'development' then $.PodSpec {
            // Set anti-affinity to help AZ distributiuon
            affinity: {
              podAntiAffinity: {
                local podAffinityTerm(topologyKey, weight=100) = {
                  podAffinityTerm: {
                    labelSelector: {
                      matchExpressions: [{ key: 'name', operator: 'In', values: [name] }],
                    },
                    topologyKey: topologyKey,
                  },
                  weight: weight,
                },
                preferredDuringSchedulingIgnoredDuringExecution: [
                  podAffinityTerm(k)
                  for k in [
                    'kubernetes.io/hostname',
                    'failure-domain.beta.kubernetes.io/zone',
                  ]
                ],
              },
            },
          } else $.PodSpec {
            topologySpreadConstraints: [
              {
                maxSkew: 1,
                topologyKey: 'topology.kubernetes.io/zone',
                whenUnsatisfiable: 'DoNotSchedule',
                labelSelector: {
                  matchLabels: {
                    name: name,
                  },
                },
              },
            ],
          },
          metadata: {
            labels: deployment.metadata.labels,
            annotations: {
              'cluster-autoscaler.kubernetes.io/safe-to-evict': 'true',
            },
          },
        },
        strategy: {
          type: 'RollingUpdate',

          //local pvcs = [
          //  v
          //  for v in deployment.spec.template.spec.volumes
          //  if std.objectHas(v, 'persistentVolumeClaim')
          //],
          //local is_stateless = std.length(pvcs) == 0,

          // Apps trying to maintain a majority quorum or similar will
          // want to tune these carefully.
          // NB: Upstream default is surge=1 unavail=1
          //rollingUpdate: if is_stateless then {
          //  maxSurge: '25%',  // rounds up
          //  maxUnavailable: '25%',  // rounds down
          //} else {
          //  // Poor-man's StatelessSet.  Useful mostly with replicas=1.
          //  maxSurge: 0,
          //  maxUnavailable: 1,
          //},
        },
      },
    },
  CrossVersionObjectReference(target): {
    apiVersion: target.apiVersion,
    kind: target.kind,
    name: target.metadata.name,
  },

  HorizontalPodAutoscaler(name, namespace, app=name): $._Object('autoscaling/v1', 'HorizontalPodAutoscaler', name, app=app, namespace=namespace) {
    local hpa = self,

    target:: error 'target required',

    spec: {
      scaleTargetRef: $.CrossVersionObjectReference(hpa.target),

      minReplicas: hpa.target.spec.replicas,
      maxReplicas: error 'maxReplicas required',

      assert self.maxReplicas >= self.minReplicas,
    },
  },

  HorizontalPodAutoscalerV2(name, namespace, app=name): $._Object('autoscaling/v2', 'HorizontalPodAutoscaler', name, app=app, namespace=namespace) {
    local hpa = self,

    target:: error 'target required',

    spec: {
      scaleTargetRef: $.CrossVersionObjectReference(hpa.target),

      minReplicas: hpa.target.spec.replicas,
      maxReplicas: error 'maxReplicas required',

      assert self.maxReplicas >= self.minReplicas,
    },
  },

  // ---------------------------------------------------------------------------
  // KEDA
  //
  // KEDA (keda.sh) autoscales from a ScaledObject, which owns a
  // HorizontalPodAutoscaler of its own: KEDA creates that HPA and thereafter
  // overwrites its metrics, annotations, and labels on every reconcile. Two
  // controllers writing one HPA is a fight -- and if the HPA is also declared
  // in GitOps, ArgoCD is the second controller -- so a workload is autoscaled
  // by *either* a HorizontalPodAutoscaler this library renders or a
  // ScaledObject, never both. KedaScaledObject() converts the former into the
  // latter in place, which keeps one declaration as the source of truth.
  // ---------------------------------------------------------------------------

  // Defaults for KEDA's Datadog scaler in Cluster Agent proxy mode -- the
  // shape the Datadog-HPA -> KEDA migration standardised on. Override any of
  // them per call site through KedaScaledObject()'s `opts`.
  kedaDefaults:: {
    // Cluster-wide credentials for the Datadog scaler, installed with KEDA
    // itself (eks-cluster-addons), not per namespace.
    clusterTriggerAuthentication: 'datadog-cluster-agent-creds',
    // How far back the scaler reads the DatadogMetric, in seconds.
    datadogMetricAge: 90,
    pollingInterval: 30,
    fallbackFailureThreshold: 3,
    // Value the scaler reports when Datadog returns no data, so a no-data
    // query holds replicas instead of surfacing as FailedGetExternalMetric on
    // the HPA. The symbolic 'targetValue' resolves to each trigger's own
    // target -- the only per-workload-correct default, since "at or above
    // target holds replicas" is relative to a number that differs per
    // workload. null omits it.
    metricUnavailableValue: 'targetValue',
    // Adopt an HPA that already exists under this name rather than failing.
    transferHPAOwnership: true,
  },

  // kedaDatadogMetricRef splits a Datadog Cluster Agent external metric name
  // ("datadogmetric@<namespace>:<name>") into its parts.
  kedaDatadogMetricRef(metricName):: (
    local prefix = 'datadogmetric@';
    assert std.startsWith(metricName, prefix) :
           'KEDA: external metric %s is not a DatadogMetric reference ("datadogmetric@<namespace>:<name>")' % metricName;
    local rest = std.substr(metricName, std.length(prefix), std.length(metricName) - std.length(prefix));
    local parts = std.splitLimit(rest, ':', 1);
    assert std.length(parts) == 2 :
           'KEDA: external metric %s is missing the ":<name>" half of a DatadogMetric reference' % metricName;
    { namespace: parts[0], name: parts[1] }
  ),

  // kedaPlainNumber renders an HPA metric target as the plain number string
  // KEDA's Datadog scaler expects. A quantity suffix ("10k") is valid on an
  // HPA but the scaler parses this field with ParseFloat, so a suffix carried
  // over verbatim produces a trigger that can never resolve -- fail loudly at
  // render time instead.
  kedaPlainNumber(value, what):: (
    local s = std.toString(value);
    assert std.length(std.stripChars(s, '0123456789.+-')) == 0 :
           'KEDA: %s target %s must be a plain number, not a Kubernetes quantity -- the Datadog scaler parses it with ParseFloat' % [what, s];
    s
  ),

  // kedaTrigger translates one HPA v2 metric into a KEDA trigger.
  //  * An External metric referencing a DatadogMetric becomes a `datadog`
  //    trigger in Cluster Agent proxy mode: same DatadogMetric CR, same
  //    value, same threshold -- only the path the value travels changes.
  //  * A cpu/memory Resource metric becomes KEDA's built-in cpu/memory
  //    trigger, which reads metrics.k8s.io exactly as the HPA did.
  kedaTrigger(metric, opts=$.kedaDefaults):: (
    if metric.type == 'External' then
      local ref = $.kedaDatadogMetricRef(metric.external.metric.name);
      local target = metric.external.target;
      local targetValue = $.kedaPlainNumber(
        if std.objectHas(target, 'value') then target.value else target.averageValue,
        'external metric ' + metric.external.metric.name,
      );
      {
        type: 'datadog',
        metricType: target.type,
        metadata: {
          useClusterAgentProxy: 'true',
          datadogMetricNamespace: ref.namespace,
          datadogMetricName: ref.name,
          targetValue: targetValue,
          age: std.toString(opts.datadogMetricAge),
          [if opts.metricUnavailableValue != null then 'metricUnavailableValue']:
            if opts.metricUnavailableValue == 'targetValue' then targetValue
            else std.toString(opts.metricUnavailableValue),
        },
        authenticationRef: {
          kind: 'ClusterTriggerAuthentication',
          name: opts.clusterTriggerAuthentication,
        },
      }
    else if metric.type == 'Resource' && (metric.resource.name == 'cpu' || metric.resource.name == 'memory') then
      local target = metric.resource.target;
      {
        type: metric.resource.name,
        metricType: target.type,
        metadata: {
          value: std.toString(
            if std.objectHas(target, 'averageUtilization') then target.averageUtilization
            else if std.objectHas(target, 'averageValue') then target.averageValue
            else target.value
          ),
        },
      }
    else
      error 'KEDA: no trigger for %s metric %s -- KEDA has no equivalent of Pods/Object metrics or of non-cpu/memory Resource metrics, so this HPA cannot be converted' % [
        metric.type,
        if metric.type == 'Resource' then metric.resource.name else std.toString(metric),
      ]
  ),

  // KedaScaledObject converts the HorizontalPodAutoscalerV2 it is mixed into
  // -- `hpa + $.KedaScaledObject(enabled)` -- into the KEDA ScaledObject that
  // owns that HPA, deriving triggers from the HPA's own metrics so thresholds
  // are declared once and cannot drift between the two shapes. Mix it in
  // last: it reads the HPA spec after every other override has merged.
  //
  // `enabled` is required and has no default on purpose. KEDA is enabled
  // cluster by cluster, so callers drive this from their own per-bento data
  // and one call site renders a ScaledObject on the migrated clusters and a
  // plain HPA on every other. enabled=false is exactly the HPA that was there
  // before, byte for byte.
  KedaScaledObject(enabled, opts={}):: if !enabled then {} else (
    local o = $.kedaDefaults + opts;
    {
      local hpaSpec = super.spec,
      local hpaName = super.metadata.name,
      local scaleTarget = hpaSpec.scaleTargetRef,

      apiVersion: 'keda.sh/v1alpha1',
      kind: 'ScaledObject',

      metadata+: {
        annotations+: {
          [if o.transferHPAOwnership then 'scaledobject.keda.sh/transfer-hpa-ownership']: 'true',
        },
      },

      spec: {
        scaleTargetRef: {
          name: scaleTarget.name,
          // KEDA defaults to apps/v1 Deployment.
          [if scaleTarget.kind != 'Deployment' then 'apiVersion']: scaleTarget.apiVersion,
          [if scaleTarget.kind != 'Deployment' then 'kind']: scaleTarget.kind,
        },
        minReplicaCount: hpaSpec.minReplicas,
        maxReplicaCount: hpaSpec.maxReplicas,
        pollingInterval: o.pollingInterval,
        // A scaler that is failing must not strand the workload
        // under-provisioned, so fall back to the workload's own ceiling
        // rather than a guess at its steady state.
        fallback: {
          failureThreshold: o.fallbackFailureThreshold,
          replicas: hpaSpec.maxReplicas,
        },
        advanced: {
          horizontalPodAutoscalerConfig: {
            // Keep the HPA's existing name. Without this KEDA creates
            // keda-hpa-<scaledobject>, which orphans every dashboard, alert,
            // and runbook that names the HPA.
            name: hpaName,
            [if std.objectHas(hpaSpec, 'behavior') then 'behavior']: hpaSpec.behavior,
          },
        },
        triggers: [$.kedaTrigger(metric, o) for metric in hpaSpec.metrics],
      },
    }
  ),

  VerticalPodAutoscaler(name, namespace, app=name): $._Object('autoscaling.k8s.io/v1beta2', 'VerticalPodAutoscaler', name, app=app, namespace=namespace) {
    local vpa = self,
    target:: error 'target required',
    spec: {
      targetRef: $.CrossVersionObjectReference(vpa.target),

      updatePolicy: {
        updateMode: 'Initial',
      },
    },
  },

  StatefulSet(name, namespace, app=name):
    $._Object('apps/v1', 'StatefulSet', name, app=app, namespace=namespace) {
      local sset = self,

      spec: {
        selector: { matchLabels: sset.metadata.labels },
        serviceName: name,

        template: {
          spec: $.PodSpec {
            // Set anti-affinity to help AZ distributiuon
            affinity: {
              podAntiAffinity: {
                preferredDuringSchedulingIgnoredDuringExecution: [{
                  podAffinityTerm: {
                    labelSelector: {
                      matchExpressions: [
                        {
                          key: 'name',
                          operator: 'In',
                          values: [name],
                        },
                      ],
                    },
                    topologyKey: 'failure-domain.beta.kubernetes.io/zone',
                  },
                  weight: 100,
                }],
              },
            },
          },
          metadata: {
            labels: sset.metadata.labels,
            annotations: {
              'cluster-autoscaler.kubernetes.io/safe-to-evict': 'true',
            },
          },
        },

        volumeClaimTemplates_:: {},
        volumeClaimTemplates: [$.PersistentVolumeClaim($.hyphenate(kv[0])) + kv[1] for kv in $.objectItems(self.volumeClaimTemplates_)],

        replicas: 1,
      },
    },

  Job(name, namespace='default', app=name): $._Object('batch/v1', 'Job', name, app=app, namespace=namespace) {
    local job = self,
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/hook': 'Sync',
        'argocd.argoproj.io/sync-wave': '-3',
      },
    },
    spec: {
      template: {
        spec: $.PodSpec {
          restartPolicy: 'OnFailure',
        },
        metadata: {
          labels: job.metadata.labels,
          annotations: {
            'cluster-autoscaler.kubernetes.io/safe-to-evict': 'true',
          },
        },
      },

      completions: 1,
      parallelism: 1,
    },
  },

  CronJob(name, namespace, app=name): $._Object('batch/v1', 'CronJob', name, app=app, namespace=namespace) {
    spec: {
      jobTemplate: $.Job(name, namespace, app) {
        apiVersion:: null,
        kind:: null,
        metadata:: super.metadata,
      },
      schedule: error 'schedule is required',
    },
  },

  DaemonSet(name, namespace, app=name):
    $._Object('apps/v1', 'DaemonSet', name, app=app, namespace=namespace) {
      local ds = self,
      spec: {
        selector: {
          matchLabels: {
            [if app != null then 'app']: app,
            [if app != null && namespace == 'kube-system' then 'k8s-app']: app,
          },
        },
        template: {
          metadata: {
            labels: ds.metadata.labels,
            annotations: {
              'cluster-autoscaler.kubernetes.io/safe-to-evict': 'true',
            },
          },
          spec: $.PodSpec,
        },
      },
    },

  Ingress(name, namespace, app=name):
    $._Object('networking.k8s.io/v1beta1', 'Ingress', name, app=app, namespace=namespace) {
      spec: {},
    },

  IngressV1(name, namespace, app=name):
    $._Object('networking.k8s.io/v1', 'Ingress', name, app=app, namespace=namespace) {
      spec: {},
    },

  ThirdPartyResource(name): $._Object('apps/v1', 'ThirdPartyResource', name) {
    versions_:: [],
    versions: [{ name: n } for n in self.versions_],
  },

  ServiceAccount(name, namespace, app=name): $._Object('v1', 'ServiceAccount', name, namespace=namespace, app=app) {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-wave': '-5',
      },
    },
  },

  Role(name, app=name, namespace=null): $._Object('rbac.authorization.k8s.io/v1', 'Role', name, app=app, namespace=namespace) {
    rules: [],
  },

  ClusterRole(name, app=name): $.Role(name, app=app) {
    kind: 'ClusterRole',
  },

  RoleBinding(name, app=name, namespace=null): $._Object('rbac.authorization.k8s.io/v1', 'RoleBinding', name, app=app, namespace=namespace) {
    local rb = self,

    subjects_:: [],
    subjects: [{
      kind: o.kind,
      namespace: if std.objectHas(o.metadata, 'namespace') then o.metadata.namespace else null,
      name: o.metadata.name,
    } for o in self.subjects_],

    roleRef_:: error 'roleRef is required',
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: rb.roleRef_.kind,
      name: rb.roleRef_.metadata.name,
    },
  },

  ClusterRoleBinding(name, app=name): $.RoleBinding(name, app=app) {
    kind: 'ClusterRoleBinding',
  },

  LimitRange(name, namespace): $._Object('v1', 'LimitRange', name, namespace=namespace),

  PodDisruptionBudget(name, namespace, app=name): $._Object('policy/v1', 'PodDisruptionBudget', name, namespace=namespace) {
    spec: {
      maxUnavailable: '50%',
      selector: {
        matchLabels: {
          app: app,
        },
      },
    },
  },

  APIServiceV1(name, app=name): $._Object('apiregistration.k8s.io/v1', 'APIService', name, app=app) {
    local api = self,
    kind: 'APIService',
    service:: error 'service required',
    spec+: {
      group: std.join('.', std.split(name, '.')[1:]),
      version: std.split(name, '.')[0],
      service+: {
        name: api.service.metadata.name,
        namespace: api.service.metadata.namespace,
      },
    },
  },

  // Convert a prometheus duration ('30s', '1m', '2h') to whole seconds.
  // Single-unit durations only; compound forms like '1m30s' are rejected.
  local durationSeconds(d) =
    local n = std.parseInt(std.substr(d, 0, std.length(d) - 1));
    local unit = std.substr(d, std.length(d) - 1, 1);
    if unit == 's' then n
    else if unit == 'm' then n * 60
    else if unit == 'h' then n * 3600
    else error 'unsupported interval %s: expected <n>s, <n>m, or <n>h' % d,

  // Stamps the scrape interval (in seconds) onto every series scraped by an
  // endpoint. The OTel collector maps it to a datapoint attribute and then
  // promotes it to a resource attribute. Prometheus label names cannot contain
  // dots, so the attribute name is underscore-flattened here and renamed in
  // the collector pipeline.
  local intervalRelabeling(interval) = {
    targetLabel: 'outreach_metric_collection_interval',
    replacement: std.toString(durationSeconds(interval)),
  },

  // ServiceMonitor selects a Service and scrapes its metrics port. Pass the
  // target Service via target_service:: -- the metrics port (named or targeting
  // 'metrics', else the sole port) and selector are derived from it. All
  // Service labels are copied onto the series; scrape interval defaults to 30s
  // (override via the `interval` arg).
  //
  // Minimal usage (no overrides needed for a stencil service with a 'metrics'
  // port):
  // ```
  // servicemonitor: ok.ServiceMonitor(app.name, app.namespace) {
  //   target_service:: $.service,
  // },
  // ```
  //
  // Common overrides:
  // ```
  // servicemonitor: ok.ServiceMonitor(app.name, app.namespace, interval='60s') {
  //   target_service:: $.service,
  //   spec+: {
  //     // per-endpoint tuning, keyed by the Service port's targetPort
  //     endpoints_+:: { 'http-prom': {
  //       interval: '15s',
  //       // drop noisy series
  //       metricRelabelings: [{ sourceLabels: ['__name__'], regex: 'go_gc_.*', action: 'drop' }],
  //     } },
  //     // restrict which Service labels are copied (default: all of them)
  //     targetLabels_:: ['app', 'repo'],
  //   },
  // },
  // ```
  ServiceMonitor(name, namespace, app=name, interval='30s'): $._Object(
    'monitoring.coreos.com/v1',
    'ServiceMonitor',
    name,
    app=app,
    namespace=namespace,
  ) {
    target_service:: error 'target_service required',

    local this = self,

    // Discover the port to scrape.
    // Note: use std.member, not std.setMember -- the latter assumes a sorted
    // set and misdetects when targetPort == 'metrics' but the port name sorts
    // after 'metrics'.
    local ports = this.target_service.spec.ports,
    local matched_ports = std.filter(
      function(p) std.member([p.name, p.targetPort], 'metrics'),
      ports,
    ),
    local default_port =
      if std.length(matched_ports) > 0 then matched_ports[0]
      // No 'metrics' port: fall back to the sole port when unambiguous
      // (common for apps serving /metrics on their only port).
      else if std.length(ports) == 1 then ports[0]
      // Multiple ports and none is 'metrics' -> refuse to guess (objectFields
      // sorting could pick e.g. the gRPC port). Set spec.endpoints_ explicitly.
      else error 'ServiceMonitor(%s): target_service has multiple ports and none is named or targets "metrics"; set spec.endpoints_ explicitly' % name,

    spec: {
      // All Service labels are copied onto every scraped series -- they carry
      // the low-cardinality dimensions (repo/bento/reporting_team/...) that
      // downstream consumers rely on, and this is the only place to surface
      // them. Any renames (e.g. reporting_team -> team) are done centrally in
      // the collector pipeline, not here. Override targetLabels_ to restrict.
      targetLabels_:: std.objectFields(this.target_service.metadata.labels),

      // endpoint-level config here will override defaults
      // this is just map-based sugar around self.endpoints
      endpoints_:: { [default_port.targetPort]: {} },
      // override this to explicitly adhere to the operator's API
      // and ignore all of the above, which is simply sugar
      endpoints: [
        // interval defaults to the constructor's `interval` arg (30s); override
        // per-endpoint via endpoints_. The interval stamp is derived from the
        // endpoint's effective interval, so per-endpoint overrides are
        // reflected in the label; user metricRelabelings are appended after
        // the stamp. To suppress the stamp, override metricRelabelings on the
        // rendered endpoint.
        local ep = { honorLabels: true, interval: interval, targetPort: p } + this.spec.endpoints_[p];
        ep {
          metricRelabelings: [intervalRelabeling(ep.interval)]
                             + (if std.objectHas(ep, 'metricRelabelings') then ep.metricRelabelings else []),
        }
        for p in std.objectFields(this.spec.endpoints_)
      ],
      jobLabel: 'app',
      // Minimal, stable selector -- match only the target Service's identity.
      // The old default matched the full label set, which would silently break
      // the SM if any label (repo/bento/reporting_team/...) changed. Override
      // via selectorLabels_ if a different match is needed.
      selectorLabels_:: { name: this.target_service.metadata.name },
      selector: {
        matchLabels: this.spec.selectorLabels_,
      },
      targetLabels: this.spec.targetLabels_,
    },
  },

  // PodMonitor scrapes pods directly, for apps that do not expose a Service
  // with a metrics port. Mirrors ServiceMonitor's defaults: minimal selector,
  // honorLabels on, all pod labels copied onto the series, and a 30s scrape
  // interval.
  //
  // Minimal usage (pod has a 'metrics'/'http-prom' container port):
  // ```
  // podmonitor: ok.PodMonitor(app.name, app.namespace) {
  //   target_pod:: $.deployment.spec.template,
  // },
  // ```
  //
  // Common overrides:
  // ```
  // podmonitor: ok.PodMonitor(app.name, app.namespace, interval='60s') {
  //   target_pod:: $.deployment.spec.template,
  //   spec+: {
  //     // per-endpoint tuning, keyed by the container port name
  //     podMetricsEndpoints_+:: { 'http-prom': {
  //       interval: '15s',
  //       // drop noisy series before they leave the pod
  //       metricRelabelings: [{ sourceLabels: ['__name__'], regex: 'go_gc_.*', action: 'drop' }],
  //     } },
  //     // restrict which pod labels are copied (default: all of them)
  //     podTargetLabels_:: ['app', 'repo'],
  //   },
  // },
  // ```
  PodMonitor(name, namespace, app=name, interval='30s'): $._Object(
    'monitoring.coreos.com/v1',
    'PodMonitor',
    name,
    app=app,
    namespace=namespace,
  ) {
    target_pod:: error 'target_pod required',

    local this = self,

    // Flatten every container port on the pod. Container ports have a name and
    // containerPort (no targetPort -- that only exists on Services).
    local pod_ports = std.flattenArrays([
      if std.objectHas(c, 'ports') then c.ports else []
      for c in this.target_pod.spec.containers
    ]),
    // Container port names that identify the metrics port. Note this is the
    // CONTAINER port name: stencil names it 'http-prom' (the Service port named
    // 'metrics' targets it), so match both.
    local metrics_port_names = ['metrics', 'http-prom'],
    local matched_ports = std.filter(function(p) std.member(metrics_port_names, p.name), pod_ports),
    local default_port =
      if std.length(matched_ports) > 0 then matched_ports[0]
      // No metrics-named port: fall back to the sole port when unambiguous.
      else if std.length(pod_ports) == 1 then pod_ports[0]
      // Multiple ports and none is a metrics port -> refuse to guess.
      else error 'PodMonitor(%s): target_pod has multiple ports and none is named one of [%s]; set spec.podMetricsEndpoints_ explicitly' % [name, std.join(', ', metrics_port_names)],

    spec: {
      // All pod labels are copied onto every scraped series -- they carry the
      // low-cardinality dimensions (repo/bento/reporting_team/...) that
      // downstream consumers rely on. Any renames (e.g. reporting_team -> team)
      // are done centrally in the collector pipeline, not here. Override
      // podTargetLabels_ to restrict the set.
      podTargetLabels_:: std.objectFields(this.target_pod.metadata.labels),

      // map-based sugar around self.podMetricsEndpoints, keyed by port name
      podMetricsEndpoints_:: { [default_port.name]: {} },
      // override this to explicitly adhere to the operator's API
      podMetricsEndpoints: [
        // interval defaults to the constructor's `interval` arg (30s); override
        // per-endpoint via podMetricsEndpoints_. The interval stamp is derived
        // from the endpoint's effective interval, so per-endpoint overrides
        // are reflected in the label; user metricRelabelings are appended
        // after the stamp. To suppress the stamp, override metricRelabelings
        // on the rendered endpoint.
        local ep = { honorLabels: true, interval: interval, port: p } + this.spec.podMetricsEndpoints_[p];
        ep {
          metricRelabelings: [intervalRelabeling(ep.interval)]
                             + (if std.objectHas(ep, 'metricRelabelings') then ep.metricRelabelings else []),
        }
        for p in std.objectFields(this.spec.podMetricsEndpoints_)
      ],
      jobLabel: 'app',
      // Minimal, stable selector against the pod's identity label. Override via
      // selectorLabels_ if a different match is needed. (namespaceSelector is
      // omitted so the operator defaults to the PodMonitor's own namespace.)
      selectorLabels_:: { name: this.target_pod.metadata.labels.name },
      selector: {
        matchLabels: this.spec.selectorLabels_,
      },
      podTargetLabels: this.spec.podTargetLabels_,
    },
  },

  Mixins: {
    'cluster-service': {
      metadata+: {
        labels+: {
          'kubernetes.io/cluster-service': 'true',
        },
      },
    },
    'critical-pod': {
      metadata+: {
        annotations+: {
          'scheduler.alpha.kubernetes.io/critical-pod': '',
        },
      },
    },
  },

  VaultSecret(name, namespace, alias=''): $._Object('secrets.outreach.io/v1alpha1', 'VaultSecret', name, namespace=namespace) {
    vaultPath_:: error 'vaultPath_ is required',
    local this = self,
    metadata+: {
      annotations+: {
        // https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/#how-do-i-configure-waves
        'argocd.argoproj.io/sync-wave': '-5',
      },
    },
    spec: {
      reconciled: false,
      vaultPath: this.vaultPath_,
      [if alias != '' then 'alias']: alias,
    },
  },

  // GoSecretData adds a helper for creating the go-outreach/gobox secretData struct
  GoSecretData(path): { Path: path },

  /*
  * addEnvFromSecret adds a secret to the environment of a container. It
  * expects to be added to an object whose values are the kubernetes resources
  * to be defined. The secret is injected into the environment of the specified
  * container using the kubernetes envFrom field.
  *
  * It expects the value at the field to have the structure
  * { spec: { template: { spec: { containers_:: { [container_name]: { ... } } } } } }
  *
  * Parameters:
  *
  * 	secretName     : the name of the secret to add to the container
  * 	key            : the field of the object (e.g.; deployment) to add the secret to
  * 	container_name : the name of the container to add the secret to
  *
  * return value: an object that to mixin to the top-level kubernetes resource
  * object with the object composition operator +.
  */
  addEnvFromSecret(secretName, key='deployment', container_name='default'): {
    [key]+: {
      spec+: {
        template+: {
          spec+: {
            containers_+:: {
              [container_name]+: {
                envFrom+: [
                  { secretRef: { name: secretName } },
                ],
              },
            },
          },
        },
      },
    },
  },


  DatadogMetric(name, namespace, app=name): $._Object('datadoghq.com/v1alpha1', 'DatadogMetric', name, namespace=namespace, app=app) {
    local metric = self,

    metadata+: {
      annotations+: {
        'external-metrics.datadoghq.com/always-active': 'true',
      },
    },

    query_:: error 'query is required',
    spec: {
      query: metric.query_,
    },
  },

  // Deploys only Gateway object which is proccessed by Istio and Waypoint proxy is added
  // Namespace, service or pods need to be labeled with 'istio.io/use-waypoint=waypoint' to use this waypoint
  WaypointProxy(name='waypoint', namespace, team): $._Object('gateway.networking.k8s.io/v1', 'Gateway', name, namespace=namespace) {
    metadata+: {
      labels+: {
        name: name,
        reporting_team: team,
        // override in case you want 'all', 'workload' or 'none' to disable
        'istio.io/waypoint-for': 'all',
      },
    },
    spec+: {
      gatewayClassName: 'istio-waypoint',
      listeners+: [{
        name: 'mesh',
        port: 15008,
        protocol: 'HBONE',
      }],
      infrastructure+: {
        parametersRef: {
          group: '',
          kind: 'ConfigMap',
          name: name,
        },
      },
    },
  },

  WaypointProxyConfig(name='waypoint-config', namespace, team): self.ConfigMap(name, namespace, team) {
    metadata+: {
      labels+: {
        reporting_team: team,
      },
    },
    data+: {
      deployment+: std.manifestYamlDoc({
        spec: {
          template: {
            metadata: {
              annotations: {
                'scaleops.sh/default-rightsize-policy': 'high-availability',
              },
            },
            spec: {
              nodeSelector: {
                'outreach.io/nodepool': 'ondemand',
              },
              priorityClassName: 'system-cluster-critical',
              tolerations: [{
                effect: 'NoSchedule',
                key: 'dedicated',
                operator: 'Equal',
                value: 'ondemand',
              }],
              topologySpreadConstraints: [{
                labelSelector: {
                  matchLabels: {
                    'gateway.networking.k8s.io/gateway-name': name,
                  },
                },
                maxSkew: 1,
                topologyKey: 'topology.kubernetes.io/zone',
                whenUnsatisfiable: 'DoNotSchedule',
              }],
              containers: [{
                name: 'istio-proxy',
                resources: {
                  limits: {
                    memory: '1Gi',
                  },
                  requests: {
                    cpu: '500m',
                    memory: '200Mi',
                  },
                },
              }],
            },
          },
        },
      }),
      horizontalPodAutoscaler+: std.manifestYamlDoc({
        spec: {
          minReplicas: 2,
          maxReplicas: 6,
          scaleTargetRef: {
            apiVersion: 'apps/v1',
            kind: 'Deployment',
            name: name,
          },
          metrics: [{
            type: 'Resource',
            resource: {
              name: 'cpu',
              target: {
                type: 'Utilization',
                averageUtilization: 80,
              },
            },
          }],
        },
      }),
      podDisruptionBudget+: std.manifestYamlDoc({
        spec: {
          minAvailable: 1,
        },
      }),
    },
  },

  GatewayConfig(name='gateway', namespace): $._Object('gateway.networking.k8s.io/v1', 'Gateway', name, namespace=namespace) {
    metadata+: {
      labels+: {
        name: name,
      },
      annotations+: {
        'cert-manager.io/cluster-issuer': 'letsencrypt-prod',
        'service.beta.kubernetes.io/aws-load-balancer-type': 'external',
        'service.beta.kubernetes.io/aws-load-balancer-nlb-target-type': 'ip',
        'service.beta.kubernetes.io/aws-load-balancer-scheme': 'internet-facing',
      },
    },
    spec+: {
      gatewayClassName: 'istio',
    },
  },
  HttpRoute(name='httproute', namespace): $._Object('gateway.networking.k8s.io/v1', 'HTTPRoute', name, namespace=namespace) {
    metadata+: {
      labels+: {
        name: name,
      },
    },
    spec+: {},
  },
  GrpcRoute(name='grpcroute', namespace): $._Object('gateway.networking.k8s.io/v1', 'GRPCRoute', name, namespace=namespace) {
    metadata+: {
      labels+: {
        name: name,
      },
    },
    spec+: {},
  },
}
