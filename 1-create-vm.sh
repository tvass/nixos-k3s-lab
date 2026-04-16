#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"

MAC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mac) MAC="$2"; shift 2 ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done

if [[ ! -f "${DIR}/local.nix" ]]; then
  echo "local.nix not found — copy local.nix.dist and edit it"
  exit 1
fi

for cmd in arp nix virsh virt-install nc uuidgen scp k9s jq; do
  if ! command -v "${cmd}" &>/dev/null; then
    echo "missing: ${cmd}"
    exit 1
  fi
done


BRIDGE=$(FLAKE_DIR="${DIR}" nix eval --raw --impure "${DIR}/nix#localConfig.bridge")
VM_USER="k3s"
HOST_IP=$(ip -o -f inet addr show "${BRIDGE}" | awk '{print $4}' | cut -d/ -f1)
echo "Host IP: ${HOST_IP}"

FLAKE_DIR="${DIR}" HOST_IP="${HOST_IP}" nix build "${DIR}/nix#" --impure --out-link "${DIR}/result"

UUID=$(uuidgen)
QCOW="${DIR}/k3s-vm-${UUID}.qcow2"

cp "${DIR}/result/nixos.qcow2" "${QCOW}"
chmod 644 "${QCOW}"

NETWORK_ARG="bridge=${BRIDGE}"
[[ -n "${MAC}" ]] && NETWORK_ARG="${NETWORK_ARG},mac=${MAC}"

virt-install \
  --name "k3s-vm-${UUID}" \
  --memory 2048 \
  --vcpus 2 \
  --disk path="${QCOW}",format=qcow2 \
  --import \
  --os-variant nixos-unstable \
  --network "${NETWORK_ARG}" \
  --noautoconsole

MAC=$(virsh domiflist "k3s-vm-${UUID}" | awk -v bridge="${BRIDGE}" '$0 ~ bridge {print $5}')
echo "VM MAC: ${MAC} — waiting for ARP entry..."

VM_IP=""
until [[ -n "${VM_IP}" ]]; do
  VM_IP=$(arp -n | awk -v mac="${MAC}" 'tolower($3) == tolower(mac) && $1 !~ /^169\.254/ {print $1; exit}')
  sleep 1
done
echo "VM IP: ${VM_IP}"

KUBECONFIG_TMP="/tmp/k3s-${VM_IP}.yaml"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa"

wait_port() {
  local port=$1
  echo "Waiting for ${VM_IP}:${port}..."
  until nc -zw3 "${VM_IP}" "${port}" 2>/dev/null; do
    sleep 2
  done
  echo "  ${port} open"
}

wait_port 22
wait_port 6443

echo "Waiting for kubeconfig..."
until ssh -q ${SSH_OPTS} "${VM_USER}"@"${VM_IP}" "test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null; do
  sleep 2
done

CLUSTER_NAME="k3s-${VM_IP//./-}"

scp -q ${SSH_OPTS} "${VM_USER}"@"${VM_IP}":/etc/rancher/k3s/k3s.yaml "${KUBECONFIG_TMP}"
sed -i \
  -e "s|https://127.0.0.1:6443|https://${VM_IP}:6443|g" \
  -e "s|\bdefault\b|${CLUSTER_NAME}|g" \
  "${KUBECONFIG_TMP}"

echo "Waiting for k3s node to be ready..."
until KUBECONFIG="${KUBECONFIG_TMP}" kubectl wait node --all --for=condition=Ready --timeout=10s &>/dev/null; do
  sleep 2
done
echo -e "\n\nRun this to use the cluster:\n  export KUBECONFIG=${KUBECONFIG_TMP}"
KUBECONFIG="${KUBECONFIG_TMP}" k9s --context "${CLUSTER_NAME}" --command pods -A
