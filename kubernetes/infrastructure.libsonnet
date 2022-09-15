
{
    RequiredInfrastructureTags(app): {
        local this = self,

        name:: error 'name is required',
        team:: error 'team is required',
        tier:: error 'tier is required',
        pii:: 'no',
        dataClassification:: 'none',    
        [
            {
                key: 'Name',
                value: this.name,
            },
            {
                key: 'outreach-team',
                value: this.team,
            },
            {
                key: 'outreach-environment',
                value: app.environment,
            },
            {
                key: 'outreach-application',
                value: app.name,
            },
            {
                key: 'outreach-bento',
                value: app.bento,
            },
            {
                key: 'outreach-tier',
                value: this.tier,
            },
            {
                key: 'outreach-k8s-cluster',
                value: app.cluster,
            },
            {
                key: 'outreach-data-classification',
                value: this.dataClassification,
            },
            {
                key: 'outreach-personal-information',
                value: this.pii,
            },
        ],
    },
}