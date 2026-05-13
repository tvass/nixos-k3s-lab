{ pkgs, serverAddr, token, ... }:

{
  imports = [ ./base.nix ];

  networking.hostName = "k3s-agent";
  networking.firewall.allowedTCPPorts = [ 22 10250 ];

  services.k3s = {
    enable = true;
    role = "agent";
    package = pkgs.k3s_1_31;
    serverAddr = serverAddr;
    token = token;
    extraFlags = "--with-node-id";
  };
}