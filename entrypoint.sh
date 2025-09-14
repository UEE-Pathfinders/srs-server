#!/bin/bash
# SRS Server Configuration and Startup Script

set -e
CONFIG_FILE="/opt/srs/cfg/server.cfg"
PRESETS_DIR="/opt/srs/cfg/Presets"
LOGS_DIR="/opt/srs/logs"
CFG_DIR="/opt/srs/cfg"

# ============================================================================  
# CREATE REQUIRED DIRECTORIES  
# ============================================================================  
echo "Creating required SRS server directories..."

if [ ! -d "$PRESETS_DIR" ] || [ -z "$(find "$PRESETS_DIR" -type f -name '*.txt' -print -quit)" ]; then
    echo "Creating Presets directory and initializing default (if needed)..."
    mkdir -p "$PRESETS_DIR"
    chmod 755 "$PRESETS_DIR"
else
    echo "Presets directory exists and contains preset files. Skipping creation."
fi

mkdir -p "$LOGS_DIR"
chmod 755 "$LOGS_DIR"
echo "Created directory: logs"

mkdir -p "$CFG_DIR"
chmod 755 "$CFG_DIR"
echo "Created directory: cfg"
echo ""

# ============================================================================  
# GENERATE CONFIGURATION FILE IF MISSING  
# ============================================================================  

# Function to generate server.cfg if missing
generate_server_cfg() {
    local cfg_file="/opt/srs/cfg/server.cfg"
    
    if [ ! -f "$cfg_file" ]; then
        echo "server.cfg not found. Generating default configuration..."
        
        # Create cfg directory if it doesn't exist
        mkdir -p /opt/srs/cfg
        
        # Try to run SRS binary briefly to generate default config
        echo "Running SRS binary to generate default configuration..."
        timeout 10s /opt/srs/SRS-Server-Commandline --generateconfig || {
            echo "Failed to generate config with --generateconfig, trying alternative method..."
            
            # If --generateconfig doesn't work, try running briefly and stopping
            timeout 5s /opt/srs/SRS-Server-Commandline > /dev/null 2>&1 || true
        }
        
        # If config still doesn't exist, create a basic template
        if [ ! -f "$cfg_file" ]; then
            echo "Creating basic server.cfg template..."
            cat > "$cfg_file" << 'EOF'
{
  "Version": "2.3.0.3",
  "Port": 5002,
  "Bind": "0.0.0.0",
  "Coalition": {
    "RedPassword": "",
    "BluePassword": "",
    "SpectatorPassword": ""
  },
  "General": {
    "ServerName": "DCS-SRS Server",
    "AutoConnect": true,
    "ClientAutoConnect": true,
    "SendHeartbeat": true,
    "TestFrequencies": false,
    "AllowDCSPTT": true,
    "CoalitionAudioSecurity": false,
    "SpectatorAudioDisabled": true,
    "LotATCExport": false,
    "ExternalAWACSModePassword": "",
    "ExternalAWACSModePasswordBlue": "",
    "ExternalAWACSModePasswordRed": "",
    "StrictRadioFrequency": false,
    "RetransmitNodeLimit": 5,
    "RadioEncryptionEffects": true,
    "RadioSwitchIsPTT": false,
    "RequireAdmin": false,
    "CheckForBetaUpdates": false,
    "ClientIdleKick": 0,
    "RadioRxEffects": true,
    "RadioTxStartEffects": true,
    "RadioTxEndEffects": true,
    "AlwaysAllowHotasControls": false,
    "UPnPEnabled": true,
    "ExpandControls": false,
    "ShowTransmitterName": true,
    "GlobalLobbyFrequencies": "251.0,264.0,267.0,270.0,254.0,250.0,243.0,255.0,257.0,260.0,262.0,268.0",
    "RecordAudio": false,
    "AllowMultipleRadioSameFrequency": true,
    "DenyClientsNotInWhitelist": false,
    "VoiceCodecFrameRate": 1,
    "VoiceCodec": 4,
    "MinimumSampleRate": 16000
  },
  "RadioChannels": [],
  "RadioChannelsPresets": []
}
EOF
            echo "Basic server.cfg template created."
        else
            echo "server.cfg generated successfully."
        fi
    else
        echo "server.cfg already exists."
    fi
}

# Generate server.cfg if missing
generate_server_cfg

# ============================================================================  
# GENERATE CONFIGURATION FILE  
# ============================================================================  
echo "Generating SRS server configuration..."

# Generate REST API key if not provided
if [ -z "${SRS_REST_API_KEY:-}" ]; then
    # Generate a random UUID for the API key
    SRS_REST_API_KEY=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || openssl rand -hex 16)
    echo "Generated REST API key: $SRS_REST_API_KEY"
else
    echo "Using provided REST API key"
fi

# Remove existing configuration file if it exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Removing existing $CONFIG_FILE..."
    rm "$CONFIG_FILE"
fi

