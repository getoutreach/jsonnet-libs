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
      on_success_:: {},
      on_success: self.on_success_,
      on_failure_:: {},
      on_failure: self.on_failure_,
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
      },
    ]),

  // Update Github
  updateGithub(
    name = 'Step',
    state = 'success',
    pr = false,
    desc = null,
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
      require_name:: if name == null then error '`name` paramater is required!',
      name: if pr then name + '-pr' else name,
      type: 'docker-image',
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
  std.prune([
    if semver != null then $.getSemver(params = semver),
    {
      put: if pr then name + '-pr' else name,
      params: {
        build: source,
        tag: tag_file,
        [if additional_tags_file != null then 'additional_tags']: additional_tags_file,
        tag_as_latest: if pr then false else latest,
        [if build_args != null then 'build_args']: build_args,
      },
      [if semver != null then 'on_success']: {
        put: 'version',
        params: {
          file: 'version/version',
        },
      },
    },
  ]),

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

  // Slack Message
  slackMessage(
    type = 'success',
    title,
    text,
    channel = '#botland',
    color = null,
    inputs = [],
  )::
    local status_color = if color != null then color
      else if type == 'success' then 'good'
      else if type == 'failure' then 'danger'
      else null;
    local custom_inputs = std.prune(std.map(function(i) if i.name != null then { name: i.name, optional: true}, inputs));
    local custom_fields = std.filter(function(i) if i.title != null && i.value != null then true else false, inputs) + [
      {
        title: 'Project',
        value: '${BUILD_PIPELINE_NAME}',
        short: true,
      }
    ];
    [
      {
        task: type + '_payload',
        config: {
          platform: 'linux',
          image_resource: {
            type: 'docker-image',
            source: {
              repository: 'registry.outreach.cloud/alpine/tools',
              tag: 'latest',
              username: $.outreach_registry_username,
              password: $.outreach_registry_password,
            },
          },
          params: {
            STATUS_TITLE: title,
            STATUS_TEXT: text,
            STATUS_COLOR: status_color,
          },
          inputs: [{ name: 'metadata' }] + custom_inputs,
          outputs: [{ name: 'status' }],
          run: {
            path: 'bash',
            args: [
              '-c',
              |||
                set -euf -o pipefail
                export ATC_EXTERNAL_URL=$(cat metadata/atc_external_url)
                export BUILD_TEAM_NAME=$(cat metadata/build_team_name)
                export BUILD_PIPELINE_NAME=$(cat metadata/build_pipeline_name)
                export BUILD_JOB_NAME=$(cat metadata/build_job_name)
                export BUILD_ID=$(cat metadata/build_id)
                export BUILD_NAME=$(cat metadata/build_name)

                cat <<EOF > ./status/message.json
                [
                  {
                    "fallback": "${STATUS_TEXT}",
                    "color": "${STATUS_COLOR}",
                    "title": "${STATUS_TITLE}",
                    "title_link": "$ATC_EXTERNAL_URL/teams/$BUILD_TEAM_NAME/pipelines/$BUILD_PIPELINE_NAME/jobs/$BUILD_JOB_NAME/builds/$BUILD_NAME",
                    "text": "${STATUS_TEXT}",
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
    manifests = null,
    kubecfg_vars = {},
    semver = null,
  )::
    local vault = if vault_secrets != null || vault_configs != null then true else false;
    std.prune([
      if cluster_name == null then error '`cluster_name` parameter is required!',
      if namespace == null then error '`namespace` parameter is required!',

      { get: 'kubeconfig' },
      if semver != null then $.getSemver(params = semver),
      if vault then { get: 'vault' },
      if source != null then { get: source },
      {
        put: 'k8s_deploy',
        params: {
          cluster_name: cluster_name,
          namespace: namespace,
          kubeconfig_file: 'kubeconfig/config',
          [if vault then 'vault_token_file']: 'vault/token',
          [if vault && vault_secrets != null then 'vault_secrets_path']: vault_secrets,
          [if vault && vault_configs != null then 'vault_configs_path']: vault_configs,
          [if source != null && manifests != null then 'manifest_path']: source + '/' + manifests,
          kubecfg_variables: {
            namespace: namespace,
            cluster_name: cluster_name,
          } + kubecfg_vars,
        },
      },
    ]),
}