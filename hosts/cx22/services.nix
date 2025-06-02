{
  inputs,
  outputs,
  ...
}:

{
  imports = [
    inputs.core.nixosModules.nginx
    inputs.core.nixosModules.openssh
    inputs.core.nixosModules.sops

    outputs.nixosModules.matrix-synapse
  ];

  services = {
    matrix-synapse.enable = true;
    nginx.enable = true;
  };
}
