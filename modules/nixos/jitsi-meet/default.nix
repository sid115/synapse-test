{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.grafana;
  domain = config.networking.domain;
  fqdn = if (cfg.subdomain != "") then "${cfg.subdomain}.${domain}" else domain;

  inherit (lib)
    mkDefault
    mkIf
    mkOption
    types
    ;
in
{
  options.services.jitsi-meet = {
    subdomain = mkOption {
      type = types.str;
      default = "jitsi";
      description = "Subdomain for Nginx virtual host. Leave empty for root domain.";
    };
    forceSSL = mkOption {
      type = types.bool;
      default = true;
      description = "Force SSL for Nginx virtual host.";
    };
  };

  config = mkIf cfg.enable {
    services.jitsi-meet = {
      hostName = fqdn;
      ngnix.enable = true;
      videobridge.openFirewall = true;
      # prosody.lockdown = true;
      # https://github.com/jitsi/jitsi-meet/blob/master/config.js
      config = {
        enableWelcomePage = false;
        prejoinPageEnabled = true;
        defaultLang = "en";
      };
      interfaceConfig = {
        SHOW_JITSI_WATERMARK = false;
        SHOW_WATERMARK_FOR_GUESTS = false;
      };
    };

    services.jitsi-videobridge.openFirewall = true;

    services.nginx = mkIf config.services.nginx.enable {
      virtualHosts."${cfg.hostName}" = {
        forceSSL = cfg.forceSSL;
        enableACME = cfg.forceSSL;
      };
    };
  };
}
