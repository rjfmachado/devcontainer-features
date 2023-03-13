#!/usr/bin/env bash
set -e

# Clean up
rm -rf /var/lib/apt/lists/*

KUBECTL_VERSION="${KUBECTL:-"latest"}"
HELM_VERSION="${HELM:-"latest"}"
KUBELOGIN_VERSION="${KUBELOGIN:-"latest"}"
AZWI_VERSION="${AZWI:-"latest"}"
FLUX_VERSION="${FLUX:-"latest"}"
CILIUM_VERSION="${CILIUM:-"latest"}"

KUBECTL_SHA256="${KUBECTL_SHA256:-"automatic"}"
HELM_SHA256="${HELM_SHA256:-"automatic"}"
KUBELOGIN_SHA256="${KUBELOGIN_SHA256:-"automatic"}"
AZWI_SHA256="${AZWI_SHA256:-"automatic"}"
FLUX_SHA256="${FLUX_SHA256:-"automatic"}"
CILIUM_SHA256="${CILIUM_SHA256:-"automatic"}"
USERNAME=${USERNAME:-"automatic"}

HELM_GPG_KEYS_URI="https://raw.githubusercontent.com/helm/helm/main/KEYS"
GPG_KEY_SERVERS="keyserver hkp://keyserver.ubuntu.com:80
keyserver hkps://keys.openpgp.org
keyserver hkp://keyserver.pgp.com"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u ${CURRENT_USER} > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

USERHOME="/home/$USERNAME"
if [ "$USERNAME" = "root" ]; then
    USERHOME="/root"
fi

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

apt_get_update()
{
    if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
check_packages curl ca-certificates coreutils gnupg2 dirmngr bash-completion unzip
if ! type git > /dev/null 2>&1; then
    check_packages git
fi

architecture="$(uname -m)"
case $architecture in
    x86_64) architecture="amd64";;
    aarch64 | armv8*) architecture="arm64";;
    aarch32 | armv7* | armvhf*) architecture="arm";;
    i?86) architecture="386";;
    *) echo "(!) Architecture $architecture unsupported"; exit 1 ;;
esac

# Install kubectl, verify checksum
if [ "${KUBECTL_VERSION}" != "none" ] && ! type kubectl > /dev/null 2>&1; then
    echo "Downloading kubectl..."
    if [ "${KUBECTL_VERSION}" = "latest" ] || [ "${KUBECTL_VERSION}" = "lts" ] || [ "${KUBECTL_VERSION}" = "current" ] || [ "${KUBECTL_VERSION}" = "stable" ]; then
        KUBECTL_VERSION="$(curl -sSL https://dl.k8s.io/release/stable.txt)"
    else
        find_version_from_git_tags KUBECTL_VERSION https://github.com/kubernetes/kubernetes
    fi
    if [ "${KUBECTL_VERSION::1}" != 'v' ]; then
        KUBECTL_VERSION="v${KUBECTL_VERSION}"
    fi
    curl -sSL -o /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${architecture}/kubectl"
    chmod 0755 /usr/local/bin/kubectl
    if [ "$KUBECTL_SHA256" = "automatic" ]; then
        KUBECTL_SHA256="$(curl -sSL "https://dl.k8s.io/${KUBECTL_VERSION}/bin/linux/${architecture}/kubectl.sha256")"
    fi
    ([ "${KUBECTL_SHA256}" = "dev-mode" ] || (echo "${KUBECTL_SHA256} */usr/local/bin/kubectl" | sha256sum -c -))
    if ! type kubectl > /dev/null 2>&1; then
        echo '(!) kubectl installation failed!'
        exit 1
    fi
else
    if ! type kubectl > /dev/null 2>&1; then
        echo "Skipping kubectl."
    else
        echo "Kubectl already instaled"
    fi
fi

# If kubectl is installed, install completion
if type kubectl > /dev/null 2>&1; then
    # kubectl bash completion
    kubectl completion bash > /etc/bash_completion.d/kubectl

    # kubectl zsh completion
    if [ -e "${USERHOME}/.oh-my-zsh" ]; then
        mkdir -p "${USERHOME}/.oh-my-zsh/completions"
        kubectl completion zsh > "${USERHOME}/.oh-my-zsh/completions/_kubectl"
        chown -R "${USERNAME}" "${USERHOME}/.oh-my-zsh"
    fi
fi

