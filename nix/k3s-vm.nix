{ pkgs, ... }:

{
  imports = [ ./base.nix ];

  networking.hostName = "k3s-vm";
  networking.firewall.allowedTCPPorts = [ 22 6443 9443 10250 ];

  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s_1_31;
    extraFlags = "--write-kubeconfig-mode 644 --disable traefik";
  };

  environment.systemPackages = with pkgs; [ kubectl ];
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
}
