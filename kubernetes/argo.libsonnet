local ok = import 'outreach.libsonnet';

// namespace for argocd
local argocdNamespace = 'argocd';

{
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
            { name: 'MANIFESTPATH', value: '/tmp/git@github.com_getoutreach_%(name)s/%(path)s' % { name: this.repo_name_, path: this.path_ } },
          ],
        },
      },
      syncPolicy: {
        automated: {
          prune: true,
        },
        syncOptions: ['ApplyOutOfSyncOnly=true', 'PruneLast=true'],
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
              selfHeal: true,
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
}
