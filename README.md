# jsonnet-libs
Libraries to help simplify Outreach manifests

## Use Jsonnet to deploy to Kubernetes

To deploy to Kubernetes we use kubecfg, it natively supports jsonnet and helps simplify and standardize the way we build our manifests.

### Install kubecfg

```Bash
brew install kubecfg
```

### Create your K8s manifest

You can use the jsonnet manifests in the `concourse-example` repo as an example:

https://github.com/getoutreach/concourse-example/blob/master/k8s/manifests/deployment.jsonnet

### Render your K8s manifest

```Bash
kubecfg \
--jurl http://k8s-clusters.outreach.cloud/ \
--jurl https://raw.githubusercontent.com/getoutreach/jsonnet-libs/master \
show deployment.jsonnet
```

***

## Use Jsonnet to create a Concourse pipeline

We use Jsonnet to simplify and templatize our configurations, in this example we use it to create a concourse pipeline.

### Install jsonnet

```Bash
brew install jsonnet
```

### Create a your Concourse pipeline

You can use the jsonnet pipeline in the `concourse-example` repo as an example:

https://github.com/getoutreach/concourse-example/blob/master/ci/pipeline.jsonnet

### Render your Concourse pipeline

```Bash
git clone git@github.com:getoutreach/jsonnet-libs.git /tmp/jsonnet-libs
jsonnet -J /tmp/jsonnet-libs -y pipeline.jsonnet
```

### Testing
jsonnet files created under the `./tests` directory can be used to test libsonnet functions. The files will be rendered to identically named `.snap` files in the same directory.
Snapshots are regenerated each time the tests are run.
```sh
make test
```
