local ok = import 'kubernetes/outreach.libsonnet';
local crossplane = import 'kubernetes/crossplane.libsonnet';

local name = 'irsa';

//// Definition
local customConfig = {
	awsAccountID: {
		type: "string",
	},
	eksOIDC: {
		type: "string",
	},
	permissionsBoundaryArn: {
		type: "string",
	},
	policyArns: {
		items: {
			type: "string",
		},
		type: "array",
	},
	policy: {
		type: "string",
	},
};

local customRequired = [
	"awsAccountID",
];

local customStatus = {
	roleArn: {type: "string"},
	roleName: {type: "string"},
	eksOIDC: {type: "string"},
};

//// Composition
local resources = {
	"iam-role": {
		apiVersion: "iam.aws.upbound.io/v1beta1",
		kind: "Role",
		spec: {
			"forProvider": {
				"assumeRolePolicy": ""
			}
		},
		patchCommonFields: true,
		patches: [
			{
				"type": "FromEnvironmentFieldPath",
				"fromFieldPath": "awsAccountID",
				"toFieldPath": "metadata.annotations[crossplane.io/awsaccountid]"
			},
			{
				"type": "ToCompositeFieldPath",
				"fromFieldPath": "metadata.annotations[crossplane.io/awsaccountid]",
				"toFieldPath": "status.awsAccountID",
				"policy": {
					"fromFieldPath": "Required"
				}
			},
			{
				"type": "FromEnvironmentFieldPath",
				"fromFieldPath": "eksOIDC",
				"toFieldPath": "metadata.annotations[crossplane.io/eksoidc]"
			},
			{
				"type": "ToCompositeFieldPath",
				"fromFieldPath": "metadata.annotations[crossplane.io/eksoidc]",
				"toFieldPath": "status.eksOIDC",
				"policy": {
					"fromFieldPath": "Required"
				}
			},
			{
				"type": "ToCompositeFieldPath",
				"fromFieldPath": "status.atProvider.arn",
				"toFieldPath": "status.roleArn"
			},
			{
				"type": "ToCompositeFieldPath",
				"fromFieldPath": "status.atProvider.arn",
				"toFieldPath": "status.roleName",
				"transforms": [
					{
						"type": "string",
						"string": {
							"type": "Regexp",
							"regexp": {
								"match": "arn:aws:iam::(\\d+):role/(.*)",
								"group": 2
							}
						}
					}
				]
			},
			{
				"type": "FromCompositeFieldPath",
				"fromFieldPath": "spec.permissionsBoundaryArn",
				"toFieldPath": "spec.forProvider.permissionsBoundary"
			},
			{
				"type": "CombineFromComposite",
				"toFieldPath": "spec.forProvider.assumeRolePolicy",
				"combine": {
					"variables": [
						{
							"fromFieldPath": "status.awsAccountID"
						},
						{
							"fromFieldPath": "status.eksOIDC"
						},
						{
							"fromFieldPath": "status.eksOIDC"
						},
						{
							"fromFieldPath": "status.eksOIDC"
						},
						{
							"fromFieldPath": "metadata.labels[crossplane.io/claim-namespace]"
						},
						{
							"fromFieldPath": "spec.serviceAccountName"
						}
					],
					"strategy": "string",
					"string": {
						"fmt": std.manifestJsonEx(self.trusted_policy_, '  '),
            trusted_policy_:: [
              {
                Version: "2012-10-17",
								Statement: [
									{
										Effect: "Allow",
										Principal: {
											Federated: "arn:aws:iam::%s:oidc-provider/%s"
											},
										Action: "sts:AssumeRoleWithWebIdentity",
										Condition: {
											StringEquals: {
												"%s:aud": "sts.amazonaws.com",
												"%s:sub": "system:serviceaccount:%s:%s"
											}
										}
									}
								]
							}
            ],
					}
				}
			}
		]
	},
	"service-account": {
		apiVersion: "kubernetes.crossplane.io/v1alpha1",
		kind: "Object",
		spec: {
			"forProvider": {
				"manifest": {
					"apiVersion": "v1",
					"kind": "ServiceAccount",
					"metadata": {
						"name": "",
						"namespace": "default",
						"annotations": {
							"eks.amazonaws.com/role-arn": ""
						}
					}
				}
			}
		},
		patchCommonFields: false,
		patches: [
			{
				"type": "FromCompositeFieldPath",
				"fromFieldPath": "metadata.labels[crossplane.io/claim-namespace]",
				"toFieldPath": "spec.forProvider.manifest.metadata.namespace"
			},
			{
				"type": "FromCompositeFieldPath",
				"fromFieldPath": "spec.serviceAccountName",
				"toFieldPath": "spec.forProvider.manifest.metadata.name"
			},
			{
				"type": "FromCompositeFieldPath",
				"fromFieldPath": "status.roleArn",
				"toFieldPath": "spec.forProvider.manifest.metadata.annotations[eks.amazonaws.com/role-arn]",
				"policy": {
					"fromFieldPath": "Required"
				}
			}
		]
	}
};

local all = {

	crd: crossplane.CompositeResourceDefinition(name, customConfig, customRequired, customStatus) {},

	composition: crossplane.composition(name, resources)
};

ok.List() { items_: all }