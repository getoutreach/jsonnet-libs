local ok = import 'kubernetes/outreach.libsonnet';
local crossplane = import 'kubernetes/crossplane.libsonnet';

local name = 'postgres';

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
	awsAccountID: {type: "string"},
	eksOIDC: {type: "string"},
};

local all = {

	crd: crossplane.CompositeResourceDefinition(name, customConfig, customRequired, customStatus) {
	},
};

ok.List() { items_: all }