# [General Settings]
{
echo "[General Settings]"
echo "TRANSMISSION_LOG_ENABLED=${TRANSMISSION_LOG_ENABLED:-false}"
echo "CLIENT_EXPORT_ENABLED=${CLIENT_EXPORT_ENABLED:-false}"
echo "SERVER_PRESETS_ENABLED=${SERVER_PRESETS_ENABLED:-false}"
echo "LOTATC_EXPORT_ENABLED=${LOTATC_EXPORT_ENABLED:-false}"
echo "TEST_FREQUENCIES=${TEST_FREQUENCIES:-247.2,120.3}"
echo "GLOBAL_LOBBY_FREQUENCIES=${GLOBAL_LOBBY_FREQUENCIES:-248.22}"
echo "EXTERNAL_AWACS_MODE=${EXTERNAL_AWACS_MODE:-true}"
echo "COALITION_AUDIO_SECURITY=${COALITION_AUDIO_SECURITY:-false}"
echo "SPECTATORS_AUDIO_DISABLED=${SPECTATORS_AUDIO_DISABLED:-false}"
echo "LOS_ENABLED=${LOS_ENABLED:-false}"
echo "DISTANCE_ENABLED=${DISTANCE_ENABLED:-false}"
echo "IRL_RADIO_TX=${IRL_RADIO_TX:-false}"
echo "IRL_RADIO_RX_INTERFERENCE=${IRL_RADIO_RX_INTERFERENCE:-false}"
echo "RADIO_EXPANSION=${RADIO_EXPANSION:-true}"
echo "ALLOW_RADIO_ENCRYPTION=${ALLOW_RADIO_ENCRYPTION:-true}"
echo "STRICT_RADIO_ENCRYPTION=${STRICT_RADIO_ENCRYPTION:-false}"
echo "SHOW_TUNED_COUNT=${SHOW_TUNED_COUNT:-true}"
echo "RADIO_EFFECT_OVERRIDE=${RADIO_EFFECT_OVERRIDE:-false}"
echo "SHOW_TRANSMITTER_NAME=${SHOW_TRANSMITTER_NAME:-true}"
echo "TRANSMISSION_LOG_RETENTION=${TRANSMISSION_LOG_RETENTION:-2}"
echo "RETRANSMISSION_NODE_LIMIT=${RETRANSMISSION_NODE_LIMIT:-0}"
echo ""

# [Server Settings]
echo "[Server Settings]"
echo "CLIENT_EXPORT_FILE_PATH=/opt/srs/clients-list.json"
echo "SERVER_IP=${SERVER_IP:-0.0.0.0}"
echo "SERVER_PORT=${SERVER_PORT:-5002}"
echo "UPNP_ENABLED=${UPNP_ENABLED:-true}"
echo "CHECK_FOR_BETA_UPDATES=${CHECK_FOR_BETA_UPDATES:-false}"
echo "HTTP_SERVER_ENABLED=${HTTP_SERVER_ENABLED:-false}"
echo "HTTP_SERVER_PORT=${HTTP_SERVER_PORT:-8080}"
echo ""

# [HTTP/API Settings]
echo "[HTTP/API Settings]"
echo "SRS_REST_API_KEY=${SRS_REST_API_KEY}"
echo ""

# [AWACS Settings]
# Check if AWACS custom radios are enabled and file exists
if [ "${AWACS_CUSTOM_ENABLED:-false}" = "true" ]; then
    AWACS_FILE_PATH="${AWACS_CUSTOM_PATH:-/opt/srs/Presets/awacs-radios-custom.json}"
    if [ -f "$AWACS_FILE_PATH" ]; then
        echo "AWACS_RADIOS_FILE=${AWACS_FILE_PATH}"
        echo "AWACS_RADIOS_ENABLED=true"
        echo "Custom AWACS radios file enabled: $AWACS_FILE_PATH"
    else
        echo "AWACS_RADIOS_ENABLED=false"
        echo "Warning: AWACS_CUSTOM_ENABLED is true but file not found: $AWACS_FILE_PATH"
    fi
else
    echo "AWACS_RADIOS_ENABLED=false"
fi
echo ""

# [External AWACS Mode Settings]
echo "[External AWACS Mode Settings]"
echo "EXTERNAL_AWACS_MODE_BLUE_PASSWORD=${EXTERNAL_AWACS_MODE_BLUE_PASSWORD:-blue}"
echo "EXTERNAL_AWACS_MODE_RED_PASSWORD=${EXTERNAL_AWACS_MODE_RED_PASSWORD:-red}"
} > "$CONFIG_FILE"

# ============================================================================  
# DISPLAY CONFIGURATION STATUS  
# ============================================================================  
echo ""
echo "Current server.cfg:"
echo "==================="
cat "$CONFIG_FILE"
echo "==================="
echo ""

# ============================================================================  
# START THE SRS SERVER  
# ============================================================================  
echo "Starting SRS Server..."

# Build the startup command with required arguments
STARTUP_CMD="./SRS-Server-Commandline --cfg=$CONFIG_FILE --port=${SERVER_PORT:-5002} --serverBindIP=${SERVER_IP:-0.0.0.0}"

# Add server-side presets flag if enabled (SRS requires CLI flag even if config has setting)
if [ "${SERVER_PRESETS_ENABLED:-false}" = "true" ]; then
    STARTUP_CMD="$STARTUP_CMD --serverPresetChannelsEnabled=true"
    echo "Server-side presets enabled via command line argument"
fi

echo "Executing: $STARTUP_CMD"
exec $STARTUP_CMD