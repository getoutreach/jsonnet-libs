// Templates for basic usage of Concourse

{
  // Create Job
  newJob(name, group=null, serial_groups=null)::
    {
      name: name,
      group:: group,
      [if serial_groups != null then 'serial_groups']: serial_groups,
      build_logs_to_retain: 100,
      plan_:: [],
      plan: self.plan_,
      on_success_:: null,
      on_failure_:: null,
    },

  // Get semver resource
  getSemver(trigger=false, passed=null, params=null)::
    {
      get: 'version',
      [if trigger then 'trigger']: trigger,
      [if passed != null then 'passed']: passed,
      [if params != null then 'params']: params,
    },

  // Get source from github
  getGitRepo(trigger=null, passed=null, pr=false)::
    local source = if pr then 'source_pr' else 'source';
    {
      get: source,
      [if trigger != null then 'trigger']: trigger,
      [if passed != null then 'passed']: passed,
    },

  // Template for running tasks from repo
  newTask(
    name='test',
    path='ci/tasks/test.yaml',
    pr=false,
    passed=null,
    trigger=true,
    image=null,
    semver=null,
    params=null,
    attempts=null,
    update=true,
    privileged=null,
    context='status',
    timeout=null,
  )::
    local source = if pr then 'source_pr' else 'source';
    local custom_params = {
      [if pr then 'PR']: true,
    } + if params != null then params else {};
    std.prune([
      $.getGitRepo(trigger, passed, pr),
      if image != null then { get: image },
      if semver != null then $.getSemver(params=semver),
      if pr && update then {
        put: source,
        params: {
          path: source,
          status: 'pending',
          context: context,
        },
      }
      else if update then {
        put: 'github_status',
        params: {
          state: 'pending',
          commit: source,
          description: 'Concourse CI ' + name + ' pending...',
        },
      },
      {
        task: name,
        [if image != null then 'image']: image,
        [if pr then 'input_mapping']: { source: source },
        params: custom_params,
        file: source + '/' + path,
        [if attempts != null then 'attempts']: attempts,
        [if privileged != null then 'privileged']: privileged,
        [if timeout != null then 'timeout']: timeout,
      },
    ]),

  // Template for running tasks inline
  newInlineTask(
    name,
    inputs=[],
    args=[],
    outputs=[],
  )::
    {
      task: name,
      config: {
        platform: 'linux',
        image_resource: $.basicResources.task_image { name:: null },
        inputs: inputs,
        outputs: outputs,
        run: {
          path: 'bash',
          args: ['-c'] + args,
        },
      },
    },

  // Update Github
  updateGithub(
    name='Step',
    state='success',
    pr=false,
    desc=null,
    context='status',
    comment=null,
  )::
    local source = if pr then 'source_pr' else 'source';
    local description = if desc != null then desc
    else if state == 'success' then 'Concourse CI ' + name + ' succeeded...'
    else if state == 'failure' then 'Concourse CI ' + name + ' failed...'
    else null;
    [
      if pr then {
        put: source,
        params: {
          path: source,
          status: state,
          context: context,
          [if comment != null then 'comment']: comment,
        },
      }
      else {
        put: 'github_status',
        params: {
          state: state,
          commit: source,
          description: description,
        },
      },
    ],

  // Docker image resource
  dockerImage(
    name=null,
    repo='registry.outreach.cloud/outreach/' + name,
    tag='latest',
    username=null,
    password=null,
    pr=false,
  )::
    {
      require_name:: if name == null then error '`name` parameter is required!',
      name: if pr then name + '-pr' else name,
      type: 'registry-image',
      source: {
        repository: repo,
        tag: if pr then tag + '-pr' else tag,
        username: if username != null then username else $.outreach_registry_username,
        password: if username != null then password else $.outreach_registry_password,
      },
    },

  // Docker image configuration for GCR
  gcrImage(
    name=null,
    repo='gcr.io/outreach-docker/' + name,
    tag='latest',
    username=null,
    password=null,
    pr=false,
  )::
    {
      require_name:: if name == null then error '`name` parameter is required!',
      name: if pr then name + '-pr' else name,
      type: 'registry-image',
      source: {
        repository: repo,
        tag: if pr then tag + '-pr' else tag,
        username: if username != null then username else $.gcr_registry_username,
        password: if username != null then password else $.gcr_registry_password,
      },
    },

  // Build and push docker images with specified tags
  imageBuildPush(
    name=$.name,
    source='source',
    tag_file='version/version',
    extra_tags=[],
    // https://github.com/vito/oci-build-task#params
    params={},
    build_args={},
  )::
    local build_args_rendered = std.map(
      function(k) '--build-arg ' + k + '="${' + k + '}"', std.objectFields(build_args)
    );

    std.prune([
      // Build image using the concourse oci-build-task
      {
        task: 'build-%s' % name,
        privileged: true,
        config: {
          platform: 'linux',
          image_resource: $.basicResourceTypes.builder_task { name:: null },
          params: {
            CONTEXT: source,
            REPOSITORY_USER: $.gcr_registry_username,
            REPOSITORY_PASS: $.gcr_registry_password,
            REPOSITORY: 'gcr.io/outreach-docker/%s' % name,
            OUTPUT: 'image',
            BUILD_ARGS: std.join(' ', build_args_rendered),
          } + params + build_args,
          inputs: [{ name: source }, { name: 'version', optional: true }],
          outputs: [{ name: 'image' }],
          run: {
            path: '/bin/bash',
            args: [
              '-c',
              |||
                echo ${REPOSITORY_PASS} | img login -u ${REPOSITORY_USER} --password-stdin https://gcr.io

                set -ex
                export TAG=$(cat %(tf)s)
                cat %(tf)s > image/tags
                echo -n " %(extra_tags)s" >> image/tags
                build
              ||| % {
                tf: tag_file,
                extra_tags: std.join(' ', extra_tags),
              },
            ],
          },
        },
      },

      // Push the built image to the registry with the tags specified
      {
        put: name,
        params: {
          image: 'image/image.tar',
          additional_tags: 'image/tags',
        },
      },
    ]),

  // Build docker image
  buildDockerImage(
    name=$.name,
    source='source',
    tag_file='version/version',
    additional_tags_file=null,
    latest=true,
    semver={ bump: 'patch' },
    build_args={},
    pr=false,
    repo=null,
  )::
    local pr_suffix = if pr then '-pr' else '';
    local real_name = name + pr_suffix;
    local builder_name = 'build-%s' % real_name;
    local real_repo = if repo != null then repo else 'registry.outreach.cloud/outreach/' + name;
    local output = '%s-image' % real_name;
    local latest_tag = if latest then 'latest' + pr_suffix else '';
    local tags_file = if additional_tags_file != null then additional_tags_file else tag_file;

    local build_args_rendered = std.map(
      function(k) '--build-arg ' + k + '="${' + k + '}"', std.objectFields(build_args)
    );

    std.prune([
      if semver != null then $.getSemver(params=semver),
      {
        task: builder_name,
        privileged: true,
        config: {
          platform: 'linux',
          image_resource: {
            type: 'registry-image',
            source: {
              repository: 'registry.outreach.cloud/concourse/builder',
              tag: 'latest',
              username: '((outreach-registry-username))',
              password: '((outreach-registry-password))',
            },
          },
          params: {
            REPOSITORY_USER: '((outreach-registry-username))',
            REPOSITORY_PASS: '((outreach-registry-password))',
            REPOSITORY: real_repo,
            OUTPUT: output,
            CONTEXT: source,
            BUILD_ARGS: std.join(' ', build_args_rendered),
          } + build_args,
          inputs: [{ name: source }, { name: 'version', optional: true }],
          outputs: [{ name: output }],
          caches: [{ path: 'cache' }],
          run: {
            path: 'bash',
            args: [
              '-c',
              |||
                img login -u ${REPOSITORY_USER} -p ${REPOSITORY_PASS} https://registry.outreach.cloud/v2/

                set -ex
                export TAG=$(cat %(t)s)

                # Add tag
                cat %(t)s > %(o)s/additional_tags

                # Add additional tags
                echo -n " $(cat %(tf)s)" >> %(o)s/additional_tags

                # Add latest tag
                echo -n " %(lt)s" >> %(o)s/additional_tags

                build
              ||| % {
                o: output,
                t: tag_file,
                tf: tags_file,
                lt: latest_tag,
              },
            ],
          },
        },
      },
      {
        put: real_name,
        params: {
          image: '%s/image.tar' % output,
          additional_tags: '%s/additional_tags' % output,
        },
        [if semver != null && pr != true then 'on_success']: {
          put: 'version',
          params: {
            file: 'version/version',
          },
        },
      },
    ]),

  // Deprecated method
  slackInput(
    name=null,
    title=null,
    text=null,
    short=true,
  )::
    {
      name:: name,
      title: title,
      value: text,
      short: short,
    },

  slackField():: {
    title: null,
    value: null,
    short: true,
  },

  // Slack Message
  slackMessage(
    type='success',
    title='Untitled',
    text=null,
    channel='#botland',
    color=null,
    inputs=[],  // Deprecated
    fields=[],
    resources=[],
  )::
    local status_color = if color != null then color
    else if type == 'success' then 'good'
    else if type == 'failure' then 'danger'
    else '#439FE0';
    local deprecated_inputs = std.prune(std.map(function(i) if i.name != null then { name: i.name, optional: true }, inputs));
    local custom_inputs = std.prune(std.map(function(resource) { name: resource, optional: true }, resources) + deprecated_inputs);
    local deprecated_fields = std.filter(function(i) if i.title != null && i.value != null then true else false, inputs);
    local custom_fields = std.filter(function(i) if i.title != null && i.value != null then true else false, fields) + deprecated_fields + [
      {
        title: 'Project',
        value: '${SLACK_BUILD_PIPELINE_NAME}',
        short: true,
      },
    ];
    [
      {
        task: type + '_payload',
        config: {
          platform: 'linux',
          image_resource: $.basicResources.task_image { name:: null },
          params: {
            STATUS_TITLE: title,
            [if text != null then 'STATUS_TEXT']: text,
            STATUS_COLOR: status_color,
          },
          inputs: [{ name: 'metadata' }] + custom_inputs,
          outputs: [{ name: 'status' }],
          run: {
            path: 'bash',
            args: [
              '-c',
              |||
                set -ef -o pipefail
                export SLACK_ATC_EXTERNAL_URL=$(cat metadata/atc_external_url)
                export SLACK_BUILD_TEAM_NAME=$(cat metadata/build_team_name)
                export SLACK_BUILD_PIPELINE_NAME=$(cat metadata/build_pipeline_name)
                export SLACK_BUILD_JOB_NAME=$(cat metadata/build_job_name)
                export SLACK_BUILD_ID=$(cat metadata/build_id)
                export SLACK_BUILD_NAME=$(cat metadata/build_name)

                if [ "${STATUS_TEXT}" = "" ]; then
                  export FALLBACK_TEXT="${STATUS_TITLE}"
                else
                  export FALLBACK_TEXT="${STATUS_TEXT}"
                  export TEXT="\"text\": \"${STATUS_TEXT}\","
                fi

                cat <<EOF > ./status/message.json
                [
                  {
                    "fallback": "${FALLBACK_TEXT}",
                    "color": "${STATUS_COLOR}",
                    "title": "${STATUS_TITLE}",
                    "title_link": "$SLACK_ATC_EXTERNAL_URL/teams/$SLACK_BUILD_TEAM_NAME/pipelines/$SLACK_BUILD_PIPELINE_NAME/jobs/$SLACK_BUILD_JOB_NAME/builds/$SLACK_BUILD_NAME",
                    ${TEXT}
                    "fields": %s
                  }
                ]
                EOF

                cat ./status/message.json
              ||| % std.manifestJson(custom_fields),
            ],
          },
        },
      },
      {
        put: 'slack_message',
        params: {
          channel: channel,
          username: $.slack_username,
          attachments_file: 'status/message.json',
        },
      },
    ],
  // Deploy manifest to kuberentes using Helm
  helmDeploy(
    cluster_name=null,
    namespace=null,
    create_namespace=true,
    chart=null,
    chart_path=null,
    version=null,
    values_file=null,
    override_values=[],
    debug=false,
    atomic=true,
    put_name='helm_deploy',
    params={},
    show_diff=true,
    timeout='5m0s',
    release=std.strReplace(chart, '/', '-'),
  )::
    std.prune([
      if cluster_name == null then error '`cluster_name` parameter is required!',
      if namespace == null then error '`namespace` parameter is required!',
      if chart == null && chart_path == null then error '`chart` or `chart_path` parameter is required!',
      if chart != null && chart_path != null then error 'either `chart` or `chart_path` parameter can be set!',
      if version == null && chart != null then error '`version` parameter is required!',
      { get: 'kubeconfig', attempts: 3 },
      {
        put: put_name,
        params: {
          chart: if chart_path != null then './source/%s' % chart_path else chart,
          version: version,
          override_values: override_values,
          namespace: namespace,
          create_namespace: create_namespace,
          debug: debug,
          kubeconfig_path: 'kubeconfig/config',
          kubecontext: cluster_name,
          atomic: atomic,
          timeout: timeout,
          show_diff: show_diff,
          release: release,
        } + params,
      },
    ]),
  // Deploy manifest to kuberentes
  k8sDeploy(
    cluster_name=null,
    namespace=null,
    vault_secrets=null,
    vault_configs=null,
    source='source',
    manifests=[],
    kubecfg_vars={},
    semver=null,
    debug=false,
    params={},
    validation_retries=null,
    job_validation_retries=null,
    put_name='k8s_deploy',
    on_success=null,
    on_failure=null,
  )::
    local vault = if vault_secrets != null || vault_configs != null then true else false;
    local secret_array = if std.isArray(vault_secrets) then vault_secrets else [vault_secrets];
    local config_array = if std.isArray(vault_configs) then vault_configs else [vault_configs];
    std.prune([
      if cluster_name == null then error '`cluster_name` parameter is required!',
      if namespace == null then error '`namespace` parameter is required!',

      { get: 'kubeconfig', attempts: 3 },
      if semver != null then ($.getSemver(params=semver) + { attempts: 3 }),
      if vault then { get: 'vault', attempts: 3 },
      if source != null then { get: source, attempts: 3 },
      {
        put: put_name,
        [if on_success != null then 'on_success']: on_success,
        [if on_failure != null then 'on_failure']: on_failure,
        params: {
          cluster_name: cluster_name,
          namespace: namespace,
          kubeconfig_file: 'kubeconfig/config',
          [if vault then 'vault_token_file']: 'vault/token',
          [if vault && vault_secrets != null then 'vault_secrets']: secret_array,
          [if vault && vault_configs != null then 'vault_configs']: config_array,
          [if source != null then 'manifest_paths']: if std.isArray(manifests) then std.map(function(p) source + '/' + p, manifests) else [source + '/' + manifests],
          [if validation_retries != null then 'validation_retries']: std.toString(validation_retries),
          [if job_validation_retries != null then 'job_validation_retries']: std.toString(job_validation_retries),
          kubecfg_variables: {
            namespace: namespace,
            cluster: cluster_name,
          } + kubecfg_vars,
          debug: debug,
        } + params,
      },
    ]),
  deploymentStartSlackMessage(name, target=null, slackChannel='#deployments')::
    local targetMessage = if target != null then ' to %s' % [target] else '';
    $.slackMessage(
      channel=slackChannel,
      type='notice',
      title=':airplane_departure: %s deployment%s is starting...' % [name, targetMessage],
      inputs=[
        $.slackInput(title='Deployment', text=name),
      ],
    ),
  deploymentSuccessfulSlackMessage(name, target=null, slackChannel='#deployments')::
    local targetMessage = if target != null then ' to %s' % [target] else '';
    $.slackMessage(
      channel=slackChannel,
      type='success',
      title=':airplane_arriving: %s deployment%s succeeded! :successkid:' % [name, targetMessage],
      inputs=[
        $.slackInput(title='Deployment', text=name),
      ],
    ),
  deploymentFailedSlackMessage(name, target=null, slackChannel='#deployments')::
    local targetMessage = if target != null then ' to %s' % [target] else '';
    $.slackMessage(
      channel=slackChannel,
      type='failure',
      title=':boom: %s deployment%s failed...' % [name, targetMessage],
      inputs=[
        $.slackInput(title='Deployment', text=name),
      ],
    ),
  maestroResource(name, deploy_name, resource):: {
    name: 'maestro-%s-%s' % [deploy_name, resource],
    type: 'maestrov3',
    source: {
      application: name,
      secret: $.maestro_secret,
      segmentName: deploy_name,
      resource: resource,
    },
  },
  helmResource(name, repo_url):: {
    name: 'helm_deploy',
    type: 'helm_deploy',
    source: {
      repos: [
        {
          name: name,
          url: repo_url,
        },
      ],
    },
  },
  maestroActionableVersion(name, deploy_name):: $.maestroResource(name, deploy_name, 'actionable_version'),
  maestroDeployedVersion(name, deploy_name):: $.maestroResource(name, deploy_name, 'deployed_version'),
  checkoutMaestroVersion(maestro_resource_name):: $.newInlineTask(
    'Checkout Maestro Version',
    [{ name: 'source' }, { name: maestro_resource_name }],
    [
      |||
        set -euf -o pipefail
        maestro_version=$(cat ./%s/version)
        cd source
        git checkout $maestro_version
      ||| % [maestro_resource_name],
    ],
    [{ name: 'source' }],
  ),

  // Sends OpsLevel Deployment Updates
  deploymentSuccessfulOpsLevelMessage(service, bento=null, env=null)::
    {
      task: 'Send OpsLevel Deploy Message',
      config: {
        platform: 'linux',
        image_resource: $.basicResources.task_image { name:: null },
        inputs: [{ name: 'metadata' }, { name: 'source' }],
        outputs: [],
        run: {
          path: '/bin/bash',
          args: [
            '-c',
            |||
              set -euf -o pipefail
              SERVICE=%s
              BENTO=%s
              ENV=%s
              OPSLEVEL_DEPLOY=/tmp/opslevel_deploy.json
              ATC_EXTERNAL_URL=$(cat metadata/atc_external_url)
              BUILD_TEAM_NAME=$(cat metadata/build_team_name)
              BUILD_PIPELINE_NAME=$(cat metadata/build_pipeline_name)
              BUILD_JOB_NAME=$(cat metadata/build_job_name)
              BUILD_ID=$(cat metadata/build_id)
              BUILD_NAME=$(cat metadata/build_name)
              cat <<EOF > $OPSLEVEL_DEPLOY
              {
                "dedup_id": "$BUILD_ID",
                "service": "$SERVICE",
                "deployer": {
                  "email": "$BUILD_TEAM_NAME@outreach.io"
                },
                "deployed_at": "$(date -u '+%%FT%%TZ')",
                "environment": "$ENV-$BENTO",
                "description": "Deployed by Concourse: $BUILD_PIPELINE_NAME#$BUILD_NAME",
                "deploy_url": "$ATC_EXTERNAL_URL/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME",
                "deploy_number": "$BUILD_ID"
              }
              EOF
              echo "OpsLevel Payload:"
              cat $OPSLEVEL_DEPLOY
              curl -X POST https://app.opslevel.com/integrations/deploy/6a9c1f3e-d708-4f00-99d8-c4831ee03f49 \
                -H 'content-type: application/json' \
                --data-binary @$OPSLEVEL_DEPLOY
            ||| % [service, bento, env],
          ],
        },
      },
    },

  // Sends GQL changes of subgraph to schema registry
  // Need to include { get: 'vault', params: { paths: [ 'deploy/graphql/schema-registry' ] } } step in pipeline
  GQLRegistryUpdate(service, schema_path, service_url, bento, env)::
    $.newInlineTask(
    'Send GQL subgraph changes to registry',
    [{ name: 'source' }, { name: 'vault' }],
    [
      |||
        set -euf -o pipefail

        export TOKEN=$(jq -r '.data.token' vault/deploy/graphql/schema-registry.json)
        export SCHEMA_NAME=$(jq -r '.data.name' vault/deploy/graphql/schema-registry.json)

        SERVICE=%s
        SCHEMA_PATH=%s
        SERVICE_URL=%s
        BENTO=%s
        ENV=%s

        curl -sSL https://rover.apollo.dev/nix/latest | sh

        APOLLO_KEY=service:$SCHEMA_NAME:$TOKEN \
          /root/.rover/bin/rover subgraph publish $SCHEMA_NAME@$BENTO \
          --schema $SCHEMA_PATH \
          --name $SERVICE \
          --routing-url $SERVICE_URL
      ||| % [service, schema_path, service_url, bento, env],
    ],
    [],
  ),
}
