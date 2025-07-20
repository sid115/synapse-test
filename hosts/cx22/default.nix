{
  inputs,
  outputs,
  ...
}:

{
  imports = [
    ./boot.nix
    ./hardware.nix
    ./packages.nix
    ./services.nix
    ./users.nix

    inputs.core.nixosModules.common

    outputs.nixosModules.common
  ];

  networking.hostName = "cx22";
  networking.domain = "synapse-test.ovh";

  system.stateVersion = "25.05";
}
