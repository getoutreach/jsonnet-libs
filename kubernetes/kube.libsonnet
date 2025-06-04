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
        selector: service.target_pod.metadata.labels,
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

  ServiceMonitor(name, namespace, app=name): $._Object(
    'monitoring.coreos.com/v1',
    'ServiceMonitor',
    name,
    app=app,
    namespace=namespace,
  ) {
    target_service:: error 'target_service required',

    local this = self,

    // discover metrics port if exists, else use first port
    // whatever this resolves to is only used as the default
    // if spec.endpoints|spec.endpoints_ aren't specified below
    local default_port = (
      local ports = this.target_service.spec.ports;
      std.filter(function(p) std.setMember('metrics', [p.name, p.targetPort]), ports)
      + this.target_service.spec.ports
    )[0],

    metadata+: { labels+: { 'prometheus.io/scrape': 'true' } },
    spec: {
      // endpoint-level config here will override defaults
      // this is just map-based sugar around self.endpoints
      endpoints_:: { [default_port.targetPort]: {} },
      // override this to explicitly adhere to the operator's API
      // and ignore all of the above, which is simply sugar
      endpoints: [
        { honorLabels: true, interval: '1m', targetPort: p }
        + this.spec.endpoints_[p]
        for p in std.objectFields(this.spec.endpoints_)
      ],
      jobLabel: 'app',
      selector: {
        matchLabels: this.target_service.metadata.labels,
      },
      targetLabels: std.objectFields(this.target_service.metadata.labels),
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

  VaultSecret(name, namespace): $._Object('secrets.outreach.io/v1alpha1', 'VaultSecret', name, namespace=namespace) {
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

    query_:: error 'query is required',
    spec: {
      query: metric.query_,
    },
  },

  # Deploys only Gateway object which is proccessed by Istio and Waypoint proxy is added
  # Namespace, service or pods need to be labeled with 'istio.io/use-waypoint=waypoint' to use this waypoint
  WaypointProxy(name='waypoint', namespace, team): $._Object('gateway.networking.k8s.io/v1', 'Gateway', name, namespace=namespace) {
    metadata+: {
      labels+: {
        name: name,
        # override in case you want 'all', 'workload' or 'none' to disable
        'istio.io/waypoint-for': 'all',
      },
    },
    spec+: {
      gatewayClassName: 'istio-waypoint',
      listeners+: [{
        name: 'mesh',
        port: 15008,
        protocol: 'HBONE',
    },],
  },
},

  WaypointProxyConfig(name='waypoint', namespace, team): self.ConfigMap(name, namespace, team) {
    metadata+: {
      labels+: {
        repo: name,

        reporting_team: team,
      },
    },
    data: {
      deployment: std.manifestYamlDoc({
        spec: {
          template: {
            spec: {
              nodeSelector: {
                'outreach.io/nodepool': 'ondemand',
                },
              priorityClassName: system-cluster-critical
              },},},
      })
},
}