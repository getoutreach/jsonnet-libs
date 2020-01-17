// Basic resources for Concourse

{
  // Basic resource types
  basicResourceTypes:: {
    // https://github.com/vito/oci-build-task
    build_task: {
      name: 'oci-build-task',
      type: 'registry-image',
      source: {
        repository: 'gcr.io/outreach-docker/concourse/vito/oci-build-task',
        tag: 'latest',
        username: $.gcr_registry_username,
        password: $.gcr_registry_password,
      },
    },
    // Deprecated but still in use until the oci-build-task works
    builder_task: {
      name: 'oci-build-task',
      type: 'registry-image',
      source: {
        repository: 'gcr.io/outreach-docker/concourse/builder',
        tag: 'latest',
        username: $.gcr_registry_username,
        password: $.gcr_registry_password,
      },
    },
    maestro: {
      name: 'maestro',
      type: 'registry-image',
      source: {
        repository: 'registry.outreach.cloud/maestro-resource',
        tag: 'latest',
        username: $.outreach_registry_username,
        password: $.outreach_registry_password,
      },
    },
    slack_message: {
      name: 'slack_message',
      type: 'registry-image',
      source: {
        repository: 'cfcommunity/slack-notification-resource',
        tag: 'latest',
      },
    },
    github_status: {
      name: 'github_status',
      type: 'registry-image',
      source: {
        repository: 'dpb587/github-status-resource',
        tag: 'master',
      },
    },
    source_pr: {
      name: 'source_pr',
      type: 'registry-image',
      source: {
        repository: 'jtarchie/pr',
      },
    },
    metadata: {
      name: 'metadata',
      type: 'registry-image',
      source: {
        repository: 'olhtbr/metadata-resource',
        tag: '1.0.0',
      },
    },
    vault: {
      name: 'vault',
      type: 'registry-image',
      source: {
        repository: 'registry.outreach.cloud/concourse/vault-resource',
        tag: 'latest',
        username: $.outreach_registry_username,
        password: $.outreach_registry_password,
      },
    },
    k8s_deploy: {
      name: 'k8s_deploy',
      type: 'registry-image',
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
    maestro: {
      name: 'maestro',
      type: 'maestro',
      source: {
        application: $.name,
        secret: $.maestro_secret,
      },
    },
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
      webhook_token: $.webhook_token,
    },
    source_pr: {
      name: 'source_pr',
      type: 'source_pr',
      source: {
        repo: $.source_repo,
        uri: 'git@github.com:' + $.source_repo + '.git',
        base: 'master',
        access_token: $.github_access_token,
        private_key: $.github_key,
      },
      webhook_token: $.webhook_token,
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
      webhook_token: $.webhook_token,
    },
    task_image: {
      name: 'task_image',
      type: 'registry-image',
      source: {
        repository: 'registry.outreach.cloud/alpine/tools',
        tag: '1.2',
        username: $.outreach_registry_username,
        password: $.outreach_registry_password,
      },
    },
    kubeconfig: {
      name: 'kubeconfig',
      type: 's3',
      source: {
        region_name: 'us-west-2',
        bucket: 'kubeconfig-files',
        versioned_file: 'config',
        access_key_id: $.aws_access_key_id,
        secret_access_key: $.aws_secret_access_key,
      },
    },
    vault: {
      name: 'vault',
      type: 'vault',
      source: {
        url: 'https://vault.outreach.cloud',
        tls_skip_verify: false,
        auth_method: 'AppRole',
        role_id: '((vault-role-id))',
        expose_token: true,
      },
    },
    k8s_deploy: {
      name: 'k8s_deploy',
      type: 'k8s_deploy',
      source: {
        vault_url: 'https://vault.outreach.cloud',
        vault_skip_verify: false,
      },
    },
  },
}
