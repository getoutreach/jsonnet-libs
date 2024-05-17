local database = import 'kubernetes/database.libsonnet';

{
  db: database.PostgresqlDatabaseCluster(
    'dpotestresource',
    app='dpotestresource',
    namespace='dpotestresource--ngb-ss2-us-east-2',
    environment='staging',
  ) {
    database_name: 'dpotestresource',
    bento: 'ngb-ss2-us-east-2',
    engine: {
      version: '14.6',
      parameter_group_family: 'aurora-postgresql14',
    },
    instance_classes: {
      default: 'db.t4g.medium',
    },
    team: 'fnd-qss',
    tier: 'tier-2',
    personal_information: 'yes',
    temp_builtin_users: true,
    cluster_parameters: {
      default: [{
        Name: 'rds.logical_replication',
        Value: '1',
      }, {
        Name: 'wal_sender_timeout',
        Value: '300000',
      }, {
        Name: 'wal_receiver_timeout',
        Value: '300000',
      }, {
        Name: 'max_wal_senders',
        Value: '20',
      }],
    },
  },
  assignment: database.PostgresqlClusterServiceAssignment(
    'mydpotestservice',
    app='mydpotestservice',
    namespace='mydpotestservice--ngb-ss2-us-east-2'
  ) {
    bento: 'ngb-ss2-us-east-2',
    personal_information: 'yes',
    database_name: 'mydpotestservice',
    database_cluster_namespace: 'dpotestresource--ngb-ss2-us-east-2',
    database_cluster_name: 'dpotestresource',
    resource_name: 'myresource',
    team: 'fnd-qss',
    tier: 'tier-2',
  },
  assignment2: database.PostgresqlClusterServiceAssignment(
    'mydpotestservice2',
    app='mydpotestservice',
    namespace='mydpotestservice--ngb-ss2-us-east-2'
  ) {
    bento: 'ngb-ss2-us-east-2',
    personal_information: 'yes',
    database_name: 'mydpotestservice',
    database_cluster_namespace: 'dpotestresource--ngb-ss2-us-east-2',
    database_cluster_name: 'dpotestresource',
    team: 'fnd-qss',
    tier: 'tier-2',
  },
}
