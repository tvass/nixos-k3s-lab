{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  networking.dhcpcd.wait = "any";
  networking.firewall.allowedUDPPorts = [ 8472 ];

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

  environment.systemPackages = with pkgs; [ curl git ];

  virtualisation.diskSize = 18 * 1024;
  system.stateVersion = "24.11";
}