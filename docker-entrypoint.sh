#!/bin/sh
set -eu
set -f

java_properties=""
geyser_jar="/opt/geyser/geyser.jar"
sync_temp=""

cleanup() {
    if [ -n "${sync_temp}" ]; then
        rm -f "${sync_temp}"
    fi
}

trap cleanup EXIT
trap 'exit 143' HUP INT TERM

case "${GEYSER_SYNC:-false}" in
    true|TRUE|1|yes|YES)
        sync_temp="$(mktemp /data/.geyser.jar.XXXXXX)"
        echo "Downloading the latest Geyser JAR from ${GEYSER_DOWNLOAD_URL}..."
        curl --fail --location --retry 5 --retry-all-errors \
            --silent --show-error \
            --output "${sync_temp}" "${GEYSER_DOWNLOAD_URL}"

        if [ -n "${GEYSER_SHA256:-}" ]; then
            printf '%s  %s\n' "${GEYSER_SHA256}" "${sync_temp}" | sha256sum -c -
        fi

        mv -f "${sync_temp}" /data/geyser.jar
        sync_temp=""
        geyser_jar="/data/geyser.jar"
        ;;
    false|FALSE|0|no|NO|"")
        ;;
    *)
        echo "Error: GEYSER_SYNC must be true or false" >&2
        exit 64
        ;;
esac

add_property() {
    env_name="$1"
    property_name="$2"
    property_value="$(printenv "${env_name}" 2>/dev/null || true)"

    if [ -n "${property_value}" ]; then
        case "${property_value}" in
            *[[:space:]]*)
                echo "Error: ${env_name} must not contain whitespace" >&2
                exit 64
                ;;
        esac
        java_properties="${java_properties} -D${property_name}=${property_value}"
    fi
}

# Geyser's property names are case-sensitive. Environment variables use a
# container-friendly naming convention and are translated here.
add_property GEYSER_UDP_PORT geyserUdpPort
add_property GEYSER_UDP_ADDRESS geyserUdpAddress
add_property GEYSER_BROADCAST_PORT geyserBroadcastPort
add_property GEYSER_PRINT_SECURE_CHAT_INFORMATION Geyser.PrintSecureChatInformation
add_property GEYSER_SHOW_SCOREBOARD_LOGS Geyser.ShowScoreboardLogs
add_property GEYSER_SHOW_RESOURCE_PACK_LENGTH_WARNING Geyser.ShowResourcePackLengthWarning
add_property GEYSER_PRINT_PINGS_IN_DEBUG_MODE Geyser.PrintPingsInDebugMode
add_property GEYSER_USE_DIRECT_ADAPTERS Geyser.UseDirectAdapters
add_property GEYSER_BEDROCK_NETWORK_THREADS Geyser.BedrockNetworkThreads
add_property GEYSER_ADD_TEAM_SUGGESTIONS Geyser.AddTeamSuggestions
add_property GEYSER_NO_PLAYER_LIST_PS Geyser.NoPlayerListPS
add_property GEYSER_RAK_PACKET_LIMIT Geyser.RakPacketLimit
add_property GEYSER_RAK_GLOBAL_PACKET_LIMIT Geyser.RakGlobalPacketLimit
add_property GEYSER_RAK_RATE_LIMITING_DISABLED Geyser.RakRateLimitingDisabled
add_property GEYSER_RAK_SEND_COOKIE Geyser.RakSendCookie

# JAVA_TOOL_OPTIONS is parsed by the JVM itself. The generated properties are
# intentionally expanded here because each value becomes one JVM argument.
# shellcheck disable=SC2086
exec java ${java_properties} -jar "${geyser_jar}" "$@"
