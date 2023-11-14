local ok = import 'outreach.libsonnet';

// namespace for crossplane
local crossplaneNamespace = 'crossplane-system';

{
  // DEPRECATED: Use crossplaneApplication instead.
  CompositeResourceDefinition(name, group='outreach.io', apiversion='v1'): ok._Object('apiextensions.crossplane.io/v1', 'CompositeResourceDefinition', 'x%s.%s' % [name, group] ) {
    local this = self,
		local uppername = std.asciiUpper(name),
		local fullname = "%s.%s" % [name, group],
    // Copyright 2023 Outreach Corporation. All Rights Reserved.
    metadata+: {
  		name: fullname,
		},
		spec+: {
			claimNames: {
				kind: uppername,
				plural: "%ss" + name,
			},
			group: group,
			names: {
				kind: "x%s" % uppername,
				plural: "x%ss" % name,
			},
			versions: [
      {
        name: "v1alpha1",
        served: true,
        referenceable: true,
        schema: {
          openAPIV3Schema: {
            description: "%s is the Schema for the %ss API" % [uppername, name],
            properties: {
              spec: {
                description: "%s Spec defines the desired state of %s" % [uppername, uppername],
                properties: {
                  "awsAccountID": {
                    "type": "string"
                  },
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
                    "type": "object"
                  },
                },
                "required": [
                  "resourceConfig"
                ],
                "type": "object"
              },
              "status": {
                "description": "%s Status defines the observed state of %s" % (uppername, uppername),
                "properties": {
                },
                "type": "object"
              }
            },
            "type": "object"
          },
        },
      },
    ],
  },
}
