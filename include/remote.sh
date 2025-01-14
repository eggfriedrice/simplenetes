# All REMOTELY EXECUTED functionality
#

# host: host[:pathToHostEnvFile]
# Return 10 on internal error which is pointless retrying.
_REMOTE_EXEC()
{
    SPACE_SIGNATURE="host action [args]"
    # This env variable can be baked in at compile time if we want this module to be standalone
    SPACE_ENV="CLUSTERPATH REMOTE_PACK_RELEASEDATA=$ REMOTE_SET_COMMITCHAIN=$ REMOTE_ACQUIRE_LOCK=$ REMOTE_RELEASE_LOCK=$ REMOTE_GET_HOSTMETADATA=$ REMOTE_UPLOAD_ARCHIVE=$ REMOTE_UNPACK_ARCHIVE=$ REMOTE_INIT_HOST=$ REMOTE_HOST_SETUP=$ REMOTE_LOGS=$ REMOTE_DAEMON_LOG=$ REMOTE_CREATE_SUPERUSER=$ REMOTE_DISABLE_ROOT=$ REMOTE_SIGNAL=$ REMOTE_ACTION=$ REMOTE_POD_STATUS=$ REMOTE_POD_INFO=$ REMOTE_POD_SHELL=$ REMOTE_HOST_SHELL=$"
    SPACE_DEP="SSH PRINT STRING_TRIM"

    local host="${1}"
    shift

    local action="${1}"
    shift

    local hostEnv="${host#*:}"
    if [ "${hostEnv}" != "${host}" ]; then
        host="${host%%:*}"
    else
        hostEnv="${CLUSTERPATH}/${host}/host.env"
    fi

    PRINT "Connect to host ${host} with action: ${action}." "debug"

    # Load host env file
    if [ ! -f "${hostEnv}" ]; then
        PRINT "${hostEnv} file does not exist." "error" 0
        return 10
    fi

    local HOSTHOME=
    local HOST=
    local value=
    local varname=
    for varname in HOSTHOME HOST; do
        value="$(grep -m 1 "^${varname}=" "${hostEnv}")"
        value="${value#*${varname}=}"
        STRING_TRIM "value"
        eval "${varname}=\"\${value}\""
    done

    if [ -z "${HOSTHOME}" ]; then
        HOSTHOME="cluster-host"
    fi

    if [ "${HOST}" = "local" ]; then
        PRINT "Connecting directly on local disk using shell" "debug"
    fi

    # Check if we have the script exported already
    local RUN=
    case "${action}" in
        "pack_release_data")
            if [ -n "${REMOTE_PACK_RELEASEDATA}" ]; then
                RUN="${REMOTE_PACK_RELEASEDATA}"
            fi
            ;;
        "set_commit_chain")
            if [ -n "${REMOTE_SET_COMMITCHAIN}" ]; then
                RUN="${REMOTE_SET_COMMITCHAIN}"
            fi
            ;;
        "acquire_lock")
            if [ -n "${REMOTE_ACQUIRE_LOCK}" ]; then
                RUN="${REMOTE_ACQUIRE_LOCK}"
            fi
            ;;
        "release_lock")
            if [ -n "${REMOTE_RELEASE_LOCK}" ]; then
                RUN="${REMOTE_RELEASE_LOCK}"
            fi
            ;;
        "get_host_metadata")
            if [ -n "${REMOTE_GET_HOSTMETADATA}" ]; then
                RUN="${REMOTE_GET_HOSTMETADATA}"
            fi
            ;;
        "upload_archive")
            if [ -n "${REMOTE_UPLOAD_ARCHIVE}" ]; then
                RUN="${REMOTE_UPLOAD_ARCHIVE}"
            fi
            ;;
        "unpack_archive")
            if [ -n "${REMOTE_UNPACK_ARCHIVE}" ]; then
                RUN="${REMOTE_UNPACK_ARCHIVE}"
            fi
            ;;
        "init_host")
            if [ -n "${REMOTE_INIT_HOST}" ]; then
                RUN="${REMOTE_INIT_HOST}"
            fi
            ;;
        "setup_host")
            if [ -n "${REMOTE_HOST_SETUP}" ]; then
                RUN="${REMOTE_HOST_SETUP}"
            fi
            ;;
        "logs")
            if [ -n "${REMOTE_LOGS}" ]; then
                RUN="${REMOTE_LOGS}"
            fi
            ;;
        "pod_info")
            if [ -n "${REMOTE_POD_INFO}" ]; then
                RUN="${REMOTE_POD_INFO}"
            fi
            ;;
        "pod_status")
            if [ -n "${REMOTE_POD_STATUS}" ]; then
                RUN="${REMOTE_POD_STATUS}"
            fi
            ;;
        "signal")
            if [ -n "${REMOTE_SIGNAL}" ]; then
                RUN="${REMOTE_SIGNAL}"
            fi
            ;;
        "action")
            if [ -n "${REMOTE_ACTION}" ]; then
                RUN="${REMOTE_ACTION}"
            fi
            ;;
        "daemon_log")
            if [ -n "${REMOTE_DAEMON_LOG}" ]; then
                RUN="${REMOTE_DAEMON_LOG}"
            fi
            ;;
        "create_superuser")
            if [ -n "${REMOTE_CREATE_SUPERUSER}" ]; then
                RUN="${REMOTE_CREATE_SUPERUSER}"
            fi
            ;;
        "disable_root")
            if [ -n "${REMOTE_DISABLE_ROOT}" ]; then
                RUN="${REMOTE_DISABLE_ROOT}"
            fi
            ;;
        "pod_shell")
            if [ -n "${REMOTE_POD_SHELL}" ]; then
                RUN="${REMOTE_POD_SHELL}"
            fi
            ;;
        "host_shell")
            if [ -n "${REMOTE_HOST_SHELL}" ]; then
                RUN="${REMOTE_HOST_SHELL}"
            fi
            ;;
        *)
            # Unknown action type
            PRINT "Unknown action type: ${action}." "error"
            return 10
            ;;
    esac

    if [ -n "${RUN}" ]; then
        if [ "${HOST}" = "local" ]; then
            sh -c "${RUN}" "sh" "${HOSTHOME}" "$@"
        else
            SSH "" "" "" "" "" "${hostEnv}" "" "${RUN}" "${HOSTHOME}" "$@"
        fi
    else
        # Run the space target to do this. This is usually only done in dev mode when we are working with the sns source.
        if [ "${HOST}" = "local" ]; then
            space -L "${SPACE_LOG_LEVEL}" -f "${0}" /_remote_plumbing/${action}/ -- "${HOSTHOME}" "$@"
        else
            space -L "${SPACE_LOG_LEVEL}" -f "${0}" /_remote_plumbing/${action}/ -m ssh /wrap/ -e SSHHOSTFILE="${hostEnv}" -- "${HOSTHOME}" "$@"
        fi
    fi
}

