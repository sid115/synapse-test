{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.matrix-synapse;
  fqdn = config.networking.domain;
  element-call = cfg.element-call;
  element-call-config = builtins.readFile ./element-call-config.json;

  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
in
{
  options.services.matrix-synapse.element-call = {
    enable = mkEnableOption "Enable Element Call backend services and web client.";
    subdomain = mkOption {
      type = types.str;
      default = "call";
      description = "Subdomain for Nginx virtual host. Cannot be empty."; # TODO: add assertion
    };
    forceSSL = mkOption {
      type = types.bool;
      default = true;
      description = "Force SSL for Nginx virtual host.";
    };
  };

  config = mkIf (cfg.enable && element-call.enable) {
    services.matrix-synapse = {
      settings = {
        experimental-features = {
          msc3266_enabled = true;
          msc4222_enabled = true;
        };
        max_event_delay_duration = "24h";
        rc_message = {
          per_second = 0.5;
          burst_count = 30;
        };
        rc_delayed_event_mgmt = {
          per_second = 1;
          burst_count = 20;
        };
      };
    };

    services.livekit = {
      enable = true;
      settings = {
        port = 7880;
      };
      keyFile = config.sops.templates."livekit/keyFile".path;
    };

    services.lk-jwt-service = {
      enable = true;
      livekitUrl = "wss://${fqdn}/livekit/sfu/";
      port = 8090;
      keyFile = config.sops.templates."livekit/keyFile".path;
    };

    services.nginx.virtualHosts = {
      "${fqdn}" = {
        locations."/livekit/jwt/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:${toString config.services.lk-jwt-service.port}/";
        };
        locations."/livekit/sfu/" = {
          recommendedProxySettings = true;
          proxyPass = "http://localhost:${toString config.services.livekit.settings.port}/";
          extraConfig = ''
            proxy_send_timeout 120;
            proxy_read_timeout 120;
            proxy_buffering off;
            proxy_set_header Accept-Encoding gzip;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
          '';
        };
      };
      "${element-call.subdomain}.${fqdn}" = {
        root = pkgs.element-call;
        enableACME = element-call.forceSSL;
        forceSSL = element-call.forceSSL;
        locations."/" = {
          extraConfig = "try_files $uri /$uri /index.html;";
        };
        locations."/public/config.json" = {
          extraConfig = ''
            add_header Cache-Control "no-cache, must-revalidate";
            default_type application/json;
            return 200 '${element-call-config}';
          '';
        };
      };
    };

    sops = {
      # nix-shell -p livekit --run 'livekit-server generate-keys'
      secrets."livekit/api-key" = { };
      secrets."livekit/api-secret" = { };
      templates."livekit/keyFile".content = ''
        lk-jwt-service: ${config.sops.placeholder."livekit/api-secret"}
      '';
    };
  };
}
