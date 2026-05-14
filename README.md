# NixOS K3s Lab (Linux/KVM)

while(1) { create, deploy, test, delete }

Spins up NixOS-based k3s clusters on QEMU/KVM/libvirt. I use it for testing ingress controllers, service meshes, datastores, or failure scenarios.


## Requirements

- libvirt/KVM on the host
- A bridge interface (e.g. `br0`) putting VMs on the same LAN as the host
- DHCP server on that network
- `qemu-bridge-helper` configured:

```bash
sudo mkdir -p /etc/qemu
echo "allow br0" | sudo tee /etc/qemu/bridge.conf
sudo chmod u+s /usr/lib/qemu/qemu-bridge-helper
```

## Setup

```bash
cp local.nix.dist local.nix
# edit local.nix: set bridge name and your SSH public key
```

## Usage

```bash
./cluster.sh                             # 1-node cluster (control plane as worker)
./cluster.sh --nodes 3                   # 1 server + 2 agents
./cluster.sh --mac 52:54:00:ab:cd:ef
```

When the cluster is ready, k9s opens automatically. The kubeconfig is saved to `/tmp/k3s-<ip>.yaml`.

## local.nix options

| Option | Required | Description |
|---|---|---|
| `bridge` | yes | Host bridge interface (e.g. `br0`) |
| `sshKeys` | yes | List of SSH public keys for the `k3s` user |
| `dns` | no | Override DHCP DNS server |
| `disableAlgifAead` | no | Disable `algif_aead` kernel module (CVE-2026-31431 mitigation) |
| `useEtcd` | no | Run etcd as a separate process and use it as the k3s datastore instead of SQLite |

## Network keepalive

Each VM runs a `ping-host` systemd service that continuously pings the KVM host. This keeps the ARP entry alive on the host so the VM remains discoverable without a static lease.

## vm-hosts.log

Each run appends `ip:mac` to `vm-hosts.log` (gitignored). Useful for looking up MAC addresses when resuming VMs that were off.

## k3s version

Set `package` in `nix/k3s-vm.nix` and `nix/k3s-agent.nix`. Available in nixpkgs 24.11: `k3s_1_26`, `k3s_1_27`, `k3s_1_28`, `k3s_1_30`, `k3s_1_31`.

## Demo

<video src="https://private-user-images.githubusercontent.com/1489618/591806814-37e94ef7-c73c-42c7-9d1b-a8f7fc7030fe.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3Nzg2Nzc1NDYsIm5iZiI6MTc3ODY3NzI0NiwicGF0aCI6Ii8xNDg5NjE4LzU5MTgwNjgxNC0zN2U5NGVmNy1jNzNjLTQyYzctOWQxYi1hOGY3ZmM3MDMwZmUubXA0P1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDUxMyUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA1MTNUMTMwMDQ2WiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9MDIzOTJmZDYxYTJhNjk5NDZhY2RiNWM5ZGFiZDkzYzMxZWI5ZDQ5MmI2YTFiOGNjNTY0ZjlhODQ3ZWY4NDk3YSZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPXZpZGVvJTJGbXA0In0.f-vRjVVc8Irq7bM2yiJiWrpr12ejdfbzZ2s6AO4hOY0" controls></video>
