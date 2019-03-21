// Templates for basic usage of Concourse

{
  // Create Job
  newJob(name, group = null, serial_groups = null)::
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
  getSemver(trigger = false, passed = null, params = null)::
    {
      get: 'version',
      [if trigger then 'trigger']: trigger,
      [if passed != null then 'passed']: passed,
      [if params != null then 'params']: params
    },

  // Get source from github
  getGitRepo(trigger = null, passed = null, pr = false)::
    local source = if pr then 'source_pr' else 'source';
    {
      get: source,
      [if trigger != null then 'trigger']: trigger,
      [if passed != null then 'passed']: passed,
      [if pr then 'version']: 'every',
    },

  // Template for running tasks from repo
  newTask(
    name = 'test',
    path = 'ci/tasks/test.yaml',
    pr = false,
    passed = null,
    trigger = true,
    image = null,
    semver = null,
    params = null,
    attempts = null,
    update = true,
    privileged = null,
    context = 'status',
  )::
    local source = if pr then 'source_pr' else 'source';
    local custom_params = {
      [if pr then 'PR']: true,
    } + if params != null then params else {};
    std.prune([
      $.getGitRepo(trigger, passed, pr),
      if image != null then { get: image },
      if semver != null then $.getSemver(params = semver),
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
      },
    ]),

  // Template for running tasks inline
  newInlineTask(
    name,
    inputs = [],
    args = [],
    outputs = [],
  )::
    {
      task: name,
      config: {
        platform: 'linux',
        image_resource: {
          type: 'registry-image',
          source: {
            repository: 'registry.outreach.cloud/alpine/tools',
            tag: 'latest',
            username: '((outreach-registry-username))',
            password: '((outreach-registry-password))',
          },
        },
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
    name = 'Step',
    state = 'success',
    pr = false,
    desc = null,
    context = 'status',
    comment = null,
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
    name = null,
    repo = 'registry.outreach.cloud/outreach/' + name,
    tag = 'latest',
    username = null,
    password = null,
    pr = false,
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

  // Build docker image
  buildDockerImage(
    name = $.name,
    source = 'source',
    tag_file = 'version/version',
    additional_tags_file = null,
    latest = true,
    semver = { bump: 'patch' },
    build_args = null,
    pr = false,
  )::
    local real_name = if pr then name + '-pr' else name;
    local builder_name = 'build-%s' % real_name;
    local repo = 'registry.outreach.cloud/outreach/' + real_name;
    local output = '%s-image' % real_name;
    local latest_tag = if latest then 'latest' else '';
    local tags_file = if additional_tags_file != null then additional_tags_file else tag_file;

    std.prune([
      if semver != null then $.getSemver(params = semver),
      {
        task: builder_name,
        privileged: true,
        config: {
          platform: 'linux',
          image_resource: {
            type: 'registry-image',
            source: {
              repository: 'concourse/builder',
            },
          },
          params: {
            REPOSITORY: repo,
            CONTEXT: source,
          } + build_args,
          inputs: [{name: source}, {name: 'version', optional: true}],
          outputs: [{name: output}],
          caches: [{path: 'cache'}],
          run: {
            path: 'bash',
            args: [
              '-c',
              |||
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
          image: '%s-image' % real_name,
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
    name = null,
    title = null,
    text = null,
    short = true,
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
    type = 'success',
    title = 'Untitled',
    text = null,
    channel = '#botland',
    color = null,
    inputs = [], // Deprecated
    fields = [],
    resources = [],
  )::
    local status_color = if color != null then color
      else if type == 'success' then 'good'
      else if type == 'failure' then 'danger'
      else "#439FE0";
    local deprecated_inputs = std.prune(std.map(function(i) if i.name != null then { name: i.name, optional: true}, inputs));
    local custom_inputs = std.prune(std.map(function(resource) { name: resource, optional: true}, resources) + deprecated_inputs);
    local deprecated_fields = std.filter(function(i) if i.title != null && i.value != null then true else false, inputs);
    local custom_fields = std.filter(function(i) if i.title != null && i.value != null then true else false, fields) + deprecated_fields + [
      {
        title: 'Project',
        value: '${SLACK_BUILD_PIPELINE_NAME}',
        short: true,
      }
    ];
    [
      {
        task: type + '_payload',
        config: {
          platform: 'linux',
          image_resource: {
            type: 'registry-image',
            source: {
              repository: 'registry.outreach.cloud/alpine/tools',
              tag: 'latest',
              username: $.outreach_registry_username,
              password: $.outreach_registry_password,
            },
          },
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

  // Deploy manifest to kuberentes
  k8sDeploy(
    cluster_name = null,
    namespace = null,
    vault_secrets = null,
    vault_configs = null,
    source = 'source',
    manifests = [],
    kubecfg_vars = {},
    semver = null,
    debug = false,
    params = {},
    validation_retries = null,
    job_validation_retries = null,
  )::
    local vault = if vault_secrets != null || vault_configs != null then true else false;
    local secret_array = if std.isArray(vault_secrets) then vault_secrets else [vault_secrets];
    local config_array = if std.isArray(vault_configs) then vault_configs else [vault_configs];
    std.prune([
      if cluster_name == null then error '`cluster_name` parameter is required!',
      if namespace == null then error '`namespace` parameter is required!',

      { get: 'kubeconfig', attempts: 3 },
      if semver != null then ($.getSemver(params = semver) + { attempts: 3 }),
      if vault then { get: 'vault', attempts: 3 },
      if source != null then { get: source, attempts: 3 },
      {
        put: 'k8s_deploy',
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
}
