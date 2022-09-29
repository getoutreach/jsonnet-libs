local cluster = import '../kubernetes/cluster.libsonnet';
local ok = import '../kubernetes/outreach.libsonnet';
local infra = import '../kubernetes/outreach.libsonnet';

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
      tags+: infra.RequiredInfrastructureTags(app){
        name: tableName,
        team:: this.team,
        tier:: this.tier,
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

    spec:{
      forProvider+:{
        attributeDefinitions: this.attributeDefinitions,
        keySchema: this.keySchema,
        region: this.region,
        tags: infra.RequiredInfrastructureTags(app){
          name:: dynamoDBName,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  // Ref: https://doc.crds.dev/github.com/crossplane/provider-aws/iam.aws.crossplane.io/Role/v1beta1@v0.31.0
  awsIAMRole(name, app): ok._Object('iam.aws.crossplane.io/v1beta1', 'Role', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    assumeRolePolicyDocument:: error 'assumeRolePolicyDocument is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider:{
        assumeRolePolicyDocument+: this.assumeRolePolicyDocument,
        tags: infra.RequiredInfrastructureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  // REF: https://doc.crds.dev/github.com/crossplane/provider-aws/iot.aws.crossplane.io/Policy/v1alpha1@v0.31.0
  awsIAMPolicy(name, app): ok._Object('iam.aws.crossplane.io/v1beta1', 'Policy', name=name, app=app.name, namespace=app.namespace){
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

    spec: {
      forProvider+:{
        name: name,
        policy: this.policy,
        tags: infra.RequiredInfrastructureTags(app){
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

 # REF: https://doc.crds.dev/github.com/crossplane/provider-aws/iam.aws.crossplane.io/UserPolicyAttachment/v1beta1@v0.31.0
  awsIAMUserPolicyAttatchment(name, app): ok._Object('iam.aws.crossplane.io/v1beta1', 'RolePolicyAttachment', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider+:{

      },
    },
  },

  // REF: https://doc.crds.dev/github.com/crossplane/provider-aws/s3.aws.crossplane.io/Bucket/v1beta1@v0.31.0
  awsS3(name, app):  ok._Object('s3.aws.crossplane.io/v1beta1', 'Bucket', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    locationConstraint:: error 'locationConstraint is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec: {
      forProvider+:{
        locationConstraint: this.locationConstraint,
        tags: infra.RequiredInfrastructureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  // REF: https://doc.crds.dev/github.com/crossplane/provider-aws/route53.aws.crossplane.io/HostedZone/v1alpha1@v0.31.0
  awsroute53HostedZone(name, app):  ok._Object('route53.aws.crossplane.io/v1alpha1', 'HostedZone', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec: {
      forProvider+:{
        name: name,
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/route53.aws.crossplane.io/ResourceRecordSet/v1alpha1@v0.31.0
  awsroute53ResourceRecordSet(name, app):  ok._Object('route53.aws.crossplane.io/v1alpha1', 'ResourceRecordSet', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    type:: error 'type is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec: {
      forProvider+:{
        type: this.type,
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

     spec: {
      forProvider+:{
        name: this.name,
        region: this.region,
        type: this.type,
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/s3.aws.crossplane.io/BucketPolicy/v1alpha3@v0.31.0
  awsS3Policy(name, app):  ok._Object('s3.aws.crossplane.io/v1alpha3', 'BucketPolicy', name=name, app=app.name, namespace=app.namespace){
      local this = self,

      region:: error 'region is required',
      importFrom:: '',

      metadata+: {
        annotations+: {
          [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
        },
      },

      spec: {
        forProvider+:{
          region: this.region,
        },
      },
    },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/ec2.aws.crossplane.io/VPC/v1beta1@v0.31.0
  awsEC2VPC(name, app):  ok._Object('ec2.aws.crossplane.io/v1beta1', 'VPC', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    cidrBlock:: error 'cidrBlock is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

     spec: {
      forProvider+:{
        cidrBlock: this.cidrBlock,
        tags: infra.RequiredInfrastructureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/ec2.aws.crossplane.io/Subnet/v1beta1@v0.31.0
  awsEC2Subnet(name, app):  ok._Object('ec2.aws.crossplane.io/v1beta1', 'Subnet', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    cidrBlock:: error 'cidrBlock is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider+:{
        cidrBlock: this.cidrBlock,
        tags: infra.RequiredInfrastructureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/ec2.aws.crossplane.io/SecurityGroup/v1beta1@v0.31.0
  awsEC2SecurityGroup(name, app):  ok._Object('ec2.aws.crossplane.io/v1beta1', 'SecurityGroup', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    description:: error 'description is required',
    groupName:: error 'groupName is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider+:{
        description: this.description,
        groupName: this.groupName,
        tags: infra.RequiredInfrastructureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/cache.aws.crossplane.io/CacheSubnetGroup/v1alpha1@v0.31.0
  awsElasticCacheSubnetGroup(name, app):  ok._Object('cache.aws.crossplane.io/v1alpha1', 'CacheSubnetGroup', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    description:: error 'description is required',
    region:: error 'region is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider+:{
        description: this.description,
        region: this.region,
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/elasticache.aws.crossplane.io/CacheParameterGroup/v1alpha1@v0.31.0
  awsElasticCacheParameterGroup(name, app):  ok._Object('elasticache.aws.crossplane.io/v1alpha1', 'CacheParameterGroup', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    team:: error 'team is required',
    tier:: error 'tier is required',
    description:: error 'description is required',
    region:: error 'region is required',
    cacheParameterGroupFamily:: error 'cacheParameterGroupFamily is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider+:{
        description: this.description,
        cacheParameterGroupFamily: this.cacheParameterGroupFamily,
        region: this.region,
        tags: infra.RequiredInfrastructureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/cache.aws.crossplane.io/ReplicationGroup/v1beta1@v0.31.0
  awsElasticReplicationGroup(name, app):  ok._Object('cache.aws.crossplane.io/v1beta1', 'ReplicationGroup', name=name, app=app.name, namespace=app.namespace){
    local this = self,

    applyModificationsImmediately:: error 'applyModificationsImmediately is required',
    cacheNodeType:: error 'cacheNodeType is required',
    replicationGroupDescription:: error 'replicationGroupDescription is required',
    engine:: error 'engine is required',
    team:: error 'team is required',
    tier:: error 'tier is required',
    importFrom:: '',

    metadata+: {
      annotations+: {
        [if this.importFrom != '' then 'crossplane.io/external-name']: this.importFrom,
      },
    },

    spec: {
      forProvider+:{
        description: this.description,
        cacheNodeType: this.cacheNodeType,
        engine: this.engine,
        replicationGroupDescription: this.replicationGroupDescription,
        tags: infra.structureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },

  //REF: https://doc.crds.dev/github.com/crossplane/provider-aws/sns.aws.crossplane.io/Topic/v1beta1@v0.31.0
  awsSNSTopic(name, app):  ok._Object('sns.aws.crossplane.io/v1beta1', 'Topic', name=name, app=app.name, namespace=app.namespace){
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

    spec: {
      forProvider+:{
        name: name,
        region: this.region,
        tags: infra.structureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
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

    spec: {
      forProvider+:{
        alarmName: this.alarmName,
        comparisonOperator: this.comparisonOperator,
        evaluationPeriods: this.evaluationPeriods,
        region: this.region,
        tags: infra.structureTags(app){
          name:: name,
          team:: this.team,
          tier:: this.tier,
        },
      },
    },
  },
}
