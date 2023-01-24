local ok = import 'outreach.libsonnet';

// namespace for argocd
local argocdNamespace = 'argocd';

{
  // DEPRECATED: Use ArgoCDApplication instead.
  Application(name, appProject='default'): ok._Object('argoproj.io/v1alpha1', 'Application', name, namespace=argocdNamespace) {
    local this = self,
    namespace_:: error 'namespace_ is required',
    path_:: error 'path_ is required',
    repo_:: error 'repo_ is required',
    initial_revision_:: '',
    repo_name_:: std.split(this.repo_, '/')[std.length(std.split(this.repo_, '/')) - 1],
    source_path_:: std.join('/', std.slice(std.split(this.path_, '/'), 0, std.length(std.split(this.path_, '/')) - 1, 1)),
    env_:: {},
    report_maestro_:: true,
    report_opslevel_:: true,
    notification_success_:: '',
    notification_failure_:: '',
    metadata+: {
      annotations+: {
        [if this.report_maestro_ then 'notifications.argoproj.io/subscribe.on-deployed.maestro']: '',
        [if this.report_opslevel_ then 'notifications.argoproj.io/subscribe.on-deployed.opslevel']: '',
        [if this.notification_success_ != '' then 'notifications.argoproj.io/subscribe.on-deployed.slack']: this.notification_success_,
        [if this.notification_success_ != '' then 'notifications.argoproj.io/subscribe.on-sync-succeeded.slack']: this.notification_success_,
        [if this.notification_failure_ != '' then 'notifications.argoproj.io/subscribe.on-health-degraded.slack']: this.notification_failure_,
        [if this.notification_failure_ != '' then 'notifications.argoproj.io/subscribe.on-sync-failed.slack']: this.notification_failure_,
        [if this.notification_failure_ != '' then 'notifications.argoproj.io/subscribe.on-sync-status-unknown.slack']: this.notification_failure_,
      },
    },
    spec: {
      destination: {
        namespace: this.namespace_,
        server: 'https://kubernetes.default.svc',
      },
      project: appProject,
      source: {
        path: this.source_path_,
        repoURL: this.repo_,
        [if this.initial_revision_ != '' then 'targetRevision']: this.initial_revision_,
        plugin: {
          name: 'kubecfg',
          env: ok.envList(this.env_) + [
            { name: 'VERSION', value: this.initial_revision_ },
            { name: 'NAMESPACE', value: this.namespace_ },
            { name: 'MANIFESTPATH', value: std.strReplace(this.path_, this.source_path_ + '/', '') },
          ],
        },
      },
      syncPolicy: {
        automated: {
          prune: true,
        },
        syncOptions: ['ApplyOutOfSyncOnly=false', 'PruneLast=true'],
      },
    },
  },
  ArgoCDApplication(app, createdBy): ok._Object('argoproj.io/v1alpha1', 'Application', app.name, namespace=argocdNamespace) {
    local this = self,
    namespace_:: '%(name)s--%(bento)s' % app,
    version_:: '',
    repo_name_:: app.name,
    source_path_:: 'deployments/%(name)s' % app,
    manifest_path_:: '%(name)s.jsonnet' % app,
    env_:: {},
    project_:: 'default',
    report_maestro_:: true,
    report_opslevel_:: true,
    slack_:: '',
    metadata+: {
      annotations+: {
        [if this.report_maestro_ then 'notifications.argoproj.io/subscribe.on-deployed.maestro']: '',
        [if this.report_opslevel_ then 'notifications.argoproj.io/subscribe.on-deployed.opslevel']: '',
      } + if this.slack_ != '' then {
        'notifications.argoproj.io/subscribe.on-deployed.slack': this.slack_,
        'notifications.argoproj.io/subscribe.on-sync-succeeded.slack': this.slack_,
        'notifications.argoproj.io/subscribe.on-health-degraded.slack': this.slack_,
        'notifications.argoproj.io/subscribe.on-sync-failed.slack': this.slack_,
        'notifications.argoproj.io/subscribe.on-sync-status-unknown.slack': this.slack_,
      } else {},
      labels+: {
        'app.kubernetes.io/managed-by': 'deploymentcontroller',
        'app.kubernetes.io/created-by': createdBy,
      },
    },
    spec: {
      destination: {
        namespace: this.namespace_,
        server: 'https://kubernetes.default.svc',
      },
      project: this.project_,
      source: {
        path: this.source_path_,
        repoURL: 'https://github.com/getoutreach/%s' % this.repo_name_,
        [if this.version_ != '' then 'targetRevision']: this.version_,
        plugin: {
          name: 'kubecfg',
          env: [
            { name: 'BENTO', value: app.bento },
            { name: 'CHANNEL', value: app.channel },
            { name: 'CLUSTER', value: app.cluster },
            { name: 'ENVIRONMENT', value: app.environment },
            { name: 'REGION', value: app.region },
            { name: 'VERSION', value: this.version_ },
            { name: 'NAMESPACE', value: this.namespace_ },
            { name: 'MANIFESTPATH', value: this.manifest_path_ },
          ] + ok.envList(this.env_),
        },
      },
      info: [
        {
          name: 'dash.url',
          value: 'https://dash.outreach.cloud/#/apps/%(name)s' % app,
        },
        {
          name: 'opslevel.url',
          value: 'https://app.opslevel.com/services/%(name)s' % app,
        },
      ],
      syncPolicy: {
        automated: {
          prune: true,
        },
        syncOptions: [
          'ApplyOutOfSyncOnly=false',
          'PruneLast=true',
        ],
      },
    },
  },
  WebhookEventSource(name): ok._Object('argoproj.io/v1alpha1', 'EventSource', name, namespace='argo-events') {
    spec: {
      type: 'webhook',
      webhook: {
        ['%s' % [name]]: {
          port: '12000',
          endpoint: '/%s' % name,
          method: 'POST',
        },
      },
    },
  },
  CalendarEventSource(name): ok._Object('argoproj.io/v1alpha1', 'EventSource', name, namespace='argo-events') {
    local this = self,
    cronstring:: error 'cronstring required',

    spec: {
      type: 'calendar',
      calendar: {
        ['%s' % [name]]: {
          schedule: this.cronstring,
          timezone: 'America/Los_Angeles',
        },
      },
    },
  },
  SnsEventSource(name): ok._Object('argoproj.io/v1alpha1', 'EventSource', name, namespace='argo-events') {
    local this = self,
    topicArn:: error 'topicArn required',
    region:: error 'region required',
    webhook:: error 'webhook required',

    spec: {
      type: 'sns',
      sns: {
        ['%s' % [name]]: {
          topicArn: this.topicArn,
          webhook: this.webhook,
          region: this.region,
        },
      },
    },
  },
  Gateway(name, namespace='argo-events', app=name): ok._Object('argoproj.io/v1alpha1', 'Gateway', name, namespace=namespace, app=app) {
    local this = self,
    gatewayType:: error 'gatewayType required',
    eventSourceName:: error 'eventSourceName required',
    targetSensor:: error 'targetSensor required',

    sensorServiceEndpoint:: 'http://%s.%s.svc.cluster.local:%s/' % [this.targetSensor.metadata.name, this.targetSensor.metadata.namespace, this.targetSensor.spec.subscription.http.port],

    metadata+: {
      labels+: {
        'gateways.argoproj.io/gateway-controller-instanceid': 'argo-events',
      },
    },
    spec: {
      type: this.gatewayType,
      eventSourceRef: {
        name: this.eventSourceName,
      },
      template: {
        metadata: {
          name: name,
          namespace: namespace,
          labels: {
            'gateway-name': name,
          },
        },
        spec: {
          containers: [
            ok.Container('gateway-client') {
              image: 'gcr.io/outreach-docker/argo/outreach-gateway-client:v0.12.1',
              command: ['/bin/gateway-client'],
              resources: {
                limits: { memory: '100Mi' },
                requests: { cpu: '10m' },
              },
            },
            ok.Container('%s-events' % this.gatewayType) {
              image: 'gcr.io/outreach-docker/argo/outreach-%s-gateway:v0.12.1' % this.gatewayType,
              command: ['/bin/%s-gateway' % this.gatewayType],
              resources: {
                limits: { memory: '100Mi' },
                requests: { cpu: '10m' },
              },
            },
          ],
          serviceAccountName: 'argo-events-sa',
        },
      },
      subscribers: {
        http: [
          this.sensorServiceEndpoint,
        ],
      },
    },
  },
  Sensor(name, namespace): ok._Object('argoproj.io/v1alpha1', 'Sensor', name, namespace=namespace) {
    local this = self,
    serviceAccountName:: error 'sensorServiceAccountName required',
    subscriptionPort:: 9300,
    eventName:: error 'eventName required',
    gatewayName:: error 'gatewayName required',

    metadata+: {
      labels+: {
        'sensors.argoproj.io/sensor-controller-instanceid': 'argo-events',
      },
    },
    spec: {
      template: {
        spec: {
          containers: [
            ok.Container('sensor') {
              image: 'gcr.io/outreach-docker/argo/outreach-sensor:v0.12.1',
              resources: {
                limits: { memory: '100Mi' },
                requests: { cpu: '10m' },
              },
            },
          ],
          serviceAccountName: this.serviceAccountName,
        },
      },
      dependencies: [
        {
          name: this.eventName,
          gatewayName: this.gatewayName,
          eventName: this.eventName,
        },
      ],
      subscription: {
        http: { port: this.subscriptionPort },
      },
      triggers: [],
    },
  },
  WorkflowCreationTrigger(name): {
    local this = self,
    workflow:: error 'workflow required',
    template: {
      name: name,
      k8s: {
        group: 'argoproj.io',
        version: 'v1alpha1',
        operation: 'create',
        resource: 'workflows',
        source: {
          resource: this.workflow,
        },
      },
    },
  },
  Workflow(name, namespace): ok._Object('argoproj.io/v1alpha1', 'Workflow', name, namespace=namespace) {},
  BashScriptContainer(name): {
    local this = self,
    bash_script:: error 'script required',
    name: name,
    script: {
      image: 'gcr.io/outreach-docker/alpine/scripts:1.0',
      command: ['bash'],
      source: this.bash_script,
    },
  },
  AppProject(name): ok._Object('argoproj.io/v1alpha1', 'AppProject', name, namespace=argocdNamespace) {
    spec: {
      clusterResourceWhitelist: [
        {
          group: '*',
          kind: '*',
        },
      ],
      destinations: [
        {
          namespace: '*',
          server: '*',
        },
      ],
      sourceRepos: [
        '*',
      ],
    },
  },
  ApplicationSet(name, appProject='default'): ok._Object('argoproj.io/v1alpha1', 'ApplicationSet', name, namespace=argocdNamespace) {
    local this = self,
    namespace_:: error 'namespace_ is required',
    path_:: error 'path_ is required',
    repo_:: error 'repo_ is required',
    initial_revision_:: '',
    repo_name_:: std.split(this.repo_, '/')[std.length(std.split(this.repo_, '/')) - 1],
    source_path_:: std.join('/', std.slice(std.split(this.path_, '/'), 0, std.length(std.split(this.path_, '/')) - 1, 1)),
    env_:: {},
    report_maestro_:: true,
    report_opslevel_:: true,
    spec: {
      template: {
        metadata: {
          name: '%s--{{ name }}' % name,
          annotations+: {
            [if this.report_maestro_ then 'notifications.argoproj.io/subscribe.on-deployed.maestro']: '',
            [if this.report_opslevel_ then 'notifications.argoproj.io/subscribe.on-deployed.opslevel']: '',
          },
        },
        spec: {
          destination: {
            namespace: this.namespace_,
            server: '{{ server }}',
          },
          project: appProject,
          source: {
            path: this.source_path_,
            repoURL: this.repo_,
            [if this.initial_revision_ != '' then 'targetRevision']: this.initial_revision_,
            plugin: {
              name: 'kubecfg',
              env: ok.envList(this.env_) + [
                { name: 'NAMESPACE', value: this.namespace_ },
                { name: 'MANIFESTPATH', value: '/tmp/git@github.com_getoutreach_%(name)s/%(path)s' % { name: this.repo_name_, path: this.path_ } },
              ],
            },
          },
          syncPolicy: {
            automated: {
              prune: true,
              selfHeal: false,
            },
            syncOptions: [
              'CreateNamespace=true',
              'ApplyOutOfSyncOnly=true',
            ],
          },
        },
      },
    },
  },
  // CanaryDeployment is Argo Rollout with canary strategy and template spec from a given deployment object
  CanaryDeployment(name, version, namespace, app=name): ok._Object('argoproj.io/v1alpha1', 'Rollout', name, app=app, namespace=namespace) {
    local this = self,
    deploymentRef:: error 'deploymentRef required',
    previewService:: error 'previewService required',
    stableService:: error 'stableService required',
    steps:: error 'steps requried',
    ingress:: {},
    servicePort:: 8080,
    backgroundAnalysis:: {},

    spec+: {
      revisionHistoryLimit: 3,
      selector: {
        matchLabels: {
          [if app != null then 'app']: app,
          [if app != null && namespace == 'kube-system' then 'k8s-app']: app,
        },
      },
      workloadRef: ok.CrossVersionObjectReference(this.deploymentRef),
      strategy: {
        canary: {
          canaryService: this.previewService.metadata.name,
          stableService: this.stableService.metadata.name,
          [if std.isObject(this.backgroundAnalysis) then 'analysis']: this.backgroundAnalysis,
          steps: this.steps,
          [if std.isObject(this.ingress) then 'trafficRouting']: {
            alb: {
              ingress: this.ingress.metadata.name,
              servicePort: this.servicePort,
            },
          },
        },
      },
    },
  },

  // AnalysisTemplate is Argo Rollout analysis based template with default arguments, app name, version and bento
  AnalysisTemplate(name, app): ok._Object('argoproj.io/v1alpha1', 'AnalysisTemplate', name, app=app.name, namespace=app.namespace) {
    local this = self,
    metrics:: error 'metrics required',
    spec: {
      args: [
        { name: 'app', value: app.name },
        { name: 'version', value: app.version },
        { name: 'bento', value: app.bento },
      ],
      metrics: this.metrics,
    },
  },

  // AnalysisTemplateRef references Analysis Template in Argo Rollouts
  AnalysisTemplateRef(analysisTemplate): {
    assert std.isObject(analysisTemplate) : 'analysisTemplate cannot be empty',
    templateName: analysisTemplate.metadata.name,
  },

  // AnalysisMetric is metric based template for AnalysisTemplate
  AnalysisMetric(name): {
    local this = self,
    name: name,
    consecutiveErrorLimit: 2,
    failureLimit: 3,
    interval: "5m",
    successCondition: error 'successCondition required',
  },

  // AnalysisMetricDatadog is a AnalysisTemplate metric with datadog provider
  AnalysisMetricDatadog(name): $.AnalysisMetric(name) {
    local this = self,
    query:: error 'query required',
    
    provider: {
      datadog: {
        query: this.query,
      },
    },
  },

  // AnalysisMetricWeb is a AnalysisTemplate metric with web provider
  AnalysisMetricWeb(name): $.AnalysisMetric(name) {
    local this = self,
    url:: error 'url required',
    jsonPath:: error 'jsonPath required',

    provider: {
      web: {
        url: this.url,
        jsonPath: this.jsonPath,
      },
    },
  },

  // AnalysisMetricJob is a AnalysisTemplate metric with job provider
  AnalysisMetricJob(name): $.AnalysisMetric(name) {
    local this = self,
    job:: error 'job required',
    provider: {
      job: this.job,
    },
  },
}
