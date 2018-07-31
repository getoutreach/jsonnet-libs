// Library for building concourse pipelines
// Following this style guide (mostly): https://github.com/databricks/jsonnet-style-guide

local resources = import 'resources.libsonnet';
local templates = import 'templates.libsonnet';

local newPipeline(name, source_repo) = {
  // Configuration values
  name:: name,
  source_repo:: source_repo,
  github_key:: '((github-key))',
  github_access_token:: '((github-access-token))',
  outreach_registry_username:: '((outreach-registry-username))',
  outreach_registry_password:: '((outreach-registry-password))',
  aws_access_key_id:: '((aws-access-key-id))',
  aws_secret_access_key:: '((aws-secret-access-key))',
  slack_username:: 'concourse',
  slack_url:: '((slack-url))',

  // Pipeline output
  resource_types_:: [],
  resource_types: $.resourceTypesOutput + self.resource_types_,

  resources_:: [],
  resources: $.resourcesOutput + self.resources_,

  groups_:: [],
  groups: $.groupsOutput + self.groups_,
  
  jobs_:: [],
  jobs: self.jobs_,

  // Returns array of values from given object.  Does not include hidden fields.
  objectValues(o):: [o[field] for field in std.objectFields(o)],

  // Return a list of unique array elements
  uniq(arr)::
    std.foldl(
      function(a, b) (
        if std.setMember(std.md5(std.manifestJson(b)), [std.md5(std.manifestJson(i)) for i in a])
        then a
        else a + [b]
      ),
      arr,
      []
    ),

  // Convert do step to concourse compatible output
  do(steps):: { do: std.flattenArrays(steps) },

  // Convert steps to concourse compatible output
  steps(steps):: 
    local default_steps = [
      { get: 'metadata' },
    ];
    local steps_array(steps) = [
      if std.isObject(step) then [step] else step, for step in steps
    ];
    $.uniq(default_steps + std.flattenArrays(steps_array(steps))),

  // Read resources from job steps
  resourceList(steps)::
    local read(step) = {
      resource: [if type == 'get' || type == 'put' || type == 'image' then step[type] 
                for type in std.objectFields(step)],
    };
    std.set(std.flattenArrays([
      std.prune(read(step).resource)
      for step in steps
    ])),

  // List of resources used in all jobs
  usedResources:: std.set(std.flattenArrays(std.prune(
    std.map(
      function(j) $.resourceList(j.plan),
      $.jobs
    ) +
    std.map(
      function(j) if std.objectHas(j, 'on_success') then $.resourceList(j.on_success.do)
                  else if std.objectHas(j, 'on_failure') then $.resourceList(j.on_success.do),
      $.jobs
    )
    ))),

  // Concourse formatted 'resources' output
  resourcesOutput:: std.prune([
      if std.objectHas($.basicResources, r) then $.basicResources[r] for r in $.usedResources
    ]),

  // Concourse formatted 'resource_types' output
  resourceTypesOutput:: std.prune([
      if std.objectHas($.basicResourceTypes, r) then $.basicResourceTypes[r] for r in $.usedResources
    ]),

  // Concourse formatted 'groups' output
  // TODO: error if only some jobs have groups
  groupsOutput::
    local groups = std.set(std.prune(std.map(
      function(j) if j.group != null then j.group,
      $.jobs
    )));
    [
      {
        name: g,
        jobs: std.prune(std.map(
          function(j) if j.group == g then j.name,
          $.jobs
        )),
      }
      for g in groups
    ],
}
+ resources
+ templates;

{
  newPipeline:: newPipeline,
}