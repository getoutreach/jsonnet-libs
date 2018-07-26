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
jsonnet -J https://raw.githubusercontent.com/getoutreach/jsonnet-libs/master manifest.jsonnet
```