// Basic resources for Concourse

{
  // Basic resource types
  basicResourceTypes:: {
    slack_message: {
      name: 'slack_message',
      type: 'docker-image',
      source: {
        repository: 'cfcommunity/slack-notification-resource',
        tag: 'latest',
      },
    },
    github_status: {
      name: 'github_status',
      type: 'docker-image',
      source: {
        repository: 'dpb587/github-status-resource',
        tag: 'master',
      },
    },
    pull_request: {
      name: 'pull_request',
      type: 'docker-image',
      source: {
        repository: 'jtarchie/pr',
      },
    },
    metadata: {
      name: 'metadata',
      type: 'docker-image',
      source: {
        repository: 'olhtbr/metadata-resource',
      },
    },
    vault: {
      name: 'vault',
      type: 'docker-image',
      source: {
        repository: 'docurated/concourse-vault-resource',
      },
    },
    k8s_deploy: {
      name: 'k8s_deploy',
      type: 'docker-image',
      source: {
        repository: 'registry.outreach.cloud/concourse/k8s-deploy-resource',
        tag: 'latest',
        username: $.outreach_registry_username,
        password: $.outreach_registry_password,
      },
    },
  },

  // Basic resources
  basicResources:: {
    metadata: {
      name: 'metadata',
      type: 'metadata',
    },
    github_status: {
      name: 'github_status',
      type: 'github_status',
      source: {
        repository: $.source_repo,
        access_token: $.github_access_token,
        context: 'concourse-ci/status',
      },
    },
    source: {
      name: 'source',
      type: 'git',
      source: {
        uri: 'git@github.com:' + $.source_repo + '.git',
        branch: 'master',
        private_key: $.github_key,
      },
    },
    slack_message: {
      name: 'slack_message',
      type: 'slack_message',
      source: {
        url: $.slack_url,
      },
    },
    version: {
      name: 'version',
      type: 'semver',
      source: {
        initial_version: '1.0.0',
        bucket: 'outreach-concourse',
        key: $.name,
        region_name: 'us-west-2',
        access_key_id: $.aws_access_key_id,
        secret_access_key: $.aws_secret_access_key,
      },
    },
    task_image: {
      name: 'task_image',
      type: 'docker-image',
      source: {
        repository: 'registry.outreach.cloud/alpine/tools',
        tag: '1.2',
        username: $.outreach_registry_username,
        password: $.outreach_registry_password,
      },
    },
  },
}