# user pub key comes on stdin
_REMOTE_CREATE_SUPERUSER()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome user]"
    SPACE_DEP="_OS_CREATE_USER OS_MKSUDO_USER"

    local hosthome="${1}"
    shift

    local user="${1}"
    shift

    _OS_CREATE_USER "${user}" &&
    OS_MKSUDO_USER "${user}"
}

_REMOTE_DISABLE_ROOT()
{
    SPACE_SIGNATURE=""
    SPACE_DEP="OS_DISABLE_ROOT"

    OS_DISABLE_ROOT
}

_REMOTE_INIT_HOST()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome clusterID force]"
    SPACE_DEP="PRINT STRING_SUBSTR FILE_REALPATH"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local clusterID="${1}"
    shift

    local force="${1}"
    shift

    local file="${HOSTHOME}/cluster-id.txt"
    if [ -f "${file}" ]; then
        local id="$(cat "${file}")"
        if [ "${id}" != "${clusterID}" ] && [ "${force}" != "true" ]; then
            return 2
        fi
    fi

    mkdir -p "${HOSTHOME}/pods"
    printf "%s\\n" "${clusterID}" >"${file}"

    # Get the config.json on STDIN
    local content="$(cat)"

    if [ -n "${content}" ]; then
        mkdir -p "${HOME}/.docker"
        printf "%s\\n" "${content}" >"${HOME}/.docker/config.json"
    fi

    PRINT "Host successfully inited at ${HOSTHOME} for cluster ${clusterID}." "ok" 0
}

