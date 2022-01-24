// Client for interacting with discovery in jsonnet.
// Requires kubecfg --jurl https://discovery.outreach.cloud/ (must be before github, which 400s)
// Types: https://github.com/getoutreach/services/tree/main/pkg/discovery/web
{
  // GetBentos returns a []web.Bento
  GetBentos():: std.parseJson(importstr '/discovery/v1/bentos').bentos,

  // GetChannels returns a []web.Channel
  GetChannels():: std.parseJson(importstr '/discovery/v1/channels').channels,

  // GetBento returns a web.Bento from a given bento name
  GetBento(name):: std.filter(function(b) b.name == name, self.GetBentos()),

  // GetChannel returns a web.Channel from a given channel name
  GetChannel(name):: std.filter(function(b) b.name == name, self.GetChannels()),
}
