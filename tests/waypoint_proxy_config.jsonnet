// Regression test for the incident where WaypointProxyConfig returned a plain
// {configmap:, podmonitor:} wrapper.
//
// Callers place the result at a key inside FilteredList().items_, whose `items`
// is a flat array. kubecfg matches the enclosing List (it has apiVersion+kind),
// stops recursing, and emits each items[] element VERBATIM. A kindless wrapper
// therefore reaches argocd-vault-plugin as a document with no `kind` and
// hard-fails every affected app with "Object 'Kind' is missing", so ArgoCD
// cannot sync them.
//
// The result must therefore be a kindful object -- a v1.List -- which survives
// AVP and is flattened back into the two real objects by ArgoCD's repo-server
// (GenerateManifests: obj.IsList() -> EachListItem).
local ok = import 'kubernetes/kube.libsonnet';

local wpc = ok.WaypointProxyConfig('test-waypoint', namespace='test-ns', team='test-team');

assert std.objectHas(wpc, 'kind') :
       'WaypointProxyConfig must return a kindful object (a v1.List), not a plain wrapper; ' +
       'a kindless result breaks argocd-vault-plugin with "Object \'Kind\' is missing"';
assert wpc.kind == 'List' : 'WaypointProxyConfig must return kind=List, got kind=%s' % [wpc.kind];

// Both real objects must still be present, and each must itself be kindful.
assert std.length(wpc.items) == 2 : 'expected 2 items, got %d' % [std.length(wpc.items)];
assert std.all([std.objectHas(i, 'kind') for i in wpc.items]) : 'every List item must have a kind';

// Rendered the way real apps consume it: nested inside the app's own List.
ok.FilteredList() {
  items_:: {
    waypointConfig: wpc,
  },
}