_REMOTE_DAEMON_LOG()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome]"

    journalctl -u simplenetesd
}

_REMOTE_SIGNAL()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome pod podVersion container]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local pod="${1}"
    shift

    local podVersion="${1}"
    shift

    local podFile="${HOSTHOME}/pods/${pod}/release/${podVersion}/pod"

    if [ ! -f "${podFile}" ]; then
        PRINT "Missing pod: ${pod}:${podVersion}" "error" 0
        return 1
    fi

    ${podFile} signal "$@"
}

_REMOTE_ACTION()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome pod podVersion action]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local pod="${1}"
    shift

    local podVersion="${1}"
    shift

    local podFile="${HOSTHOME}/pods/${pod}/release/${podVersion}/pod"

    if [ ! -f "${podFile}" ]; then
        PRINT "Missing pod: ${pod}:${podVersion}" "error" 0
        return 1
    fi

    printf "%s\\n" "$*" >"${podFile}.action"
}

_REMOTE_HOST_SHELL()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome useBash commands]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT STRING_ESCAPE"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local useBash="${1:-false}"
    shift

    if [ -d "${HOSTHOME}" ]; then
        cd "${HOSTHOME}"
    fi

    local sh="env sh"

    if [ "${useBash}" = "true" ]; then
        sh="env bash"
    fi

    if [ "$#" -gt 0 ]; then
        local cmds="$*"
        STRING_ESCAPE "cmds" '"'
        ${sh} -c "${cmds}"
    else
        ${sh}
    fi
}

_REMOTE_POD_SHELL()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome pod podVersion container useBash commands]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local pod="${1}"
    shift

    local podVersion="${1}"
    shift

    local container="${1}"
    shift

    local useBash="${1:-false}"
    shift

    local podFile="${HOSTHOME}/pods/${pod}/release/${podVersion}/pod"

    if [ ! -f "${podFile}" ]; then
        PRINT "Missing pod: ${pod}:${podVersion}" "error" 0
        return 10
    fi

    if [ "${useBash}" = "true" ]; then
        ${podFile} "shell" "${container}" -b "$@"
    else
        ${podFile} "shell" "${container}" "$@"
    fi
}

_REMOTE_POD_INFO()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome pod podVersion]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local pod="${1}"
    shift

    local podVersion="${1}"
    shift

    local podFile="${HOSTHOME}/pods/${pod}/release/${podVersion}/pod"

    if [ ! -f "${podFile}" ]; then
        PRINT "Missing pod: ${pod}:${podVersion}" "error" 0
        return 10
    fi

    ${podFile} info
}

_REMOTE_POD_STATUS()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome pod podVersion query]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local pod="${1}"
    shift

    local podVersion="${1}"
    shift

    local query="${1}"
    shift

    local podFile="${HOSTHOME}/pods/${pod}/release/${podVersion}/pod"

    if [ ! -f "${podFile}" ]; then
        PRINT "Missing pod: ${pod}:${podVersion}" "error" 0
        return 10
    fi

    if [ "${query}" = "readiness" ]; then
        if ${podFile} readiness; then
            printf "ready\\n"
        else
            printf "not-ready\\n"
        fi
    else
        ${podFile} ps
    fi
}

_REMOTE_LOGS()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome pod podVersion timestamp limit streams details showProcessLog containers]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local pod="${1}"
    shift

    local podVersion="${1}"
    shift

    local timestamp="${1}"
    shift

    local limit="${1}"
    shift

    local streams="${1}"
    shift

    local details="${1}"
    shift

    local showProcessLog="${1}"
    shift

    local podFile="${HOSTHOME}/pods/${pod}/release/${podVersion}/pod"

    if [ ! -f "${podFile}" ]; then
        PRINT "Missing pod: ${pod}:${podVersion}" "error" 0
        return 1
    fi

    if [ "${showProcessLog}" = "true" ]; then
        ${podFile} logs ${limit:+-l $limit} ${timestamp:+-t $timestamp} ${streams:+-s $streams} ${details:+-d $details} -p "$@"
    else
        ${podFile} logs ${limit:+-l $limit} ${timestamp:+-t $timestamp} ${streams:+-s $streams} ${details:+-d $details} "$@"
    fi
}

