local ok = import 'outreach.libsonnet';
local cluster = import 'cluster.libsonnet';

local all = {
  local name = 'test',
  local namespace = 'default',

  alb_ingress: ok.ALBIngress(name, namespace) {},
};

ok.List() { items_:: all }