
# Cloud Native development environment tools (cloud-native)

Installs latest version of kubectl, Helm, kubelogin, azwi, flux and cilium cli. Auto-detects latest versions and installs needed dependencies.

## Example Usage

```json
"features": {
    "ghcr.io/rjfmachado/devcontainer-features/cloud-native:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| kubectl | Select or enter a kubectl version to install | string | latest |
| helm | Select or enter a Helm version to install | string | latest |
| kubelogin | Select or enter a kubelogin version to install | string | latest |
| azwi | Select or enter a Azure AD Workload Identity (azwi) cli version to install | string | latest |
| flux | Select or enter a Flux v2 cli version to install | string | latest |
| cilium | Select or enter a Cilium cli version to install | string | latest |



---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/rjfmachado/devcontainer-features/blob/main/src/cloud-native/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