# Public key of new user must come on stdin
_REMOTE_HOST_SETUP()
{
    # Actually not optional arguments
    SPACE_SIGNATURE="[hosthome user superuser ports internals skipFirewall skipSystemd skipPodman]"
    SPACE_DEP="PRINT OS_INSTALL_PKG _OS_CREATE_USER FILE_ROW_REMOVE FILE_ROW_PERSIST"

    local hosthome="${1}"
    shift

    local user="${1}"
    shift

    local superuser="${1}"
    shift

    local ports="${1}"
    shift

    local internals="${1}"
    shift

    local skipFirewall="${1:-false}"
    shift $(($# > 0 ? 1 : 0))

    local skipSystemd="${1:-false}"
    shift $(($# > 0 ? 1 : 0))

    local skipPodman="${1:-false}"
    shift $(($# > 0 ? 1 : 0))

    if [ $(id -u) != 0 ]; then
        PRINT "This needs to be run as root." "error" 0
        return 1
    fi

    # Catch all pub keys coming in on stdin
    local contents="$(cat)"

    # Extract user keys and super user keys
    local pubKeyLines=""
    local superPubKeyLines=""
    local stage=0
    local ifs="${IFS}"
    IFS="
"
    for line in ${contents}; do
        if [ "${line}" = "---" ]; then
            stage=$((stage+1))
            continue
        fi
        if [ "${stage}" -eq 0 ]; then
            pubKeyLines="${pubKeyLines}${line}
"
        elif [ "${stage}" -eq 1 ]; then
            superPubKeyLines="${superPubKeyLines}${line}
"
        else
            return 1
        fi
    done
    IFS="${ifs}"

    if [ -z "${pubKeyLines}" ] || [ -z "${superPubKeyLines}" ]; then
        PRINT "Missing keys on stdin." "error" 0
        return 1
    fi

    local singleKey="$(printf "%s\\" "${pubKeyLines}" | head -n1)"

    # Create regular user, but we can only pass a single pub key.
    # NOTE: pub key on stdin will get written to ~/.ssh/authorized_keys
    if ! printf "%s\\n" "${singleKey}" | _OS_CREATE_USER "${user}"; then
        PRINT "Could not create user ${user}" "error" 0
        return 1
    fi

    # Now write the complete user authorized_keys file
    local authorized_keys="/home/${user}/.ssh/authorized_keys"
    printf "%s" "${pubKeyLines}" >"${authorized_keys}"

    # Write the super user keys
    local authorized_keys="/home/${superuser}/.ssh/authorized_keys"
    printf "%s" "${superPubKeyLines}" >"${authorized_keys}"

    if [ "${skipPodman}" != "true" ]; then
        # Install podman
        if ! OS_INSTALL_PKG "podman"; then
            PRINT "Could not install podman" "error" 0
        fi
        local podmanVersion="$(podman --version)"
        PRINT "Installed ${podmanVersion}" "info" 0

        # Check /etc/subgid /etc/subuid
        # Note: not sure this matters anymore since the actual file
        # is changed later when looking at it.

        if ! grep -q "^${user}:" "/etc/subgid"; then
            PRINT "Adding user to /etc/subgid" "info" 0
            printf "%s:90000:9999\\n" "${user}" >>"/etc/subgid"
            podman system migrate
        fi

        if ! grep -q "^${user}:" "/etc/subuid"; then
            PRINT "Adding user to /etc/subuid" "info" 0
            printf "%s:90000:9999\\n" "${user}" >>"/etc/subuid"
            podman system migrate
        fi

        # Allow for users to bind from port 1 and updwards
        FILE_ROW_REMOVE "net.ipv4.ip_unprivileged_port_start=.*" "/etc/sysctl.conf"
        FILE_ROW_PERSIST "net.ipv4.ip_unprivileged_port_start=1" "/etc/sysctl.conf"

        if  command -v sysctl >/dev/null 2>/dev/null; then
            loginctl enable-linger "${user}"
            sysctl --system
        else
            PRINT "sysctl not present, the server might have to be restarted for /etc/sysctl.conf changes to be enabled." "warn" 0
        fi
    fi


    if [ "${skipFirewall}" != "true" ]; then
        # Configure firewalld
        # Note: We might want to add another "internal" zone, instead of adding the rich rule for internal networking onto the default zone.
        if ! command -v firewall-cmd >/dev/null 2>/dev/null; then
            PRINT "firewall-cmd not existing, cannot configure firewall to expose/hide ports. You need to make sure that worker machines are not exposed to the internet, but only to the local network and that the loadbalancers are properly exposed. This problem can go away if you choose a CentOS image." "security" 0
            # Best way to catch users interest is to stall the terminal.
            sleep 3
        else
            local port=
            for port in $(firewall-cmd --list-ports); do
                PRINT "Remove port ${port}" "info" 0
                firewall-cmd --permanent --remove-port "${port}"
            done
            if [ -n "${ports}" ]; then
                local port=
                for port in ${ports}; do
                    PRINT "Open port ${port}/tcp" "info" 0
                    firewall-cmd --permanent --add-port=${port}/tcp
                done
            fi
            # Remove any preadded ssh service, we do everything using port numbers.
            if firewall-cmd --list-services |grep -q "\<ssh\>"; then
                PRINT "Trim services of firewalld" "info" 0
                firewall-cmd --permanent --remove-service ssh
            fi
            local rules=
            rules="$(firewall-cmd --list-rich-rules)"
            local _ifs="$IFS"
            IFS="
"
            local rule=
            for rule in ${rules}; do
                PRINT "Remove current rich rule: ${rule}" "info" 0
                firewall-cmd --permanent --remove-rich-rule "${rule}"
            done
            IFS="${_ifs}"

            # Add a rule to allow all traffic from internal IPs
            # Without this rule only the specific ports opened are available to the internal networking.
            local network=
            for network in ${internals}; do
                PRINT "Add rich rule for: ${network}" "info" 0
                if ! firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="'${network}'" accept'; then
                    PRINT "Could not add internal networking, adding some for rescue mode" "error" 0
                    # TODO: not sure this is the correct way of setting the internal networks
                    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.0.0/16" accept'
                    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.0.0/8" accept'
                    break
                fi
            done

            PRINT "Reload firewall" "info" 0
            firewall-cmd --reload
        fi
    fi

    if [ "${skipSystemd}" != "true" ]; then
        if ! command -v systemctl >/dev/null 2>/dev/null; then
            PRINT "systemctl not present, cannot configure systemd" "error" 0
            return 1
        fi

        # Download the simplenetes daemon.
        # Check if the version changed, in such case overwrite it, overwrite the unit file and re-start the service.

        local tag="0.6.1"
        local version="Simplenetesd 0.6.1"

        local binaryUpdate="true"
        local daemonFile="/bin/simplenetesd"
        if [ -f "${daemonFile}" ]; then
            # Check version
            local ver="$("${daemonFile}" -V)"
            if [ "${ver}" = "${version}" ]; then
                binaryUpdate="false"
            fi
        fi

        if [ "${binaryUpdate}" = "true" ]; then
            if ! OS_INSTALL_PKG "curl"; then
                PRINT "Could not install curl" "error" 0
            fi
            PRINT "Downloading daemon binary" "info" 0
            if ! curl -sLO "https://raw.githubusercontent.com/simplenetes-io/simplenetesd/${tag}/release/simplenetesd"; then
                PRINT "Could not download the simplenetesd binary" "error" 0
                return 1
            fi
            chmod +x simplenetesd
            sudo mv simplenetesd "${daemonFile}"
        else
            PRINT "Daemon binary version already exists" "info" 0
        fi

        # Make sure the bin is managed by systemd.
        local file="/etc/systemd/system/simplenetesd.service"
        local unit="[Unit]
Description=Simplenetes Daemon managing pods and ramdisks
After=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/root
ExecStart=/usr/bin/env sh ${daemonFile}
Restart=always
KillMode=process

[Install]
WantedBy=multi-user.target"

        local exists="false"
        if [ -f "${file}" ]; then
            exists="true"
        fi

        if [ "${exists}" = "false" ] || ! (printf "%s\\n" "${unit}" | diff "${file}" "-" >/dev/null 2>&1); then
            PRINT "Installing systemd service" "info" 0

            printf "%s\\n" "${unit}" >"${file}"
            if [ "${exists}" = "true" ]; then
                PRINT "Daemon reload" "info" 0
                systemctl daemon-reload
            fi

            PRINT "Starting and enabling daemon service" "info" 0
            systemctl enable simplenetesd
            systemctl restart simplenetesd
        else
            PRINT "No change in systemd service" "info" 0
            if [ "${binaryUpdate}" = "true" ]; then
                PRINT "simplenetesd binary updated, restarting service" "info" 0
                systemctl restart simplenetesd
            fi
        fi
    fi
}

_REMOTE_ACQUIRE_LOCK()
{
    # Arguments are actually not optional, but we set them within [] so that the exporting does not complain.
    SPACE_SIGNATURE="[hosthome token seconds]"
    SPACE_DEP="PRINT STRING_SUBSTR FILE_REALPATH FILE_STAT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local token="${1}"
    shift

    local seconds="${1}"
    shift

    if [ ! -d "${HOSTHOME}/pods" ] || [ ! -f "${HOSTHOME}/cluster-id.txt" ]; then
        PRINT "Host is not initialized." "error" 0
        return 1
    fi

    local file="${HOSTHOME}/lock-token.txt"

    if [ -f "${file}" ]; then
        local currentToken="$(cat "${file}")"
        if [ "${currentToken}" = "${token}" ]; then
            # Pass through
            :
        else
            # Check timestamp
            local ts="$(FILE_STAT "${file}" "%Y")"
            local now="$(date +%s)"
            local age="$((now-ts))"
            if [ "${age}" -lt "${seconds}" ]; then
                # Lock busy
                return 2
            fi
        fi
    fi

    printf "%s\\n" "${token}" >"${file}"
}

_REMOTE_SET_COMMITCHAIN()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome gitCommitChain]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local chain="${1}"
    shift

    printf "%s\\n" "${chain}" >"${HOSTHOME}/commit-chain.txt"
}

_REMOTE_RELEASE_LOCK()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome token]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local token="${1}"
    shift

    local file="${HOSTHOME}/lock-token.txt"

    if [ -f "${file}" ]; then
        local currentToken="$(cat "${file}")"
        if [ "${currentToken}" = "${token}" ]; then
            rm "${file}"
        else
            PRINT "Cannot release lock, because it does not belong to us." "error" 0
            return 2
        fi
    fi
}

# This is run on host and gets the cluster metadata
_REMOTE_GET_HOST_METADATA()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome]"
    SPACE_DEP="STRING_SUBSTR FILE_REALPATH"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    local clusterID="$(cat "${HOSTHOME}/cluster-id.txt" 2>/dev/null)"
    local chain="$(cat "${HOSTHOME}/commit-chain.txt" 2>/dev/null)"
    printf "%s %s\\n" "${clusterID}" "${chain}"
}

