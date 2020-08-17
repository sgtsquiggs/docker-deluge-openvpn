#!/usr/bin/with-contenv bash

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [start-openvpn] $*"
}

VPN_PROVIDER="${OPENVPN_PROVIDER,,}"
VPN_PROVIDER_CONFIGS="/etc/openvpn/${VPN_PROVIDER}"

if [[ "${OPENVPN_PROVIDER}" == "**None**" ]] || [[ -z "${OPENVPN_PROVIDER-}" ]]; then
  log "OpenVPN provider not set. Exiting."
  exit 1
elif [[ ! -d "${VPN_PROVIDER_CONFIGS}" ]]; then
  log "Could not find OpenVPN provider: ${OPENVPN_PROVIDER}"
  log "Please check your settings."
  exit 1
fi

log "Using OpenVPN provider: ${OPENVPN_PROVIDER}"

if [[ "${OPENVPN_PROVIDER^^}" = "NORDVPN" ]]
then
    if [[ -z $NORDVPN_PROTOCOL ]]
    then
      export NORDVPN_PROTOCOL=UDP
    fi

    if [[ -z $NORDVPN_CATEGORY ]]
    then
      export NORDVPN_CATEGORY=P2P
    fi

    if [[ -n $OPENVPN_CONFIG ]]
    then
      tmp_Protocol="${OPENVPN_CONFIG##*.}"
      export NORDVPN_PROTOCOL=${tmp_Protocol^^}
      echo "Setting NORDVPN_PROTOCOL to: ${NORDVPN_PROTOCOL}"
      ${VPN_PROVIDER_CONFIGS}/updateConfigs.sh --openvpn-config
    elif [[ -n $NORDVPN_COUNTRY ]]
    then
      export OPENVPN_CONFIG=$(${VPN_PROVIDER_CONFIGS}/updateConfigs.sh)
    else
      export OPENVPN_CONFIG=$(${VPN_PROVIDER_CONFIGS}/updateConfigs.sh --get-recommended)
    fi
fi

if [[ -n "${OPENVPN_CONFIG-}" ]]; then
  readarray -t OPENVPN_CONFIG_ARRAY <<< "${OPENVPN_CONFIG//,/$'\n'}"
  ## Trim leading and trailing spaces from all entries. Inefficient as all heck, but works like a champ.
  for i in "${!OPENVPN_CONFIG_ARRAY[@]}"; do
    OPENVPN_CONFIG_ARRAY[${i}]="${OPENVPN_CONFIG_ARRAY[${i}]#"${OPENVPN_CONFIG_ARRAY[${i}]%%[![:space:]]*}"}"
    OPENVPN_CONFIG_ARRAY[${i}]="${OPENVPN_CONFIG_ARRAY[${i}]%"${OPENVPN_CONFIG_ARRAY[${i}]##*[![:space:]]}"}"
  done
  if (( ${#OPENVPN_CONFIG_ARRAY[@]} > 1 )); then
    OPENVPN_CONFIG_RANDOM=$((RANDOM%${#OPENVPN_CONFIG_ARRAY[@]}))
    log "${#OPENVPN_CONFIG_ARRAY[@]} servers found in OPENVPN_CONFIG, ${OPENVPN_CONFIG_ARRAY[${OPENVPN_CONFIG_RANDOM}]} chosen randomly"
    OPENVPN_CONFIG="${OPENVPN_CONFIG_ARRAY[${OPENVPN_CONFIG_RANDOM}]}"
  fi

  if [[ -f "${VPN_PROVIDER_CONFIGS}/${OPENVPN_CONFIG}.ovpn" ]]; then
    log "Starting OpenVPN using config ${OPENVPN_CONFIG}.ovpn"
    OPENVPN_CONFIG="${VPN_PROVIDER_CONFIGS}/${OPENVPN_CONFIG}.ovpn"
  else
    log "Supplied config ${OPENVPN_CONFIG}.ovpn could not be found."
    log "Using default OpenVPN gateway for provider ${VPN_PROVIDER}"
    OPENVPN_CONFIG="${VPN_PROVIDER_CONFIGS}/default.ovpn"
  fi
else
  log "No VPN configuration provided. Using default."
  OPENVPN_CONFIG="${VPN_PROVIDER_CONFIGS}/default.ovpn"
fi

# add OpenVPN user/pass
if [[ "${OPENVPN_USERNAME}" == "**None**" ]] || [[ "${OPENVPN_PASSWORD}" == "**None**" ]] ; then
  if [[ ! -f /config/openvpn-credentials.txt ]] ; then
    log "OpenVPN credentials not set. Exiting."
    exit 1
  fi
  log "Found existing OPENVPN credentials..."
else
  log "Setting OPENVPN credentials..."
  mkdir -p /config
  echo "${OPENVPN_USERNAME}" > /config/openvpn-credentials.txt
  echo "${OPENVPN_PASSWORD}" >> /config/openvpn-credentials.txt
  chmod 600 /config/openvpn-credentials.txt
fi

DELUGE_CONTROL_OPTS="--script-security 2 --up-delay --up /etc/openvpn/tunnelUp.sh --down /etc/openvpn/tunnelDown.sh"

exec openvpn ${DELUGE_CONTROL_OPTS} ${OPENVPN_OPTS} --config "${OPENVPN_CONFIG}"