# Install Helm, verify signature and checksum
if [ "${HELM_VERSION}" != "none" ] && ! type helm > /dev/null 2>&1; then
    echo "Downloading Helm..."
    find_version_from_git_tags HELM_VERSION "https://github.com/helm/helm"
    if [ "${HELM_VERSION::1}" != 'v' ]; then
        HELM_VERSION="v${HELM_VERSION}"
    fi
    mkdir -p /tmp/helm
    helm_filename="helm-${HELM_VERSION}-linux-${architecture}.tar.gz"
    tmp_helm_filename="/tmp/helm/${helm_filename}"
    curl -sSL "https://get.helm.sh/${helm_filename}" -o "${tmp_helm_filename}"
    curl -sSL "https://github.com/helm/helm/releases/download/${HELM_VERSION}/${helm_filename}.asc" -o "${tmp_helm_filename}.asc"
    export GNUPGHOME="/tmp/helm/gnupg"
    mkdir -p "${GNUPGHOME}"
    chmod 700 ${GNUPGHOME}
    curl -sSL "${HELM_GPG_KEYS_URI}" -o /tmp/helm/KEYS
    echo -e "disable-ipv6\n${GPG_KEY_SERVERS}" > ${GNUPGHOME}/dirmngr.conf
    gpg -q --import "/tmp/helm/KEYS"
    if ! gpg --verify "${tmp_helm_filename}.asc" > ${GNUPGHOME}/verify.log 2>&1; then
        echo "Verification failed!"
        cat /tmp/helm/gnupg/verify.log
        exit 1
    fi
    if [ "${HELM_SHA256}" = "automatic" ]; then
        curl -sSL "https://get.helm.sh/${helm_filename}.sha256" -o "${tmp_helm_filename}.sha256"
        curl -sSL "https://github.com/helm/helm/releases/download/${HELM_VERSION}/${helm_filename}.sha256.asc" -o "${tmp_helm_filename}.sha256.asc"
        if ! gpg --verify "${tmp_helm_filename}.sha256.asc" > /tmp/helm/gnupg/verify.log 2>&1; then
            echo "Verification failed!"
            cat /tmp/helm/gnupg/verify.log
            exit 1
        fi
        HELM_SHA256="$(cat "${tmp_helm_filename}.sha256")"
    fi
    ([ "${HELM_SHA256}" = "dev-mode" ] || (echo "${HELM_SHA256} *${tmp_helm_filename}" | sha256sum -c -))
    tar xf "${tmp_helm_filename}" -C /tmp/helm
    mv -f "/tmp/helm/linux-${architecture}/helm" /usr/local/bin/
    chmod 0755 /usr/local/bin/helm
    rm -rf /tmp/helm
    if ! type helm > /dev/null 2>&1; then
        echo '(!) Helm installation failed!'
        exit 1
    fi
else
    if ! type helm > /dev/null 2>&1; then
        echo "Skipping helm."
    else
        echo "Helm already instaled"
    fi
fi

# If helm is installed, install completion
if type helm > /dev/null 2>&1; then
    # helm bash completion
    helm completion bash > /etc/bash_completion.d/helm
fi


# Install kubelogin, verify checksum
if [ "${KUBELOGIN_VERSION}" != "none" ] && ! type kubelogin > /dev/null 2>&1; then

    echo "Downloading kubelogin..."

    find_version_from_git_tags KUBELOGIN_VERSION https://github.com/Azure/kubelogin
    if [ "${KUBELOGIN_VERSION::1}" != 'v' ]; then
        KUBELOGIN_VERSION="v${KUBELOGIN_VERSION}"
    fi

    curl -sSL -o /tmp/kubelogin-linux-amd64.zip "https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-${architecture}.zip"

    if [ "$KUBELOGIN_SHA256" = "automatic" ]; then
        KUBELOGIN_SHA256="$(curl -sSL "https://github.com/Azure/kubelogin/releases/download/${KUBELOGIN_VERSION}/kubelogin-linux-${architecture}.zip.sha256" | cut -f1 -d' ')"
    fi
    ([ "${KUBECTL_SHA256}" = "dev-mode" ] || (echo "${KUBELOGIN_SHA256} */tmp/kubelogin-linux-amd64.zip" | sha256sum -c -))
    unzip -j -qq /tmp/kubelogin-linux-amd64.zip -d /usr/local/bin/
    chmod 0755 /usr/local/bin/kubelogin
    rm /tmp/kubelogin-linux-amd64.zip
    if ! type kubelogin > /dev/null 2>&1; then
        echo '(!) kubelogin installation failed!'
        exit 1
    fi
else
    if ! type kubelogin > /dev/null 2>&1; then
        echo "Skipping kubelogin."
    else
        echo "Kubelogin already instaled"
    fi
fi

