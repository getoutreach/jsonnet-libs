// Templates for basic usage of Concourse

{
  // Create Job
  newJob(name, group)::
    {
      name: name,
      group:: group,
      build_logs_to_retain: 100,
      plan_:: [],
      plan: self.plan_,
      on_success_:: {},
      on_success: self.on_success_,
      on_failure_:: {},
      on_failure: self.on_failure_,
    },

  // Get semver resource
  getSemver(params = null):: 
    { get: 'version', [if params != null then 'params']: params },

  // Template for running tasks from repo
  runTask(
    name = 'test',
    path = 'ci/tasks/test.yaml',
    pr = false,
    passed = null,
    trigger = true,
    image = null,
    semver = null,
  )::
    local git_source = if pr then 'source_pr' else 'source';
    std.prune([
      { get: git_source, trigger: trigger, [if passed != null then 'passed']: passed },
      if image != null then { get: image },
      if semver != null then $.getSemver(semver),
      {
        put: 'github_status',
        params: {
          state: 'pending',
          commit: git_source,
          description: 'Concourse CI ' + name + ' pending...',
        },
      },
      {
        task: name,
        [if image != null then 'image']: image,
        file: git_source + '/' + path
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
      {
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
    name = 'docker_image',
    repo = 'registry.outreach.cloud/outreach/' + name,
    tag = 'latest',
    username = null,
    password = null,
  )::
    {
      name: name,
      type: 'docker-image',
      source: {
        repository: repo,
        tag: tag,
        username: if username != null then username else $.outreach_registry_username,
        password: if username != null then password else $.outreach_registry_password,
      },
    },

  // Build docker image
  buildDockerImage(
    name = $.name,
    source = 'source',
    tag_file = 'version/version',
    latest = true,
    semver = { bump: 'patch' },
  )::
  std.prune([
    if semver != null then $.getSemver(semver),
    {
      put: name,
      params: {
        build: source,
        tag: tag_file,
        tag_as_latest: latest,
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
    name,
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
    local custom_inputs = std.map(function(i) { name: i.name, optional: true}, inputs);
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
  k8sDeploy()::
    [],
}