_REMOTE_PACK_RELEASE_DATA()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome]"
    SPACE_DEP="_SYNC_REMOTE_PACK_RELEASE_DATA"

    _SYNC_REMOTE_PACK_RELEASE_DATA "$@"
}

# This is run on the host.
# It retrieves a tar.gz file on stdin.
_REMOTE_UPLOAD_ARCHIVE()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome]"
    SPACE_DEP="_UTIL_GET_TMP_FILE STRING_SUBSTR FILE_REALPATH PRINT"

    local HOSTHOME="${1}"
    shift
    if [ "$(STRING_SUBSTR "${HOSTHOME}" 0 1)" != '/' ]; then
        HOSTHOME="$(FILE_REALPATH "${HOSTHOME}" "${HOME}")"
    fi

    # Indicate we are still busy
    touch "${HOSTHOME}/lock-token.txt"

    local file="$(_UTIL_GET_TMP_FILE)"

    PRINT "Receive archive on host to file ${file}" "debug" 0

    # Tell the caller the path of tmpfile.
    printf "%s\\n" "${file}"

    # Receive tar.gz content on stdin and store it to file.
    cat >"${file}"
}

_REMOTE_UNPACK_ARCHIVE()
{
    # Arguments are actually not optional, but we do this so the exporting goes smoothly.
    SPACE_SIGNATURE="[hosthome targzfile]"
    SPACE_DEP="_SYNC_REMOTE_UNPACK_ARCHIVE"

    _SYNC_REMOTE_UNPACK_ARCHIVE "$@"
}
