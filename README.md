# NixOS K3s on KVM

Builds a NixOS qcow2 image with k3s, boots it in KVM, and opens k9s.

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
./cluster.sh --mac 52:54:00:ab:cd:ef    # fix MAC (stable DHCP lease)
```

When the cluster is ready, k9s opens automatically. The kubeconfig is saved to `/tmp/k3s-<ip>.yaml`.

## local.nix options

| Option | Required | Description |
|---|---|---|
| `bridge` | yes | Host bridge interface (e.g. `br0`) |
| `sshKeys` | yes | List of SSH public keys for the `k3s` user |
| `dns` | no | Override DHCP DNS server |
| `disableAlgifAead` | no | Disable `algif_aead` kernel module (CVE-2026-31431 mitigation) |

## vm-hosts.log

Each run appends `ip:mac` to `vm-hosts.log` (gitignored). Useful for looking up MAC addresses when resuming VMs that were off.

## k3s version

Set `package` in `nix/k3s-vm.nix` and `nix/k3s-agent.nix`. Available in nixpkgs 24.11: `k3s_1_26`, `k3s_1_27`, `k3s_1_28`, `k3s_1_30`, `k3s_1_31`.

## Demo

<video src="https://private-user-images.githubusercontent.com/1489618/583392051-4fe79c3e-f258-4cea-a1ca-5586ce0b87b8.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzcwMzUyNDEsIm5iZiI6MTc3NzAzNDk0MSwicGF0aCI6Ii8xNDg5NjE4LzU4MzM5MjA1MS00ZmU3OWMzZS1mMjU4LTRjZWEtYTFjYS01NTg2Y2UwYjg3YjgubXA0P1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDQyNCUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA0MjRUMTI0OTAxWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9N2ZmOTA5YjVkMjhjZThjOGRhOGM2MjBhMjdlZjIyZjhkYTY4ZmFmNjQzMGVhZTY2ZGU3ODZlMTc1ZWEzMDQ4MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPXZpZGVvJTJGbXA0In0.4ususFrgdtxO8rjtI-DyhHTHwvyA-VAlEPQ2KKRJ9k8" controls></video>