# Install az worload identity, verify checksum
if [ "${AZWI_VERSION}" != "none" ] && ! type azwi > /dev/null 2>&1; then

    echo "Downloading azwi..."

    find_version_from_git_tags AZWI_VERSION https://github.com/Azure/azure-workload-identity
    if [ "${AZWI_VERSION::1}" != 'v' ]; then
        AZWI_VERSION="v${AZWI_VERSION}"
    fi

    curl -sSL -o /tmp/azwi-${AZWI_VERSION}-linux-${architecture}.tar.gz "https://github.com/Azure/azure-workload-identity/releases/download/${AZWI_VERSION}/azwi-${AZWI_VERSION}-linux-${architecture}.tar.gz"

    if [ "$AZWI_SHA256" = "automatic" ]; then
        AZWI_SHA256="$(curl -sSL "https://github.com/Azure/azure-workload-identity/releases/download/${AZWI_VERSION}/sha256sums.txt" | grep azwi-${AZWI_VERSION}-linux-${architecture}.tar.gz | cut -f1 -d' ')"
    fi
    ([ "${AZWI_SHA256}" = "dev-mode" ] || (echo "${AZWI_SHA256} */tmp/azwi-${AZWI_VERSION}-linux-${architecture}.tar.gz" | sha256sum -c -))
    tar -xf /tmp/azwi-${AZWI_VERSION}-linux-${architecture}.tar.gz --directory /usr/local/bin/
    chmod 0755 /usr/local/bin/azwi
    rm /tmp/azwi-${AZWI_VERSION}-linux-${architecture}.tar.gz
    if ! type azwi > /dev/null 2>&1; then
        echo '(!) azwi installation failed!'
        exit 1
    fi
else
    if ! type azwi > /dev/null 2>&1; then
        echo "Skipping azwi."
    else
        echo "Azwi already instaled"
    fi
fi

# Install flux, verify checksum
if [ "${FLUX_VERSION}" != "none" ] && ! type flux > /dev/null 2>&1; then

    echo "Downloading flux..."

    find_version_from_git_tags FLUX_VERSION https://github.com/fluxcd/flux2

    FLUX_VERSION="${FLUX_VERSION}"

    curl -sSL -o /tmp/flux_${FLUX_VERSION}_linux_${architecture}.tar.gz "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_linux_${architecture}.tar.gz"

    if [ "$FLUX_SHA256" = "automatic" ]; then
        FLUX_SHA256="$(curl -sSL "https://github.com/fluxcd/flux2/releases/download/v${FLUX_VERSION}/flux_${FLUX_VERSION}_checksums.txt" | grep flux_${FLUX_VERSION}_linux_${architecture}.tar.gz | cut -f1 -d' ')"
        echo $FLUX_SHA256
    fi
    ([ "${FLUX_SHA256}" = "dev-mode" ] || (echo "${FLUX_SHA256} */tmp/flux_${FLUX_VERSION}_linux_${architecture}.tar.gz" | sha256sum -c -))
    tar -xf /tmp/flux_${FLUX_VERSION}_linux_${architecture}.tar.gz --directory /usr/local/bin/
    chmod 0755 /usr/local/bin/flux
    rm /tmp/flux_${FLUX_VERSION}_linux_${architecture}.tar.gz
    if ! type flux > /dev/null 2>&1; then
        echo '(!) flux installation failed!'
        exit 1
    fi
else
    if ! type flux > /dev/null 2>&1; then
        echo "Skipping flux."
    else
        echo "Flux already instaled"
    fi
fi

# If flux is installed, install completion
if type flux > /dev/null 2>&1; then
    # flux bash completion
    flux completion bash > /etc/bash_completion.d/flux
fi


# Install cilium cli, verify checksum
if [ "${CILIUM_VERSION}" != "none" ] && ! type cilium > /dev/null 2>&1; then

    echo "Downloading Cilium CLI..."

    find_version_from_git_tags CILIUM_VERSION https://github.com/cilium/cilium-cli
    if [ "${CILIUM_VERSION::1}" != 'v' ]; then
        CILIUM_VERSION="v${CILIUM_VERSION}"
    fi

    curl -sSL -o /tmp/cilium-linux-${architecture}.tar.gz "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-${architecture}.tar.gz"

    if [ "$CILIUM_SHA256" = "automatic" ]; then
        CILIUM_SHA256="$(curl -sSL "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_VERSION}/cilium-linux-${architecture}.tar.gz.sha256sum" | cut -f1 -d' ')"
    fi
    ([ "${CILIUM_SHA256}" = "dev-mode" ] || (echo "${CILIUM_SHA256} */tmp/cilium-linux-${architecture}.tar.gz" | sha256sum -c -))
    tar -xf /tmp/cilium-linux-${architecture}.tar.gz --directory /usr/local/bin/
    chmod 0755 /usr/local/bin/cilium
    rm /tmp/cilium-linux-${architecture}.tar.gz
    if ! type cilium > /dev/null 2>&1; then
        echo '(!) Cilium CLI installation failed!'
        exit 1
    fi
else
    if ! type cilium > /dev/null 2>&1; then
        echo "Skipping Cilium CLI."
    else
        echo "Cilium CLI already instaled."
    fi
fi

# If cilium is installed, install completion
if type cilium > /dev/null 2>&1; then
    # cilium bash completion
    cilium completion bash > /etc/bash_completion.d/cilium
fi


if ! type docker > /dev/null 2>&1; then
    echo -e '\n(*) Warning: The docker command was not found.\n\nYou can use one of the following scripts to install it:\n\nhttps://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/docker-in-docker.md\n\nor\n\nhttps://github.com/microsoft/vscode-dev-containers/blob/main/script-library/docs/docker.md'
fi

# Clean up
rm -rf /var/lib/apt/lists/*

echo -e "\nDone!"
