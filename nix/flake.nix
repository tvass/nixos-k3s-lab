{
  description = "NixOS-based k3s cluster image builder";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      local = import (builtins.toPath "${builtins.getEnv "FLAKE_DIR"}/local.nix");
      hostIp =
        let ip = builtins.getEnv "HOST_IP"; in
        if builtins.match "[0-9]+(\\.[0-9]+){3}" ip != null
        then ip
        else throw "HOST_IP must be a valid IPv4 address, got: '${ip}'";
    in {
      localConfig = local;

      packages.x86_64-linux.agent = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "qcow";
        specialArgs = {
          serverAddr = builtins.getEnv "SERVER_ADDR";
          token     = builtins.getEnv "K3S_TOKEN";
        };
        modules = [
          ./k3s-agent.nix
          (if local ? dns then {
            networking.nameservers = [ local.dns ];
            networking.dhcpcd.extraConfig = "nohook resolv.conf";
          } else {})
          (if local ? disableAlgifAead && local.disableAlgifAead then {
            boot.kernelParams = [ "initcall_blacklist=algif_aead_init" ];
          } else {})
          {
            users.users.k3s.openssh.authorizedKeys.keys = local.sshKeys;
            systemd.services.ping-host = {
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "simple";
                Restart = "always";
                RestartSec = "10s";
                ExecStart = "${nixpkgs.legacyPackages.x86_64-linux.iputils}/bin/ping ${hostIp}";
              };
            };
          }
        ];
      };

      packages.x86_64-linux.default = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        format = "qcow";
        modules = [
          ./k3s-vm.nix
          (if local ? dns then {
            networking.nameservers = [ local.dns ];
            networking.dhcpcd.extraConfig = "nohook resolv.conf";
          } else {})
          (if local ? disableAlgifAead && local.disableAlgifAead then {
            boot.kernelParams = [ "initcall_blacklist=algif_aead_init" ];
          } else {})
          (if local ? useEtcd && local.useEtcd then {
            services.etcd.enable = true;
            services.k3s.extraFlags = nixpkgs.lib.mkForce "--write-kubeconfig-mode 644 --disable traefik --datastore-endpoint=http://127.0.0.1:2379";
            systemd.services.k3s.after = [ "etcd.service" ];
            systemd.services.k3s.wants = [ "etcd.service" ];
          } else {})
          {
            users.users.k3s.openssh.authorizedKeys.keys = local.sshKeys;
            systemd.services.ping-host = {
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig = {
                Type = "simple";
                Restart = "always";
                RestartSec = "10s";
                ExecStart = "${nixpkgs.legacyPackages.x86_64-linux.iputils}/bin/ping ${hostIp}";
              };
            };
          }
        ];
      };
    };
}
