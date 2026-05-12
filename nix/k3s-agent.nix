{ pkgs, serverAddr, token, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.hostName = "k3s-agent";
  networking.firewall.allowedTCPPorts = [ 22 10250 ];
  networking.firewall.allowedUDPPorts = [ 8472 ];
  networking.dhcpcd.wait = "any";

  users.users.k3s = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [];
  };

  services.getty.autologinUser = "k3s";

  security.sudo.wheelNeedsPassword = false;
  users.users.root.hashedPassword = "!";

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      registry.lan:
        endpoint:
          - "https://registry.lan"

    configs:
      registry.lan:
        tls:
          insecure_skip_verify: true
  '';

  services.k3s = {
    enable = true;
    role = "agent";
    package = pkgs.k3s_1_31;
    serverAddr = serverAddr;
    token = token;
    extraFlags = "--with-node-id";
  };

  environment.systemPackages = with pkgs; [
    curl
    git
  ];

  virtualisation.diskSize = 18 * 1024;

  system.stateVersion = "24.11";
}