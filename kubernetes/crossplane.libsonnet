local ok = import 'outreach.libsonnet';

// namespace for crossplane
local crossplaneNamespace = 'crossplane-system';

{
  // DEPRECATED: Use crossplaneApplication instead.
  CompositeResourceDefinition(name, group='outreach.io', apiversion='v1'): ok._Object('apiextensions.crossplane.io/v1', 'CompositeResourceDefinition', 'x%s.%s' % [name, group] ) {
    local this = self,
		local uppername = name,
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
  },
}
