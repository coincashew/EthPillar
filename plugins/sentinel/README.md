CSM Sentinel plugin - Rootless Docker Notes

The sentinel run command was adjusted to avoid `--net=host` so it works under rootless Docker. Changes made:

- `--net=host` removed; container now runs on `ethpillar_default` network and uses mapped ports where appropriate.
- Ensure the network exists before running any containers:

  docker network create ethpillar_default

- If the sentinel requires specific ports to be reachable from the host, add `-p HOSTPORT:CONTAINERPORT` options when running the container or update the compose file if you prefer compose.

If you encounter issues with networking or discovery while running rootless, please report the specific service and ports, and we can propose more targeted changes.
