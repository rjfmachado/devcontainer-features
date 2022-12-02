# cloud-native

A Visual Studio code devcontainer with a collection of tools to support Cloud Native development environments.

Installs latest version of:

* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [Helm](https://github.com/helm/helm/releases)
* [kubelogin](https://github.com/Azure/kubelogin/releases)
* [azwi](https://github.com/Azure/azure-workload-identity/releases)
* [flux](https://github.com/fluxcd/flux2/releases)
* [Cilium cli](https://github.com/cilium/cilium-cli/releases)

Auto-detects latest versions and installs needed dependencies.

## Usage


```
"features": {
    "ghcr.io/rjfmachado/devcontainer-features/cloud-native:1": {
        "kubectl": "latest",
        "helm": "none",
        "kubelogin": "0.0.22"
    }
}
```

