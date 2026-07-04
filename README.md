# GeyserMC Docker

A small, non-root Docker image for [Geyser Standalone](https://geysermc.org/),
the proxy that lets Minecraft Bedrock Edition clients connect to a Java Edition
server. Docker Hub releases are configured as `aspel/geysermc`.

The Compose example also uses ViaProxy's official image to translate Geyser's
current Java protocol for an older Vanilla server:

```text
Bedrock client -> Geyser -> ViaProxy -> Vanilla server
UDP 19132         TCP 25568             TCP 25599
Java client ----------------> TCP 25565 (published)
```

The image downloads the official latest standalone JAR at build time and runs
it on Java 21. Runtime data is stored in `/data`, and Bedrock traffic is exposed
on UDP port `19132` by default.

## Quick start

Copy the example environment file, adjust the Java server address, then start
the service:

```sh
cp .env.example .env
mkdir -p geyser-data mc-data
docker compose pull
docker compose up -d geyser
docker compose logs -f geyser
```

To use the published image without building locally:

```sh
docker pull aspel/geysermc:latest
docker compose up -d
```

The default Compose file is pull-only and does not require a local Dockerfile.
For a source build, explicitly add the build override:

```sh
docker compose -f compose.yaml -f compose.build.yaml up --build -d geyser
```

With legacy Compose, replace `docker compose` with `docker-compose`.

Bedrock players connect to the Docker host on UDP port `19132`. Java players
connect to the Docker host on TCP port `25565`. Geyser reaches ViaProxy at
`viaproxy:25568`, and ViaProxy reaches the private Vanilla service at
`mc:25599`.

Generated configuration, keys, resource packs, extensions, and synchronized
JARs are kept in the host directory `./geyser-data`:

```sh
mkdir -p geyser-data mc-data
docker compose down
```

Minecraft worlds and server configuration are stored in `./mc-data`. Removing
containers does not delete either data directory. On Linux, ensure both are
writable by UID/GID `1000`:

```sh
sudo chown -R 1000:1000 geyser-data mc-data
```

ViaProxy is configured with CLI arguments and uses an ephemeral writable
`/app/run` tmpfs, avoiding host-directory permission problems.

## Vanilla through ViaProxy

The default Compose configuration publishes ViaProxy as host TCP `25565` for
Java players while keeping Vanilla private. ViaProxy connects to `mc:25599` and
automatically detects the Vanilla protocol.

ViaProxy terminates online-mode authentication before translating the protocol.
For multiple Bedrock players, use these settings:

```properties
# Generated Vanilla server.properties
online-mode=false
enforce-secure-profile=false
server-port=25599
```

```env
JAVA_AUTH_TYPE=online
VIAPROXY_PROXY_ONLINE_MODE=true
VIAPROXY_AUTH_METHOD=NONE
```

This keeps player authentication enabled at ViaProxy while the Vanilla backend
accepts the translated connection. Vanilla port `25599` is not published, so
clients cannot bypass ViaProxy. Public ViaProxy connections are protected by
`VIAPROXY_PROXY_ONLINE_MODE=true`.

`MINECRAFT_VERSION=LATEST` tracks the newest Vanilla release. ViaProxy is only
needed when the selected Vanilla version is older than the Java protocol Geyser
emulates; set a fixed `MINECRAFT_VERSION` when retaining an older world/server.

To target a specific Vanilla protocol instead of auto-detection, set its exact
ViaProxy version name in `.env`, for example:

```env
MINECRAFT_VERSION=1.21.4
VANILLA_PROTOCOL_VERSION=1.21.4
```

## Configuration

The Compose example uses Geyser's native command-line overrides, so it does not
need to modify the generated `config.yml`:

```yaml
command:
  - --nogui
  - --java.address=viaproxy
  - --java.port=25568
  - --java.auth-type=online
  - --command-suggestions=false
```

Any config key can be overridden in the same way. Nested keys use dot notation,
for example `--java.address=minecraft`. Arguments passed in `command:` are
appended after the JAR and override values in `config.yml`.

### Runtime updates

Set `GEYSER_SYNC=true` to download `GEYSER_DOWNLOAD_URL` every time the
container starts and run that JAR instead of the copy embedded in the image:

```env
GEYSER_SYNC=true
GEYSER_DOWNLOAD_URL=https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/standalone
GEYSER_SHA256=
```

The download is written to a temporary file and atomically moved to
`/data/geyser.jar`, so an interrupted download cannot replace the last complete
file. A download or checksum failure stops startup. Set `GEYSER_SHA256` when
using a fixed build URL; a checksum cannot remain valid when a `latest` URL
changes. The default remains `false` because an image whose executable changes
at startup is less reproducible and requires outbound network access.

The standalone-specific arguments are:

| Argument | Purpose |
| --- | --- |
| `--config /data/custom.yml` | Use an alternative config file |
| `--nogui` | Force console mode; this is the image default |
| `--gui` | Force GUI mode; not useful in a headless container |

### Environment variables

The entrypoint translates the documented environment variables below into JVM
system properties. Leave a variable unset to use Geyser's default.

| Environment variable | Geyser system property | Documented default |
| --- | --- | --- |
| `GEYSER_UDP_PORT` | `geyserUdpPort` | Config value |
| `GEYSER_UDP_ADDRESS` | `geyserUdpAddress` | Config value |
| `GEYSER_BROADCAST_PORT` | `geyserBroadcastPort` | Listener port |
| `GEYSER_PRINT_SECURE_CHAT_INFORMATION` | `Geyser.PrintSecureChatInformation` | `true` |
| `GEYSER_SHOW_SCOREBOARD_LOGS` | `Geyser.ShowScoreboardLogs` | `true` |
| `GEYSER_SHOW_RESOURCE_PACK_LENGTH_WARNING` | `Geyser.ShowResourcePackLengthWarning` | `true` |
| `GEYSER_PRINT_PINGS_IN_DEBUG_MODE` | `Geyser.PrintPingsInDebugMode` | `true` |
| `GEYSER_USE_DIRECT_ADAPTERS` | `Geyser.UseDirectAdapters` | `true` |
| `GEYSER_BEDROCK_NETWORK_THREADS` | `Geyser.BedrockNetworkThreads` | Auto |
| `GEYSER_ADD_TEAM_SUGGESTIONS` | `Geyser.AddTeamSuggestions` | `true` |
| `GEYSER_NO_PLAYER_LIST_PS` | `Geyser.NoPlayerListPS` | `false` |
| `GEYSER_RAK_PACKET_LIMIT` | `Geyser.RakPacketLimit` | `120` |
| `GEYSER_RAK_GLOBAL_PACKET_LIMIT` | `Geyser.RakGlobalPacketLimit` | `100000` |
| `GEYSER_RAK_RATE_LIMITING_DISABLED` | `Geyser.RakRateLimitingDisabled` | `false` |
| `GEYSER_RAK_SEND_COOKIE` | `Geyser.RakSendCookie` | `true` |

Warnings and RakNet protections should only be disabled when the consequences
are understood. In particular, keep rate limiting and cookie validation enabled
unless an upstream UDP reverse proxy provides equivalent protection.

`JAVA_TOOL_OPTIONS` is passed directly to the JVM. The default sizes the heap
relative to the Compose memory limit, which is controlled by `MEMORY_LIMIT` and
defaults to `1G`. You can replace it with explicit settings such as
`-Xms512M -Xmx1G -XX:+UseG1GC`.

## Reproducible builds

The default URL deliberately tracks Geyser's latest build. For a reproducible
image, use a versioned official download URL and its SHA-256 checksum:

```sh
docker build \
  --build-arg GEYSER_DOWNLOAD_URL='https://download.geysermc.org/v2/projects/geyser/versions/VERSION/builds/BUILD/downloads/standalone' \
  --build-arg GEYSER_SHA256='EXPECTED_SHA256' \
  -t geysermc-standalone:VERSION .
```

When `GEYSER_SHA256` is set, the build fails if the downloaded JAR does not
match. Rebuild the image to pick up a new latest Geyser release.

## Publishing

The GitHub Actions workflow publishes multi-architecture `linux/amd64` and
`linux/arm64` images to `aspel/geysermc`. Configure these repository secrets:

- `DOCKERHUB_USERNAME`: your Docker Hub username (`aspel`)
- `DOCKERHUB_TOKEN`: a Docker Hub access token with write permission

Create the `aspel/geysermc` repository in Docker Hub before the first publish.

Every run publishes one immutable UTC date and short commit tag in
`YYYY-MM-DD.<sha>` format, for example `2026-07-04.90dd603`. Pushes to `main`
also publish `latest`. Tags such as `v1.2.3` publish `1.2.3` and `1.2`. A manual
**Run workflow** can optionally set a custom Docker tag such as `stable` or
`2.10.1`.

For a manual local publish of the current architecture:

```sh
docker login
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --pull --push \
  -t aspel/geysermc:latest .
```

## Operational notes

- Publish the Bedrock port as UDP, not TCP.
- Use `online` authentication for normal online-mode servers. Use `floodgate`
  only when Floodgate is installed and configured on the Java server.
- The container runs as UID/GID `1000`, drops Linux capabilities, and uses a
  read-only root filesystem in the Compose example.
- `/tmp` is a small executable tmpfs because Netty loads its native networking
  library from that location; do not change it to `noexec` without moving
  Netty's native work directory.
- `/data` must remain writable. With a bind mount, make the host directory
  writable by UID/GID `1000` before startup.
- Geyser Standalone is a separate proxy process, not a Minecraft plugin.

See the official [Geyser setup guide](https://geysermc.org/wiki/geyser/setup/)
and [command-line/system-property reference](https://geysermc.org/wiki/geyser/geyser-command-line-arguments-and-system-properties/)
for upstream details.
