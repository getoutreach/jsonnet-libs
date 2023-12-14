local ok = import 'kubernetes/outreach.libsonnet';
local kube = import 'kubernetes/kube.libsonnet';

local name = 'irsa';
local namespace = 'irsa';
local query='test';

local all = {

	crd: kube.DatadogMetric(name, namespace){
		query::'test',
	},
};

ok.List() { items_: all }