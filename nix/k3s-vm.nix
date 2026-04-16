{ pkgs, ... }:

{
  networking.hostName = "k3s-vm";
  networking.firewall.allowedTCPPorts = [ 22 6443 10250 ];
  networking.firewall.allowedUDPPorts = [ 8472 ];
  networking.dhcpcd.wait = "any";


  users.users.k3s = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [];
  };

  security.sudo.wheelNeedsPassword = false;
  users.users.root.hashedPassword = "!";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  services.k3s = {
    enable = true;
    role = "server";
    package = pkgs.k3s_1_31;
    extraFlags = "--write-kubeconfig-mode 644 --disable traefik";
  };

  environment.systemPackages = with pkgs; [
    kubectl
    curl
    git
  ];

  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  virtualisation.diskSize = 18 * 1024; # 18 GB (default 8 GB + 10 GB extra)

  system.stateVersion = "24.11";
}
