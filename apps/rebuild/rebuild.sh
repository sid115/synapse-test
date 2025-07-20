USER="$(whoami)"
HOST="cx22"
DOMAIN="synapse-test.ovh"
PORT="2299"

NIX_SSHOPTS="-p $PORT" rebuild nixos -p . -H "$HOST" -B "$USER"@"portuus.de" -T "$USER"@"$DOMAIN"
