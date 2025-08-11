{ config, ... }:

let
  cfg = config.services.authelia;
  main = cfg.instances.main;
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
      secrets = {
        jwtSecretFile = config.sops.secrets."authelia/main/jwt-secret".path;
        storageEncryptionKeyFile = config.sops.secrets."authelia/main/storage-encryption-key".path;
      };
    };
  };

  sops =
    let
      mode = "0440";
      perms = {
        main = {
          inherit mode;
          owner = main.user;
          group = main.group;
        };
      };
    in
    {
      secrets."authelia/main/jwt-secret" = perms.main;
      secrets."authelia/main/storage-encryption-key" = perms.main;
    };
}
