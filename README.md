# jsonnet-libs
Libraries to help simplify Outreach manifests

## Usage

### Install jsonnet

```Bash
brew install jsonnet
```

### Create a jsonnet manifest

```jsonnet
local k = import 'kubernetes/k.libsonnet';
```

### Render your manifest

```Bash
git clone git@github.com:getoutreach/jsonnet-libs.git /tmp/jsonnet-libs
jsonnet -J /tmp/jsonnet-libs manifest.jsonnet
```