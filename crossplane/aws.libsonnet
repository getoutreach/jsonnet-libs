local cluster = import '../kubernetes/cluster.libsonnet';
local ok = import '../kubernetes/outreach.libsonnet';
local infra = import '../kubernetes/infrastructure.libsonnet';

{
  NoSqlTable(tableName, app): ok._Object('databases.outreach.io/v1alpha1', 'NoSqlTable', name=tableName, app=app.name, namespace=app.namespace) {
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    pii:: 'no',
    dataClassification:: 'no',
    importFrom:: '',
    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },
    spec+: {
      parameters+: {
        billingMode: 'PAY_PER_REQUEST',
        region: cluster.region,
        keySchema: [],
        attributes: [],
        globalSecondaryIndexes: [],
      },
      compositionSelector+: {
        matchLabels: {
          provider: cluster.cloud_provider,
        },
      },
    },
  },

  DynamoDB(dynamoDBName, app): ok._Object('dynamodb.aws.crossplane.io/v1alpha1', 'Table', name=dynamoDBName, app=app.name, namespace=app.namespace) {
    local this = self,

    attributeDefinitions:: error 'attributeDefinitions is required',
    keySchema:: error 'keySchema is required',
    region:: error 'region is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    pii:: 'no',
    dataClassification:: 'no',
    importFrom:: '',

     metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec+:{
      forProvider+:{
        attributeDefinitions: this.attributeDefinitions,
        keySchema: this.keySchema,
        region: this.region,
      },
    },
  },

  // Ref: https://doc.crds.dev/github.com/crossplane/provider-aws/iam.aws.crossplane.io/Role/v1beta1@v0.31.0
  awsIAMRole(name, app): ok._Object('iam.aws.jet.crossplane.io/v1alpha2', 'Role', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    assumeRolePolicy:: error 'assumeRolePolicy is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec+: {
      forProvider:{
        assumeRolePolicy: this.assumeRolePolicy,
      },
    },
  },

  awsIAMPolicy(name, app): ok._Object('iam.aws.jet.crossplane.io/v1alpha2', 'Policy', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    policy:: error 'policy is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec+: {
      forProvider+:{
        name: name,
        policy: this.policy,
      },
    },
  },

 # REF: https://doc.crds.dev/github.com/crossplane/provider-aws/iam.aws.crossplane.io/UserPolicyAttachment/v1beta1@v0.31.0
  awsIAMUserPolicyAttatchment(name, app): ok._Object('iam.aws.jet.crossplane.io/v1alpha2', 'RolePolicyAttachment', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec+: {
      forProvider+:{

      },
    },
  },

  // REF: https://doc.crds.dev/github.com/crossplane/provider-aws/s3.aws.crossplane.io/Bucket/v1beta1@v0.31.0
  awsS3(name, app):  ok._Object('s3.aws.jet.crossplane.io/v1alpha2', 'Bucket', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    region:: error 'region is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec+: {
      forProvider+:{
        region: this.region,
      },
    },
  },

  awsroute53HostedZone(name, app):  ok._Object('route53.aws.jet.crossplane.io/v1alpha2', 'HostedZone', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    region:: error 'region is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec+: {
      forProvider+:{
        region: this.region,
      },
    },
  },

  awsroute53Record(name, app):  ok._Object('route53.aws.jet.crossplane.io/v1alpha2', 'Record', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    name:: error 'name is required',
    region:: error 'region is required',
    type:: error 'type is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec+: {
      forProvider+:{
        name: this.name,
        region: this.region,
        type: this.type,
      },
    },
  },

  awsS3Policy(name, app):  ok._Object('s3.aws.jet.crossplane.io/v1alpha1', 'BucketPolicy', name=name, app=app.name, namespace=app.namespace){
      local this = self,

      bucket:: error 'bucket is required',
      policy:: error 'policy is required',
      region:: error 'region is required',
      importFrom:: '',

      metadata+: {
        annotations+: {
          [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
        },
      },

      spec+: {
        forProvider+:{
          bucket: this.bucket,
          policy: this.policy,
          region: this.region,
        },
      },
    },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/sns.aws.crossplane.io/Topic/v1beta1@v0.31.0
  awsSNSTopic(name, app):  ok._Object('sns.aws.jet.crossplane.io/v1alpha1', 'Topic', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    region:: error 'region is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec+: {
      forProvider+:{
        name: name,
        region: this.region,
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane-contrib/provider-jet-aws/cloudwatch.aws.jet.crossplane.io/MetricAlarm/v1alpha1@v0.5.0-preview
  awsMetricAlarm(name, app):  ok._Object('cloudwatch.aws.jet.crossplane.io/v1alpha1', 'MetricAlarm', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    alarmName:: error 'alarmName is required',
    comparisonOperator:: error 'comparisonOperator is required',
    evaluationPeriods:: error 'evaluationPeriods is required',
    region:: error 'region is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec+: {
      forProvider+:{
        alarmName: this.alarmName,
        comparisonOperator: this.comparisonOperator,
        evaluationPeriods: this.evaluationPeriods,
        region: this.region,
      },
    },
  },
}
