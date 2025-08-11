{ config, ... }:

let
  domain = config.networking.domain;
in
{
  services.authelia.instances = {
    main = {
      enable = true;
      settings = {
        address = "tcp://:9091/";
        log.level = "debug";
        default_redirection_url = "https://auth.${domain}";
      };
    };
  };
}
