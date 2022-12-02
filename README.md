# cloud-native

A Visual Studio code devcontainer with a collection of tools to support Cloud Native development environments.

Installs the following command line utilities:

* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [Helm](https://github.com/helm/helm/releases)
* [kubelogin](https://github.com/Azure/kubelogin/releases)
* [azwi](https://github.com/Azure/azure-workload-identity/releases)
* [flux](https://github.com/fluxcd/flux2/releases)
* [Cilium cli](https://github.com/cilium/cilium-cli/releases)

Auto-detects latest versions and installs needed dependencies.

## Usage

All the latest versions are installed by default. You can pin a specific version or specify latest or none if you wish to have the latest or skip the installation of any specific cli. Please see below for an example:

```
"features": {
    "ghcr.io/rjfmachado/devcontainer-features/cloud-native:1": {
        "kubectl": "latest",
        "helm": "none",
        "kubelogin": "0.0.22"
    }
}
```

## Contributors
<a href="https://github.com/rjfmachado/devcontainer-features/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=rjfmachado/devcontainer-features" />
</a>
