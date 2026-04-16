# NixOS K3s on KVM

Builds a NixOS qcow2 image with k3s, boots it in KVM, and opens k9s.

## Requirements

Assumes libvirt/KVM on the host with a bridge interface (e.g. `br0`) that puts VMs on the same LAN as the host, with a DHCP server available on that network.

## Setup

```bash
cp local.nix.dist local.nix
# edit local.nix: set bridge name and your sshKeys
```

## Run

Builds the image, boots a VM, waits for the node to be ready, opens k9s on pods.

```bash
./1-create-vm.sh
```

Pass `--mac` to force a specific MAC address (useful to replay a DHCP leases):

```bash
./1-create-vm.sh --mac 52:54:00:ab:cd:ef
```

## local.nix options

| Option | Description |
|---|---|
| `bridge` | Host bridge interface (e.g. `br0`) |
| `sshKeys` | List of SSH public keys for the `k3s` user |

## Demo

<video src="https://private-user-images.githubusercontent.com/1489618/583392051-4fe79c3e-f258-4cea-a1ca-5586ce0b87b8.mp4?jwt=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJnaXRodWIuY29tIiwiYXVkIjoicmF3LmdpdGh1YnVzZXJjb250ZW50LmNvbSIsImtleSI6ImtleTUiLCJleHAiOjE3NzcwMzUyNDEsIm5iZiI6MTc3NzAzNDk0MSwicGF0aCI6Ii8xNDg5NjE4LzU4MzM5MjA1MS00ZmU3OWMzZS1mMjU4LTRjZWEtYTFjYS01NTg2Y2UwYjg3YjgubXA0P1gtQW16LUFsZ29yaXRobT1BV1M0LUhNQUMtU0hBMjU2JlgtQW16LUNyZWRlbnRpYWw9QUtJQVZDT0RZTFNBNTNQUUs0WkElMkYyMDI2MDQyNCUyRnVzLWVhc3QtMSUyRnMzJTJGYXdzNF9yZXF1ZXN0JlgtQW16LURhdGU9MjAyNjA0MjRUMTI0OTAxWiZYLUFtei1FeHBpcmVzPTMwMCZYLUFtei1TaWduYXR1cmU9N2ZmOTA5YjVkMjhjZThjOGRhOGM2MjBhMjdlZjIyZjhkYTY4ZmFmNjQzMGVhZTY2ZGU3ODZlMTc1ZWEzMDQ4MCZYLUFtei1TaWduZWRIZWFkZXJzPWhvc3QmcmVzcG9uc2UtY29udGVudC10eXBlPXZpZGVvJTJGbXA0In0.4ususFrgdtxO8rjtI-DyhHTHwvyA-VAlEPQ2KKRJ9k8" controls></video>

## k3s version

Set `package` in `k3s-vm.nix`. Available in nixpkgs 24.11: `k3s_1_26`, `k3s_1_27`, `k3s_1_28`, `k3s_1_30`, `k3s_1_31`.
