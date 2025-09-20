Aztec plugin: Rootless Docker guidance

This compose example has been updated to be compatible with rootless Docker:

- `network_mode: host` was replaced with a user-defined bridge network `ethpillar_default` and explicit `ports:` mappings.
- Rootless Docker does not support host networking. If you previously relied on host networking, ensure the plugin's required ports are exposed in the `ports:` section.

Notes:
- Default ports in the example: P2P (TCP/UDP) `40400`, HTTP/API `8080`.
- If you run Docker rootless, ensure the container can bind to the host ports. Rootless Docker maps container ports to user-owned ports; if a port is <1024 you may need to choose a higher port.
- The compose file now defines a `ethpillar_default` bridge network. You can create it manually if needed:

  docker network create ethpillar_default

- For full compatibility, review any plugins that still use `--net=host` or `network_mode: host` and adjust accordingly.

If you want help converting the plugin to a true rootless deployment (removing any remaining host-network-only features), open an issue with details about which features rely on host networking.
