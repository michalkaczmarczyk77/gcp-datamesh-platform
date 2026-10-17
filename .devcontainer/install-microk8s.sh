#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
  echo "MicroK8s setup must run as root inside the privileged devcontainer." >&2
  exit 1
fi

if [ ! -r /sys/kernel/security/apparmor/profiles ]; then
  echo "AppArmor is not available inside this container. Enable AppArmor and mount securityfs on the Linux host, then recreate the devcontainer." >&2
  exit 1
fi

systemctl start snapd.socket
snap wait system seed.loaded

if ! snap list microk8s >/dev/null 2>&1; then
  snap install microk8s --classic
fi

microk8s status --wait-ready

KUBECONFIG_DIR="${HOME}/.kube"
KUBECONFIG_FILE="${KUBECONFIG_DIR}/microk8s-config"
mkdir -p "${KUBECONFIG_DIR}"
chmod 700 "${KUBECONFIG_DIR}"
umask 077
TEMP_CONFIG="$(mktemp "${KUBECONFIG_FILE}.XXXXXX")"
trap 'rm -f "${TEMP_CONFIG}"' EXIT
microk8s config > "${TEMP_CONFIG}"
mv "${TEMP_CONFIG}" "${KUBECONFIG_FILE}"
trap - EXIT

echo "MicroK8s is ready. Kubeconfig written to ${KUBECONFIG_FILE}."
