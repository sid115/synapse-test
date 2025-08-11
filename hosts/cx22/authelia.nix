{ config, pkgs, ... }:

let
  cfg = config.services.authelia;
  main = cfg.instances.main;

  domain = config.networking.domain;
  port = 9091;
  subdomain = "auth";
  fqdn = "${subdomain}.${domain}";

  test-script = ''
    import http.server
    import socketserver
    handler = http.server.SimpleHTTPRequestHandler
    with socketserver.TCPServer(('0.0.0.0', 8000), handler) as httpd:
        print('Serving at port 8000')
        httpd.serve_forever()
  '';
in
{
  services.authelia.instances = {
    main = {
      enable = true;
      settings = {
        server.address = "tcp://:${toString port}/";
        log.level = "debug";

        authentication_backend = {
          file = {
            path = "/var/lib/authelia/users_database.yml";
            watch = true;
          };
        };

        access_control = {
          default_policy = "deny";
          rules = [
            {
              domain = "*.${domain}";
              subject = [ "user:sid" ];
              policy = "one_factor";
            }
          ];
        };

        session = {
          cookies = [
            {
              inherit domain;
              authelia_url = "https://${fqdn}";
              default_redirection_url = "https://${fqdn}/";
            }
          ];
        };

        storage = {
          local = {
            path = "/var/lib/authelia/db.sqlite3";
          };
        };

        notifier = {
          filesystem = {
            filename = "/var/lib/authelia/notification.txt";
          };
        };
      };
      secrets = {
        jwtSecretFile = config.sops.secrets."authelia/main/jwt-secret".path;
        storageEncryptionKeyFile = config.sops.secrets."authelia/main/storage-encryption-key".path;
      };
    };
  };

  environment.etc."authelia/users_database.yml" = {
    text = ''
      users:
        sid:
          password: $argon2id$v=19$m=65536,t=3,p=4$yGyt1dKtjMPNd6V4GjongA$5whbC60jr5/znIF+wGLjI+0/gOBY77k7skdQQAhF+uc
          email: sid@${domain}
          groups:
            - admins
    '';
    mode = "0644";
  };

  services.nginx.virtualHosts = {
    "${fqdn}" = {
      locations."/".proxyPass = "http://127.0.0.1:${toString port}";
    };
    "auth-test.${domain}" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        extraConfig = ''
          auth_request /authelia/auth;
          auth_request_set $user $upstream_http_remote_user;
          auth_request_set $groups $upstream_http_remote_groups;
          proxy_set_header X-Forwarded-User $user;
          proxy_set_header X-Forwarded-Groups $groups;
        '';
      };
      locations."/authelia/" = {
        proxyPass = "http://127.0.0.1:${toString port}/";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  systemd.services.auth-test = {
    description = "Simple whoami test service for Authelia";
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.python3}/bin/python3 -c "${test-script}"
    '';
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
