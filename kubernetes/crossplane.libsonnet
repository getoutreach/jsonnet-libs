local ok = import 'outreach.libsonnet';

// namespace for crossplane
local crossplaneNamespace = 'crossplane-system';

{
  // DEPRECATED: Use crossplaneApplication instead.
  CompositeResourceDefinition(name, customFields={}, customRequired=[], customStatus={}, group='outreach.io', apiversion='v1' ): ok._Object('apiextensions.crossplane.io/v1', 'CompositeResourceDefinition', 'x%s.%s' % [name, group] ) {
    local this = self,
		local uppername = name,
		local fullname = "%s.%s" % [name, group],
    
		local customConfig = {
			description: "customConfig defines custom properties of this XRD.",
			properties: customFields,
			required: customRequired,
			type: "object"
		},

		local customStatusConfig = {
			description: "%s Status defines the observed state of %s" % [uppername, uppername],
			properties: customStatus,
			type: "object",
		},

		metadata+: {
  		name: fullname,
		},
		spec: {
			claimNames: {
				kind: uppername,
				plural: "%ss" % name,
			},
			group: group,
			names: {
				kind: "x%s" % uppername,
				plural: "x%ss" % name,
			},
			versions: [
				{
					name: apiversion,
					served: true,
					referenceable: true,
					schema: {
						"openAPIV3Schema": {
							"description": "%s is the Schema for the %ss API" % [uppername, name],
							"properties": {
								"spec": {
									"description": "%s Spec defines the desired state of %s" % [uppername, uppername],
									"properties": {
										"resourceConfig": {
											"description": "ResourceConfig defines general properties of this AWS resource.",
											"properties": {
												"deletionPolicy": {
													"description": "Defaults to Delete",
													"enum": [
														"Delete",
														"Orphan"
													],
													"type": "string"
												},
												"name": {
													"description": "Set the name of this resource in AWS to the value provided by this field.",
													"type": "string"
												},
												"providerConfigName": {
													"type": "string"
												},
												"region": {
													"type": "string"
												},
												"tags": {
													"additionalProperties": {
														"type": "string"
													},
													"description": "Key-value map of resource tags.",
													"type": "object"
												}
											},
											"required": [
												"providerConfigName",
												"region"
											],
											"type": "object"
										},
										"customConfig": customConfig,
									},
									"required": [
										"resourceConfig",
										"customConfig"
									],
									"type": "object"
								},
								"status": customStatusConfig,
							},
							"type": "object"
						}
					}
				}
			],
		},
  },
}
