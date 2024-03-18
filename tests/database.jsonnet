local database = import 'kubernetes/database.libsonnet';

{
    assignment: database.PostgresqlClusterServiceAssignment(
        "custom-resource-instance-name",
        app="my-app",
        namespace="my-app--bento1a"
    ) {
        bento:: "bento1a",
        personal_information:: "yes",
        database_cluster_namespace:: "shared-databases--bento1a",
        database_cluster_name:: "my-shared-database",
        team:: "fnd-qss",
        tier:: "tier-2",
    },
}
