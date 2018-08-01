local ok = import 'outreach.libsonnet';
local cluster = ok.cluster;

{
  alertmanager: {
    alert(name, severity, interval='1h'): {
      local this = self,
      expr: error 'expr required',
      summary:: error 'summary required',
      description:: this.summary,

      alert: name,
      'for': interval,
      severity:: severity,
      annotations+: {
        summary: this.summary,
        description: this.description,
      },
      labels+: {
        cluster: cluster.name,
        severity: severity,
      },
    },

    // PD + #alertmanager-critical
    critical(name, interval='1h'): self.alert(name, 'critical', interval=interval),
    // #alertmanager-warning
    warning(name, interval='1h'): self.alert(name, 'warning', interval=interval),
    // #alertmanager-info
    info(name, interval='1h'): self.alert(name, 'info', interval=interval),
  },
}
