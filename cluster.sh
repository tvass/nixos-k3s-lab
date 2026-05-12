#!/usr/bin/env bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
NIX_EXTRA=(--extra-experimental-features nix-command --extra-experimental-features flakes)

NODES=1
MAC=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --nodes) NODES="$2"; shift 2 ;;
    --mac)   MAC="$2";   shift 2 ;;
    *) echo "unknown argument: $1"; exit 1 ;;
  esac
done

if [[ ! -f "${DIR}/local.nix" ]]; then
  echo "local.nix not found — copy local.nix.dist and edit it"
  exit 1
fi

for cmd in arp nix virsh virt-install nc uuidgen scp k9s; do
  command -v "${cmd}" &>/dev/null || { echo "missing: ${cmd}"; exit 1; }
done

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa"
BRIDGE=$(FLAKE_DIR="${DIR}" nix "${NIX_EXTRA[@]}" eval --raw --impure "${DIR}/nix#localConfig.bridge")
VM_USER="k3s"
LAST_MAC=""

wait_port() {
  local ip="$1" port="$2"
  echo "Waiting for ${ip}:${port}..."
  until nc -zw3 "${ip}" "${port}" 2>/dev/null; do sleep 2; done
  echo "  ${port} open"
}

# Creates a VM and prints its IP; sets LAST_MAC
create_vm() {
  local name="$1" qcow="$2" mac_hint="${3:-}"
  local net_arg="bridge=${BRIDGE}"
  [[ -n "${mac_hint}" ]] && net_arg="${net_arg},mac=${mac_hint}"

  virt-install \
    --name "${name}" \
    --memory 2048 \
    --vcpus 2 \
    --disk path="${qcow}",format=qcow2 \
    --import \
    --os-variant nixos-unstable \
    --network "${net_arg}" \
    --noautoconsole >&2

  LAST_MAC=$(virsh domiflist "${name}" | awk -v br="${BRIDGE}" '$0 ~ br {print $5}')
  echo "MAC: ${LAST_MAC} — waiting for ARP entry..." >&2

  local ip=""
  until [[ -n "${ip}" ]]; do
    ip=$(arp -n | awk -v m="${LAST_MAC}" 'tolower($3)==tolower(m) && $1!~/^169\.254/ {print $1; exit}')
    sleep 1
  done

  echo "${ip}:${LAST_MAC}" >> "${DIR}/vm-hosts.log"
  echo "${ip}"
}

add_agent() {
  local server_ip="$1"

  local expected_nodes
  expected_nodes=$(KUBECONFIG="/tmp/k3s-${server_ip}.yaml" kubectl get node --no-headers 2>/dev/null | wc -l)
  ((expected_nodes++))

  echo "Building agent image..."
  FLAKE_DIR="${DIR}" \
  HOST_IP="$(ip -o -f inet addr show "${BRIDGE}" | awk '{print $4}' | cut -d/ -f1)" \
  SERVER_ADDR="https://${server_ip}:6443" \
  K3S_TOKEN="$(cat "/tmp/k3s-token-${server_ip}")" \
    nix "${NIX_EXTRA[@]}" build "${DIR}/nix#agent" --impure --out-link "${DIR}/result-agent"

  local uuid
  uuid=$(uuidgen)
  local qcow="${DIR}/k3s-agent-${uuid}.qcow2"
  cp "${DIR}/result-agent/nixos.qcow2" "${qcow}"
  chmod 644 "${qcow}"

  local agent_ip
  agent_ip=$(create_vm "k3s-agent-${uuid}" "${qcow}")
  echo "Agent IP: ${agent_ip}"

  wait_port "${agent_ip}" 22

  echo "Waiting for agent to join cluster (expecting ${expected_nodes} nodes)..."
  until [[ $(KUBECONFIG="/tmp/k3s-${server_ip}.yaml" kubectl get node --no-headers 2>/dev/null | wc -l) -ge ${expected_nodes} ]]; do
    sleep 3
  done
  echo "Agent ${agent_ip} joined."
}

# ── server ────────────────────────────────────────────────────────────────────
HOST_IP=$(ip -o -f inet addr show "${BRIDGE}" | awk '{print $4}' | cut -d/ -f1)
echo "Host IP: ${HOST_IP}"

FLAKE_DIR="${DIR}" HOST_IP="${HOST_IP}" \
  nix "${NIX_EXTRA[@]}" build "${DIR}/nix#" --impure --out-link "${DIR}/result"

UUID=$(uuidgen)
QCOW="${DIR}/k3s-vm-${UUID}.qcow2"
cp "${DIR}/result/nixos.qcow2" "${QCOW}"
chmod 644 "${QCOW}"

VM_IP=$(create_vm "k3s-vm-${UUID}" "${QCOW}" "${MAC}")
echo "Server IP: ${VM_IP}"

wait_port "${VM_IP}" 22
wait_port "${VM_IP}" 6443

echo "Waiting for kubeconfig..."
until ssh -q ${SSH_OPTS} "${VM_USER}@${VM_IP}" "test -f /etc/rancher/k3s/k3s.yaml" 2>/dev/null; do sleep 2; done

CLUSTER_NAME="k3s-${VM_IP//./-}"
KUBECONFIG_TMP="/tmp/k3s-${VM_IP}.yaml"

scp -q ${SSH_OPTS} "${VM_USER}@${VM_IP}:/etc/rancher/k3s/k3s.yaml" "${KUBECONFIG_TMP}"
sed -i \
  -e "s|https://127.0.0.1:6443|https://${VM_IP}:6443|g" \
  -e "s|\bdefault\b|${CLUSTER_NAME}|g" \
  "${KUBECONFIG_TMP}"
echo "Waiting for node token..."
until ssh -q ${SSH_OPTS} "${VM_USER}@${VM_IP}" "sudo test -f /var/lib/rancher/k3s/server/node-token" 2>/dev/null; do sleep 2; done
ssh -q ${SSH_OPTS} "${VM_USER}@${VM_IP}" "sudo cat /var/lib/rancher/k3s/server/node-token" > "/tmp/k3s-token-${VM_IP}"

echo "Waiting for server node to be ready..."
until KUBECONFIG="${KUBECONFIG_TMP}" kubectl wait node --all --for=condition=Ready --timeout=10s &>/dev/null; do sleep 2; done

for ((i = 2; i <= NODES; i++)); do
  echo "── Adding agent $((i - 1))/$((NODES - 1)) ──"
  add_agent "${VM_IP}"
done

echo -e "\n\nRun this to use the cluster:\n  export KUBECONFIG=${KUBECONFIG_TMP}"
KUBECONFIG="${KUBECONFIG_TMP}" k9s --context "${CLUSTER_NAME}" --command pods -A
