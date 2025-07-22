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

    outputs.nixosModules.jitsi-meet
    outputs.nixosModules.matrix-synapse
  ];

  services = {
    jitsi-meet.enable = true;
    matrix-synapse = {
      enable = true;
      element-call.enable = true;
    };
    nginx.enable = true;
  };
}
