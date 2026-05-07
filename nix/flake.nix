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
