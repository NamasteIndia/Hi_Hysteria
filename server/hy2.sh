#!/bin/bash
hihyV="1.0.3"

# Function to detect virtualization type
detectVirtualization() {
    local virt_type=""
    
    # Check for OpenVZ
    if [ -f "/proc/user_beancounters" ]; then
        virt_type="openvz"
    # Check for LXC
    elif [ -f "/proc/1/environ" ] && grep -q "container=lxc" /proc/1/environ 2>/dev/null; then
        virt_type="lxc"
    # Check systemd-detect-virt (if available)
    elif command -v systemd-detect-virt >/dev/null 2>&1; then
        local detected=$(systemd-detect-virt 2>/dev/null)
        case "$detected" in
            "openvz") virt_type="openvz" ;;
            "lxc") virt_type="lxc" ;;
            "lxc-libvirt") virt_type="lxc" ;;
            *) virt_type="other" ;;
        esac
    # Check virtualization flags in /proc/cpuinfo
    elif grep -q "flags.*hypervisor" /proc/cpuinfo 2>/dev/null; then
        virt_type="other"
    # Check container identifiers in cgroup
    elif [ -f "/proc/1/cgroup" ]; then
        if grep -q ":/lxc/" /proc/1/cgroup 2>/dev/null; then
            virt_type="lxc"
        elif grep -q ":/docker/" /proc/1/cgroup 2>/dev/null; then
            virt_type="docker"
        else
            virt_type="unknown"
        fi
    else
        virt_type="unknown"
    fi
    
    echo "$virt_type"
}

# Function to get the command prefix (whether to use chrt)
getStartCommand() {
    local virt_type=$(detectVirtualization)
    local command_prefix=""
    
    case "$virt_type" in
        "openvz"|"lxc"|"docker")
            # Do not use chrt in OpenVZ, LXC, or Docker containers
            command_prefix=""
            ;;
        *)
            # Check for chrt support in other environments
            if command -v chrt >/dev/null 2>&1; then
                # Test if chrt is usable
                if chrt -r 1 echo "test" >/dev/null 2>&1; then
                    command_prefix="chrt -r 99"
                else
                    command_prefix=""
                fi
            else
                command_prefix=""
            fi
            ;;
    esac
    
    echo "$command_prefix"
}

cronTask() {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        echo "" > /etc/hihy/logs/hihy.log
    fi
}

echoColor() {
    case $1 in
        # Red
        "red") echo -e "\033[31m${printN}$2 \033[0m" ;;
        # Sky Blue
        "skyBlue") echo -e "\033[1;36m${printN}$2 \033[0m" ;;
        # Green
        "green") echo -e "\033[32m${printN}$2 \033[0m" ;;
        # White
        "white") echo -e "\033[37m${printN}$2 \033[0m" ;;
        # Magenta
        "magenta") echo -e "\033[35m${printN}$2 \033[0m" ;;
        # Yellow
        "yellow") echo -e "\033[33m${printN}$2 \033[0m" ;;
        # Purple
        "purple") echo -e "\033[1;35m${printN}$2 \033[0m" ;;
        # Yellow on Black
        "yellowBlack") echo -e "\033[1;33;40m${printN}$2 \033[0m" ;;
        # Green on White
        "greenWhite") echo -e "\033[42;37m${printN}$2 \033[0m" ;;
        # Blue
        "blue") echo -e "\033[34m${printN}$2 \033[0m" ;;
        # Cyan
        "cyan") echo -e "\033[36m${printN}$2 \033[0m" ;;
        # Black
        "black") echo -e "\033[30m${printN}$2 \033[0m" ;;
        # Gray
        "gray") echo -e "\033[90m${printN}$2 \033[0m" ;;
        # Light Red
        "lightRed") echo -e "\033[91m${printN}$2 \033[0m" ;;
        # Light Green
        "lightGreen") echo -e "\033[92m${printN}$2 \033[0m" ;;
        # Light Yellow
        "lightYellow") echo -e "\033[93m${printN}$2 \033[0m" ;;
        # Light Blue
        "lightBlue") echo -e "\033[94m${printN}$2 \033[0m" ;;
        # Light Magenta
        "lightMagenta") echo -e "\033[95m${printN}$2 \033[0m" ;;
        # Light Cyan
        "lightCyan") echo -e "\033[96m${printN}$2 \033[0m" ;;
        # Light White
        "lightWhite") echo -e "\033[97m${printN}$2 \033[0m" ;;
    esac
}

# Function to detect system architecture
getArchitecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "amd64"
            ;;
        i386|i686)
            echo "386"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7*)
            echo "arm"
            ;;
        s390x)
            echo "s390x"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
        loongarch64)
            echo "loong64"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

checkSystemForUpdate() {
    local release=""
    local installType=""
    local updateNeeded=false
    local packageManager=""
    local requiredPackages=("wget" "curl" "lsof" "bash" "iptables" "bc")

    # Detect package manager
    if command -v apt >/dev/null; then
        packageManager="apt"
        installType="apt -y -q install"
        upgrade="apt update"
    elif command -v yum >/dev/null; then
        packageManager="yum"
        installType="yum -y -q install"
        upgrade="yum update -y --skip-broken"
    elif command -v dnf >/dev/null; then
        packageManager="dnf"
        installType="dnf -y install"
        upgrade="dnf update -y"
    elif command -v pacman >/dev/null; then
        packageManager="pacman"
        installType="pacman -Sy --noconfirm"
        upgrade="pacman -Syy"
    elif command -v apk >/dev/null; then
        packageManager="apk"
        installType="apk add --no-cache"
        upgrade="apk update"
    else
        echoColor red "\nNo supported package manager detected, please report the following information to the developer:"
        echoColor yellow "$(cat /etc/issue 2>/dev/null)"
        echoColor yellow "$(cat /proc/version 2>/dev/null)"
        exit 1
    fi

    # Check for required packages
    for package in "${requiredPackages[@]}"; do
        if ! command -v "$package" >/dev/null; then
            echoColor green "*$package"
            updateNeeded=true
        fi
    done

    # Check for dig command
    if ! command -v dig >/dev/null; then
        echoColor green "*dnsutils"
        updateNeeded=true
    fi

    # Check for qrencode package
    if ! command -v qrencode >/dev/null; then
        echoColor green "*qrencode"
        updateNeeded=true
    fi

    # Check for crontab command
    if ! command -v crontab >/dev/null; then
        echoColor green "*crontab"
        updateNeeded=true
    fi

    # Check and install yq command
    if ! command -v yq >/dev/null; then
        arch=$(getArchitecture)
        echoColor purple "Downloading yq (${arch})..."
        wget "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${arch}" -O /usr/bin/yq
        if [ $? -ne 0 ]; then
            echoColor red "Failed to download yq"
            exit 1
        fi
        chmod +x /usr/bin/yq
    fi

    # Check for chrt command
    if ! command -v chrt >/dev/null; then
        echoColor green "*util-linux"
        updateNeeded=true
    fi

    # Update package sources only if needed
    if [ "$updateNeeded" = true ]; then
        echoColor purple "\nUpdating package sources..."
        ${upgrade}

        # Install required packages
        for package in "${requiredPackages[@]}"; do
            if ! command -v "$package" >/dev/null; then
                ${installType} "$package"
            fi
        done

        # Install dig
        if ! command -v dig >/dev/null; then
            case $packageManager in
                "apt") ${installType} "dnsutils" ;;
                "yum"|"dnf") ${installType} "bind-utils" ;;
                "pacman") ${installType} "bind-tools" ;;
                "apk") ${installType} "bind-tools" ;;
            esac
        fi

        # Install qrencode
        if ! command -v qrencode >/dev/null; then
            case $packageManager in
                "apt") ${installType} "qrencode" ;;
                "yum"|"dnf") ${installType} "qrencode" ;;
                "pacman") ${installType} "qrencode" ;;
                "apk") ${installType} "libqrencode-tools" ;;
            esac
        fi

        # Install util-linux
        if ! command -v chrt >/dev/null; then
            ${installType} "util-linux"
        fi

        # Ensure pkill command is available
        if ! command -v pkill >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "procps" ;;
                "yum"|"dnf") ${installType} "procps" ;;
                "pacman") ${installType} "procps" ;;
                "apk") ${installType} "procps" ;;
            esac
        fi

        # Ensure crontab command is available
        if ! command -v crontab >/dev/null 2>&1; then
            case $packageManager in
                "apt") ${installType} "cron" ;;
                "yum"|"dnf") ${installType} "cron" ;;
                "pacman") ${installType} "cronie" ;;
                "apk") ${installType} "cronie" ;;
            esac
        fi

        echoColor purple "\nPackage installation completed."
    fi
}

getPortBindMsg() {
    # $1 type UDP or TCP
    # $2 port
    local msg
    if [ "$1" == "UDP" ]; then
        msg=$(lsof -i "${1}:${2}")
    else
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    fi

    if [ -z "$msg" ]; then
        return
    fi

    local command pid name
    command=$(echo "$msg" | awk '{print $1}')
    pid=$(echo "$msg" | awk '{print $2}')
    name=$(echo "$msg" | awk '{print $9}')
    echoColor purple "Port: ${1}/${2} is already occupied by ${command}(${name}), process PID: ${pid}."
    echoColor green "Automatically close the port occupation? (y/N)"
    read -r bindP

    if [ -z "$bindP" ] || [[ ! "$bindP" =~ ^[yY]$ ]]; then
        echoColor red "Due to port occupation, exiting installation. Please manually close or change the port..."
        if [ "$1" == "TCP" ] && [ "$2" == "80" ]; then
            echoColor yellow "If you cannot close the ${1}/${2} port, please use another certificate acquisition method."
        fi
        exit
    fi

    pkill -f "/etc/hihy/bin/appS"
    echoColor purple "Unbinding port..."
    sleep 3

    if [ "$1" == "TCP" ]; then
        msg=$(lsof -i "${1}:${2}" | grep LISTEN)
    else
        msg=$(lsof -i "${1}:${2}")
    fi

    if [ -n "$msg" ]; then
        echoColor red "Failed to close port occupation; process restarted after being killed. Check for a daemon process..."
        exit
    else
        echoColor green "Port unbound successfully..."
    fi
}

generate_uuid() {
    if command -v uuidgen > /dev/null 2>&1; then
        uuid=$(uuidgen)
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    else
        uuid=$(cat /dev/urandom | tr -dc 'a-f0-9' | head -c 32 | sed 's/\(.\{8\}\)/\1-/g;s/-$//')
    fi
    echo "$uuid"
}

addOrUpdateYaml() {
    local file=$1
    local keyPath=$2
    local value=$3
    local valueType=${4:-"auto"} # auto, string, number, bool

    # Check if file exists, create an empty file if it doesn't
    if [[ ! -f "$file" ]]; then
        touch "$file"
    fi

    # Convert value to JSON format to avoid parsing errors
    local jsonValue
    if [[ $valueType == "auto" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    elif [[ $valueType == "string" ]]; then
        jsonValue=$(echo "\"$value\"" | yq eval -o=json)
    elif [[ $valueType == "number" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    elif [[ $valueType == "bool" ]]; then
        jsonValue=$(echo "$value" | yq eval -o=json)
    else
        echo "Unsupported value type: $valueType"
        return 1
    fi

    # Modify YAML file using yq
    yq eval ".${keyPath} = ${jsonValue}" -i "$file"
}

getYamlValue() {
    local file=$1    # YAML file path
    local keyPath=$2 # Key path, dot-separated

    # Check if file exists
if [[ ! -f "$file" ]]; then
    echo "File does not exist."
fi
    # Use yq to read the value from the YAML file
    value=$(yq eval ".${keyPath}" "$file")

    # Check if yq command executed successfully
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to read YAML file"
        return 1
    fi

    echo "$value"
}

countdown() {
    local seconds=$1
    echo -ne "\033[32m⏰ Countdown:\033[0m "
    
    while [ $seconds -gt 0 ]; do
        # Print current number
        echo -ne "\033[31m$seconds\033[0m"
        sleep 1
        
        # Calculate number of backspaces
        local digits=${#seconds}
        for ((i=0; i<digits; i++)); do
            echo -ne "\b \b"
        done
        
        ((seconds--))
    done
    
    # Clear the last number and show completion message
    echo -ne " "
    echo -e "\n\033[32m✨ Done!\033[0m"
}

setHysteriaConfig() {
    mkdir -p /etc/hihy/bin /etc/hihy/conf /etc/hihy/cert /etc/hihy/result /etc/hihy/acl/
    acl_file="/etc/hihy/acl/acl.txt"
    if [ -f "${acl_file}" ]; then
        rm -r ${acl_file}
    fi
    touch $acl_file
    echoColor yellowBlack "Starting configuration:"
    echo -e "\033[32m(1/11) Please select the certificate acquisition method:\n\n\033[0m\033[33m\033[01m1. Use ACME (recommended, requires TCP/80 port open)\n2. Use local certificate files\n3. Self-signed certificate\n4. DNS validation\033[0m\033[32m\n\nEnter the number:\033[0m"
    read certNum
    useAcme=false
    useLocalCert=false
    yaml_file="/etc/hihy/conf/config.yaml"
    if [ -f "${yaml_file}" ]; then
        rm -f ${yaml_file}
    fi
    touch $yaml_file

    if [ -z "${certNum}" ] || [ "${certNum}" == "3" ]; then
        echoColor green "Enter the domain for the self-signed certificate (default: helloworld.com):"
        read domain
        if [ -z "${domain}" ]; then
            domain="helloworld.com"
        fi
        echo -e "-> Self-signed certificate domain: " `echoColor red ${domain}` "\n"
        ip=`curl -4 -s -m 8 ip.sb`
        if [ -z "${ip}" ]; then
            ip=`curl -s -m 8 ip.sb`
        fi
        echoColor green "Is the address used for client connection correct? Public IP: " `echoColor red ${ip}` "\n"
        while true; do
            echo -e "\033[32mSelect:\n\n\033[0m\033[33m\033[01m1. Correct (default)\n2. Incorrect, enter IP manually\033[0m\033[32m\n\nEnter the number:\033[0m"
            read ipNum
            if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                break
            elif [ "${ipNum}" == "2" ]; then
                echoColor green "Enter the correct public IP (IPv6 addresses do not need []):"
                read ip
                if [ -z "${ip}" ]; then
                    echoColor red "Invalid input, please try again..."
                    continue
                fi
                break
            else
                echoColor red "\n-> Invalid input, please try again:"
            fi
        done
        cert="/etc/hihy/cert/${domain}.crt"
        key="/etc/hihy/cert/${domain}.key"
        useAcme=false
        echoColor purple "\n\n-> You have chosen self-signed ${domain} certificate encryption. Public IP: " `echoColor red ${ip}` "\n"
        echo -e "\n"

    elif [ "${certNum}" == "2" ]; then
        echoColor green "Enter the path to the certificate file (must be a fullchain cert with a complete certificate chain):"
        read local_cert
        while :; do
            if [ ! -f "${local_cert}" ]; then
                echoColor red "\n\n-> Path does not exist, please try again!"
                echoColor green "Enter the path to the certificate file:"
                read local_cert
            else
                break
            fi
        done
        echo -e "\n\n-> Certificate file path: " `echoColor red ${local_cert}` "\n"
        echoColor green "Enter the path to the certificate key file:"
        read local_key
        while :; do
            if [ ! -f "${local_key}" ]; then
                echoColor red "\n\n-> Path does not exist, please try again!"
                echoColor green "Enter the path to the certificate key file:"
                read local_key
            else
                break
            fi
        done
        echo -e "\n\n-> Key file path: " `echoColor red ${local_key}` "\n"
        echoColor green "Enter the domain for the selected certificate:"
        read domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n-> This option cannot be empty, please try again!"
                echoColor green "Enter the domain for the selected certificate:"
                read domain
            else
                break
            fi
        done
        useAcme=false
        useLocalCert=true
        echoColor purple "\n\n-> You have chosen local certificate encryption. Domain: " `echoColor red ${domain}` "\n"
    elif [ "${certNum}" == "4" ]; then
        echoColor green "Enter the domain:"
        read domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n-> This option cannot be empty, please try again!"
                echoColor green "Enter the domain (must be correctly resolved to this machine, disable CDN):"
                read domain
            else
                break
            fi
        done
        echo -e "\n\n-> Domain: " `echoColor red ${domain}` "\n"
        echo -e "\033[32mSelect DNS provider:\n\n\033[0m\033[33m\033[01m1. Cloudflare (default)\n2. Duck DNS\n3. Gandi.net\n4. Godaddy\n5. Name.com\n6. Vultr\033[0m\033[32m\n\nEnter the number:\033[0m"
        read dnsNum
        if [ -z "${dnsNum}" ] || [ "${dnsNum}" == "1" ]; then
            dns="cloudflare"
            echo -e "\n\n-> You have chosen Cloudflare DNS validation\n"
            echoColor green "Enter cloudflare_api_token:"
            
            while :; do
                read cloudflare_api_token
                if [ -z "${cloudflare_api_token}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter cloudflare_api_token:"
                else
                    break
                fi
            done
                    
        elif [ "${dnsNum}" == "2" ]; then
            dns="duckdns"
            echo -e "\n\n-> You have chosen Duck DNS validation\n"
            echoColor green "Enter Duck DNS duckdns_api_token:"
            while :; do
                read duckdns_api_token
                if [ -z "${duckdns_api_token}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Duck DNS duckdns_api_token:"
                else
                    break
                fi
            done
            echoColor green "Enter Duck DNS duckdns_override_domain:"
            while :; do
                read duckdns_override_domain
                if [ -z "${duckdns_override_domain}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Duck DNS duckdns_override_domain:"
                    break
                fi
            done

        elif [ "${dnsNum}" == "3" ]; then
            dns="gandi"
            echo -e "\n\n-> You have chosen Gandi.net DNS validation\n"
            echoColor green "Enter Gandi gandi_api_token:"
            while :; do
                read gandi_api_token
                if [ -z "${gandi_api_token}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Gandi gandi_api_token:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "4" ]; then
            dns="godaddy"
            echo -e "\n\n-> You have chosen Godaddy DNS validation\n"
            echoColor green "Enter Godaddy godaddy_api_token:"
            while :; do
                read godaddy_api_token
                if [ -z "${godaddy_api_token}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Godaddy godaddy_api_token:"
                else
                    break
                fi 
            done
        elif [ "${dnsNum}" == "5" ]; then
            dns="namedotcom"
            echo -e "\n\n-> You have chosen Name.com DNS validation\n"
            echoColor green "Enter Name.com namedotcom_api_token:"
            while :; do
                read namedotcom_api_token
                if [ -z "${namedotcom_api_token}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Name.com namedotcom_api_token:"
                else
                    break
                fi
            done
            echoColor green "Enter Name.com namedotcom_user:"
            
            while :; do
                read namedotcom_user
                if [ -z "${namedotcom_user}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Name.com namedotcom_user:"
                else
                    break
                fi
            done

            echoColor green "Enter Name.com namedotcom_server:"
            while :; do
                read namedotcom_server
                if [ -z "${namedotcom_server}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Name.com namedotcom_server:"
                else
                    break
                fi
            done
        elif [ "${dnsNum}" == "6" ]; then
            dns="vultr"
            echo -e "\n\n-> You have chosen Vultr DNS validation\n"
            echoColor green "Enter Vultr vultr_api_token:"
            while :; do
                read vultr_api_token
                if [ -z "${vultr_api_token}" ]; then
                    echoColor red "\n\n-> This option cannot be empty, please try again!"
                    echoColor green "Enter Vultr vultr_api_token:"
                else
                    break
                fi
            done
        else
            echoColor red "\n-> Invalid input, please try again:"
        fi
        ip=`curl -4 -s -m 8 ip.sb`
        if [ -z "${ip}" ]; then
            ip=`curl -s -m 8 ip.sb`
        fi
        echoColor green "Is the address used for client connection correct? Public IP: " `echoColor red ${ip}` "\n"
        while true; do
            echo -e "\033[32mSelect:\n\n\033[0m\033[33m\033[01m1. Correct (default)\n2. Incorrect, enter IP manually\033[0m\033[32m\n\nEnter the number:\033[0m"
            read ipNum
            if [ -z "${ipNum}" ] || [ "${ipNum}" == "1" ]; then
                break
            elif [ "${ipNum}" == "2" ]; then
                echoColor green "Enter the correct public IP (IPv6 addresses do not need []):"
                read ip
                if [ -z "${ip}" ]; then
                    echoColor red "Invalid input, please try again..."
                    continue
                fi
                break
            else
                echoColor red "\n-> Invalid input, please try again:"
            fi
        done
        echo -e "\n\n-> You have chosen ACME DNS validation for certificate: " `echoColor red ${domain}` "\n"
        echo -e "\n -> DNS validation method: " `echoColor red ${dns}` "\n"
        echo -e "\n -> Public IP: " `echoColor red ${ip}` "\n"
        useAcme=true
        useDns=true
    else
        echoColor green "Enter the domain (must be correctly resolved to this machine, disable CDN):"
        read domain
        while :; do
            if [ -z "${domain}" ]; then
                echoColor red "\n\n-> This option cannot be empty, please try again!"
                echoColor green "Enter the domain (must be correctly resolved to this machine, disable CDN):"
                read domain
            else
                break
            fi
        done
        while :; do
            echoColor purple "\n-> Checking ${domain}, DNS resolution..."
            ip_resolv=`dig +short ${domain} A`
            if [ -z "${ip_resolv}" ]; then
                ip_resolv=`dig +short ${domain} AAAA`
            fi
            if [ -z "${ip_resolv}" ]; then
                echoColor red "\n\n-> Domain resolution failed, no DNS records (A/AAAA) found. Please check if the domain is correctly resolved to this machine!"
                echoColor green "Enter the domain (must be correctly resolved to this machine, disable CDN):"
                read domain
                continue
            fi
            remoteip=`echo ${ip_resolv} | awk -F " " '{print $1}'`
            v6str=":" # Is IPv6?
            result=$(echo ${remoteip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                localip=`curl -6 -s -m 8 ip.sb`
            else
                localip=`curl -4 -s -m 8 ip.sb`
            fi
            if [ -z "${localip}" ]; then
                localip=`curl -s -m 8 ip.sb`
                if [ -z "${localip}" ]; then
                    echoColor red "\n\n-> Failed to retrieve local IP. Please check network connection! curl -s -m 8 ip.sb"
                    exit 1
                fi
            fi
            if [ "${localip}" != "${remoteip}" ]; then
                echo -e " \n\n-> Local IP: " `echoColor red ${localip}` " \n\n-> Domain IP: " `echoColor red ${remoteip}` "\n"
                echoColor green "Multiple IPs or DNS not effective may cause detection failure. If you are sure it resolves correctly, do you want to specify the local IP? [y/N]:"
                read isLocalip
                if [ "${isLocalip}" == "y" ]; then
                    echoColor green "Enter the local IP:"
                    read localip
                    while :; do
                        if [ -z "${localip}" ]; then
                            echoColor red "\n\n-> This option cannot be empty, please try again!"
                            echoColor green "Enter the local IP:"
                            read localip
                        else
                            break
                        fi
                    done
                fi
                if [ "${localip}" != "${remoteip}" ]; then
                    echoColor red "\n\n-> The IP resolved by the domain does not match the local IP, please try again!"
                    echoColor green "Enter the domain (must be correctly resolved to this machine, disable CDN):"
                    read domain
                    continue
                else
                    break
                fi
            else
                break
            fi
        done
        useAcme=true
        useDns=false
        echoColor purple "\n\n-> Resolution correct, using Hysteria's built-in ACME to request certificate. Domain: " `echoColor red ${domain}` "\n"
    fi

    while :; do
        echoColor green "\n(2/11) Enter the port you want to open, this is the server port, recommended 443. (default random 10000-65535)"
        echo "There is no evidence that non-UDP/443 ports are blocked; it is merely a measure for better masquerading, " `echoColor red "if using port hopping, it is recommended to use a random port"` ""
        read port
        if [ -z "${port}" ]; then
            port=$(($(od -An -N2 -i /dev/random) % (65534 - 10001) + 10001))
            echo -e "\n-> Using random port: " `echoColor red udp/${port}` "\n"
        else
            echo -e "\n-> Entered port: " `echoColor red udp/${port}` "\n"
        fi
        if [ "${port}" -gt 65535 ]; then
            echoColor red "Port range error, please try again!"
            continue
        fi
        if [ "${ut}" != "udp" ]; then
            pIDa=`lsof -i ${ut}:${port} | grep "LISTEN" | grep -v "PID" | awk '{print $2}'`
        else
            pIDa=`lsof -i ${ut}:${port} | grep -v "PID" | awk '{print $2}'`
        fi
        if [ "$pIDa" != "" ]; then
            echoColor red "\n-> Port ${port} is occupied, PID: ${pIDa}! Please try again or run kill -9 ${pIDa} and reinstall!"
        else
            break
        fi
    done

    echoColor green "\n->(3/11) Use Port Hopping? Recommended."
    echo -e "Tip: Long-term single-port UDP connections may be blocked/QoS/disconnected by ISPs. Enabling this feature can effectively avoid this issue."
    echo -e "For more details, refer to: https://v2.hysteria.network/en/docs/advanced/Port-Hopping/\n"
    echo -e "\033[32mSelect whether to enable:\n\n\033[0m\033[33m\033[01m1. Enable (default)\n2. Skip\033[0m\033[32m\n\nEnter the number:\033[0m"
    read portHoppingStatus
    if [ -z "${portHoppingStatus}" ] || [ $portHoppingStatus == "1" ]; then
        portHoppingStatus="true"
        echoColor purple "\n-> You have chosen to enable Port Hopping/Multi-port functionality"
        echo -e "Port Hopping/Multi-port functionality requires multiple ports. Ensure these ports are not used by other services.\nTip: Do not select too many ports; around 1000 is recommended, within the range 1-65535, preferably consecutive ports.\n"
        while :; do
            echoColor green "Enter the start port (default: 47000):"
            read portHoppingStart
            if [ -z "${portHoppingStart}" ]; then
                portHoppingStart=47000
            fi
            if [ $portHoppingStart -gt 65535 ]; then
                echoColor red "\n-> Port range error, please try again!"
                continue
            fi
            echo -e "\n-> Start port: " `echoColor red ${portHoppingStart}` "\n"
            echoColor green "Enter the end port (default: 48000):"
            read portHoppingEnd
            if [ -z "${portHoppingEnd}" ]; then
                portHoppingEnd=48000
            fi
            if [ $portHoppingEnd -gt 65535 ]; then
                echoColor red "\n-> Port range error, please try again!"
                continue
            fi
            echo -e "\n-> End port: " `echoColor red ${portHoppingEnd}` "\n"
            if [ $portHoppingStart -ge $portHoppingEnd ]; then
                echoColor red "\n-> Start port must be less than end port, please try again!"
            else
                break
            fi
        done
        clientPort="${port},${portHoppingStart}-${portHoppingEnd}"
        echo -e "\n-> Your selected Port Hopping/Multi-port parameters: " `echoColor red ${portHoppingStart}:${portHoppingEnd}` "\n"
    else
        portHoppingStatus="false"
        echoColor red "\n-> You have chosen not to use Port Hopping"
    fi

    echoColor green "(4/11) Enter the average latency to this server, affects forwarding speed (default: 200, unit: ms):"
    read delay
    if [ -z "${delay}" ]; then
        delay=200
    fi
    echo -e "\n-> Latency: " `echoColor red ${delay}` "ms\n"
    echo -e "\nExpected speed, this is the client's peak speed, server is unlimited by default." `echoColor red Tips: The script will automatically add 10% redundancy. Setting too low or too high affects speed, please enter realistically!`
    echoColor green "(5/11) Enter the client's expected download speed (default: 50, unit: mbps):"
    read download
    if [ -z "${download}" ]; then
        download=50
    fi
    echo -e "\n-> Client download speed: " `echoColor red ${download}` "mbps\n"
    echo -e "\033[32m(6/11) Enter the client's expected upload speed (default: 10, unit: mbps):\033[0m" 
    read upload
    if [ -z "${upload}" ]; then
        upload=10
    fi
    echo -e "\n-> Client upload speed: " `echoColor red ${upload}` "mbps\n"
    echoColor green "(7/11) Enter the authentication password (default: randomly generated UUID, strong password recommended):"
    read auth_secret
    if [ -z "${auth_secret}" ]; then
        auth_secret=$(generate_uuid)
    fi
    echo -e "\n-> Authentication password: " `echoColor red ${auth_secret}` "\n"
    echo -e "Tips: Using obfuscation enhances blocking resistance, making traffic appear as unknown UDP traffic.\nHowever, it increases CPU load, reducing peak speed. If performance is a priority and not targeted for blocking, avoid using it."
    echo -e "\033[32m(8/11) Use Salamander for traffic obfuscation:\n\n\033[0m\033[33m\033[01m1. Do not use (recommended)\n2. Use\033[0m\033[32m\n\nEnter the number:\033[0m"
    read obfs_num
    if [ -z "${obfs_num}" ] || [ ${obfs_num} == "1" ]; then
        obfs_status="false"
    else
        obfs_status="true"
        obfs_pass=${auth_secret}
    fi

    if [ "${obfs_status}" == "true" ]; then
        echo -e "\n-> You will use Salamander to obfuscate traffic\n"
    else
        echo -e "\n-> You will not use obfuscation\n"
    fi

    echo -e "\033[32m(9/11) Select masquerade type:\n\n\033[0m\033[33m\033[01m1. String (default, returns a fixed string)\n2. Proxy (acts as a reverse proxy, serving content from another site)\n3. File (acts as a static file server, serving content from a directory. Must contain index.html)\033[0m\033[32m\n\nEnter the number:\033[0m"
    read masquerade_type
    if [ -z "${masquerade_type}" ] || [ ${masquerade_type} == "1" ]; then
        masquerade_type="string"
        echo -e "Enter the masquerade string (default: HelloWorld):"
        read masquerade_string
        if [ -z "${masquerade_string}" ]; then
            masquerade_string="HelloWorld"
        fi
        echo -e "\n-> Masquerade string: " `echoColor red ${masquerade_string}` "\n"
        echo -e "Enter the HTTP masquerade header content-stuff (default: HelloWorld):"
        read masquerade_stuff
        if [ -z "${masquerade_stuff}" ]; then
            masquerade_stuff="HelloWorld"
        fi
        echo -e "\n-> HTTP masquerade header content-stuff: " `echoColor red ${masquerade_stuff}` "\n"
    elif [ ${masquerade_type} == "2" ]; then
        masquerade_type="proxy"
        echoColor green "Enter the masquerade proxy address (default: https://www.helloworld.org):"
        echo -e "Reverse proxy this URL but will not replace domains in the content"
        read masquerade_proxy
        if [ -z "${masquerade_proxy}" ]; then
            masquerade_proxy="https://www.helloworld.org"
        fi
        echo -e "\n-> Masquerade proxy address: " `echoColor red ${masquerade_proxy}` "\n"
    else
        masquerade_type="file"
        echoColor green "Enter the masquerade website file directory (default: /etc/hihy/file, will automatically download mikutap):"
        echo -e "Default preview: https://hfiprogramming.github.io/mikutap/"
        read masquerade_file
        if [ -z "${masquerade_file}" ]; then
            masquerade_file="/etc/hihy/file"
        fi
        echo -e "\n-> Masquerade website file directory: " `echoColor red ${masquerade_file}` "\n"
    fi

    echoColor green "(10/11) Listen on tcp/${port} port to enhance masquerading (complete the act):"
    echoColor lightYellow "Typically, websites support HTTP/3 only as an upgrade option."
    echo -e "Listening on a TCP port to provide masqueraded content makes it more natural. If not enabled, browsers cannot access masqueraded content without H3."
    echo -e "\033[32mSelect:\n\n\033[0m\033[33m\033[01m1. Enable (default)\n2. Skip\033[0m\033[32m\n\nEnter the number:\033[0m"
    read masquerade_tcp
    if [ -z "${masquerade_tcp}" ] || [ ${masquerade_tcp} == "1" ]; then
        masquerade_tcp="true"
        echo -e "\n-> You have chosen to listen on " `echoColor red tcp/${port}` " port\n"
    else
        masquerade_tcp="false"
        echo -e "\n-> You have chosen not to listen on tcp/${port} port\n"
    fi

    echoColor green "\n(11/11) Block HTTP/3 traffic on the server (Hysteria's congestion control has no enhancement for UDP traffic, leading to poor performance for sites like YouTube using QUIC):"
    echoColor lightYellow "If enabled, Hysteria2 will not proxy UDP/443, disabling QUIC connections to websites. You must disable QUIC in the client configuration, or connections will fail.\n"
    echo -e "You can also block QUIC/HTTP3/UDP 443 only on the client, achieving the same effect.\n"
    echo -e "\033[32mSelect:\n\n\033[0m\033[33m\033[01m1. Enable (recommended)\n2. Skip (default)\033[0m\033[32m\n\nEnter the number:\033[0m"
    read block_http3
    if [ -z "${block_http3}" ] || [ ${block_http3} == "2" ]; then
        block_http3="false"
        echo -e "\n-> You have chosen not to block HTTP/3 traffic, which may result in no Hysteria2 enhancement for QUIC websites\n"
        echoColor lightYellow "Tip: It is recommended to block QUIC/HTTP3/UDP 443 on the client for a better experience.\n"
    else
        block_http3="true"
        echoColor red "\n-> You have chosen to block HTTP/3 traffic. Ensure QUIC/HTTP3 is disabled in your client, or connections to QUIC websites will fail.\n"
    fi

    echoColor green "Enter the client name remark (default: uses domain or IP, e.g., entering test results in Hy2-test):"
    read remarks
    echoColor green "\nConfiguration completed!\n"
    echoColor yellowBlack "Executing configuration..."
    download=$(($download + $download / 10))
    upload=$(($upload + $upload / 10))
    CRW=$(($delay * $download * 1000000 / 1000 * 2))
    SRW=$(($CRW / 5 * 2))
    max_CRW=$(($CRW * 3 / 2))
    max_SRW=$(($SRW * 3 / 2))

    server_upload=${download}
    server_download=${upload}
    
    addOrUpdateYaml "$yaml_file" "listen" ":${port}"
    addOrUpdateYaml "$yaml_file" "auth.type" "password"
    addOrUpdateYaml "$yaml_file" "auth.password" "${auth_secret}"
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "obfs.type" "salamander"
        addOrUpdateYaml "$yaml_file" "obfs.salamander.password" "${obfs_pass}"
    fi
    addOrUpdateYaml "$yaml_file" "quic.initStreamReceiveWindow" "${SRW}"
    addOrUpdateYaml "$yaml_file" "quic.maxStreamReceiveWindow" "${max_SRW}"
    addOrUpdateYaml "$yaml_file" "quic.initConnReceiveWindow" "${CRW}"
    addOrUpdateYaml "$yaml_file" "quic.maxConnReceiveWindow" "${max_CRW}"
    addOrUpdateYaml "$yaml_file" "quic.maxIdleTimeout" "30s"
    addOrUpdateYaml "$yaml_file" "quic.maxIncomingStreams" "1024"
    addOrUpdateYaml "$yaml_file" "quic.disablePathMTUDiscovery" "false"
    addOrUpdateYaml "$yaml_file" "bandwidth.up" "${server_upload}mbps"
    addOrUpdateYaml "$yaml_file" "bandwidth.down" "${server_download}mbps"
    addOrUpdateYaml "$yaml_file" "acl.file" "${acl_file}"
    case ${masquerade_type} in 
        "string")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "string"
            addOrUpdateYaml "$yaml_file" "masquerade.string.content" "${masquerade_string}"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.content-type" "text/plain"
            addOrUpdateYaml "$yaml_file" "masquerade.string.headers.custom-stuff" "${masquerade_stuff}"
            addOrUpdateYaml "$yaml_file" "masquerade.string.statusCode" "200"
        ;;
        "proxy")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "proxy"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.url" "${masquerade_proxy}"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.rewriteHost" "true"
            addOrUpdateYaml "$yaml_file" "masquerade.proxy.insecure" "true"
        ;;
        "file")
            addOrUpdateYaml "$yaml_file" "masquerade.type" "file"
            addOrUpdateYaml "$yaml_file" "masquerade.file.dir" "${masquerade_file}"
            if [ ! -d "${masquerade_file}" ]; then
                mkdir -p ${masquerade_file}
                wget -q -O ./mikutap.tar.gz https://github.com/HFIProgramming/mikutap/archive/refs/tags/2.0.0.tar.gz
                tar -xzf ./mikutap.tar.gz -C ${masquerade_file} --strip-components=1
                rm -r ./mikutap.tar.gz
            fi
        ;;
    esac

    if [ "${masquerade_tcp}" == "true" ]; then
        addOrUpdateYaml "$yaml_file" "masquerade.listenHTTPS" ":${port}"
    fi
    addOrUpdateYaml "$yaml_file" "speedTest" "true"
    if echo "${useAcme}" | grep -q "false"; then
        if echo "${useLocalCert}" | grep -q "false"; then
            v6str=":" # Is IPv6?
            result=$(echo ${ip} | grep ${v6str})
            if [ "${result}" != "" ]; then
                ip="[${ip}]" 
            fi
            u_host=${ip}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${ip}"
            fi
            insecure="1"
            days=3650
            mail="no-reply@qq.com"

            # Start generating certificate
            echoColor purple "Generating self-signed certificate...\n"

            # Generate CA private key
            echoColor green "Generating CA private key..."
            openssl genrsa -out /etc/hihy/cert/${domain}.ca.key 2048

            # Generate CA certificate
            echoColor green "Generating CA certificate..."
            openssl req -new -x509 -days ${days} -key /etc/hihy/cert/${domain}.ca.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=Tencent Root CA" -out /etc/hihy/cert/${domain}.ca.crt

            # Generate server private key and CSR
            echoColor green "Generating server private key and CSR..."
            openssl req -newkey rsa:2048 -nodes -keyout /etc/hihy/cert/${domain}.key -subj "/C=CN/ST=GuangDong/L=ShenZhen/O=PonyMa/OU=Tecent/emailAddress=${mail}/CN=${domain}" -out /etc/hihy/cert/${domain}.csr

            # Sign server certificate with CA
            echoColor green "Signing server certificate with CA..."
            openssl x509 -req -extfile <(printf "subjectAltName=DNS:${domain},DNS:${domain}") -days ${days} -in /etc/hihy/cert/${domain}.csr -CA /etc/hihy/cert/${domain}.ca.crt -CAkey /etc/hihy/cert/${domain}.ca.key -CAcreateserial -out /etc/hihy/cert/${domain}.crt

            # Clean up temporary files
            echoColor green "Cleaning up temporary files..."
            rm /etc/hihy/cert/${domain}.ca.key /etc/hihy/cert/${domain}.ca.srl /etc/hihy/cert/${domain}.csr

            # Move CA certificate to result directory
            echoColor green "Moving CA certificate to result directory..."
            mv /etc/hihy/cert/${domain}.ca.crt /etc/hihy/result

            # Completion
            echoColor purple "Certificate generated successfully!\n"
            addOrUpdateYaml "$yaml_file" "tls.cert" "/etc/hihy/cert/${domain}.crt"
            addOrUpdateYaml "$yaml_file" "tls.key" "/etc/hihy/cert/${domain}.key"
            addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
        else
            u_host=${domain}
            u_domain=${domain}
            if [ -z "${remarks}" ]; then
                remarks="${domain}"
            fi
            insecure="0"
            addOrUpdateYaml "$yaml_file" "tls.cert" "${local_cert}"
            addOrUpdateYaml "$yaml_file" "tls.key" "${local_key}"
            addOrUpdateYaml "$yaml_file" "tls.sniGuard" "strict"
        fi
    else
        u_host=${domain}
        u_domain=${domain}
        insecure="0"
        if [ -z "${remarks}" ]; then
            remarks="${domain}"
        fi
        addOrUpdateYaml "$yaml_file" "acme.domains" "${domain}"
        addOrUpdateYaml "$yaml_file" "acme.email" "pekora@${domain}"
        addOrUpdateYaml "$yaml_file" "acme.ca" "letsencrypt"
        addOrUpdateYaml "$yaml_file" "acme.dir" "/etc/hihy/cert"
        if [ "${useDns}" == "true" ]; then
            u_host=${ip}
            addOrUpdateYaml "$yaml_file" "acme.type" "dns"
            case ${dns} in 
                "cloudflare")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "cloudflare"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.cloudflare_api_token" "${cloudflare_api_token}"
                ;;
                "duckdns")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "duckdns"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_api_token" "${duckdns_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.duckdns_override_domain" "${duckdns_override_domain}"
                ;;
                "gandi")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "gandi"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.gandi_api_token" "${gandi_api_token}"
                ;;
                "godaddy")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "godaddy"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.godaddy_api_token" "${godaddy_api_token}"
                ;;
                "namedotcom")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "namedotcom"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_api_token" "${namedotcom_api_token}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_user" "${namedotcom_user}"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.namedotcom_server" "${namedotcom_server}"
                ;;
                "vultr")
                    addOrUpdateYaml "$yaml_file" "acme.dns.name" "vultr"
                    addOrUpdateYaml "$yaml_file" "acme.dns.config.vultr_api_token" "${vultr_api_token}"
                ;;
            esac
        else
            getPortBindMsg TCP 80
            allowPort tcp 80
            addOrUpdateYaml "$yaml_file" "acme.type" "http"
            addOrUpdateYaml "$yaml_file" "acme.listenHost" "0.0.0.0"
        fi
    fi
    addOrUpdateYaml "$yaml_file" "sniff.enabled" "true"
    addOrUpdateYaml "$yaml_file" "sniff.timeout" "2s"
    addOrUpdateYaml "$yaml_file" "sniff.rewriteDomain" "false"
    addOrUpdateYaml "$yaml_file" "sniff.tcpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "sniff.udpPorts" "80,443"
    addOrUpdateYaml "$yaml_file" "outbounds[0].name" "hihy" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.mode" "auto" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[0].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[1].name" "v4_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.mode" "4" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[1].direct.fastOpen" "false" "bool"
    addOrUpdateYaml "$yaml_file" "outbounds[2].name" "v6_only" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].type" "direct" "string"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.mode" "6" "number"
    addOrUpdateYaml "$yaml_file" "outbounds[2].direct.fastOpen" "false" "bool"
    trafficPort=$(($(od -An -N2 -i /dev/random) % (65534 - 10001) + 10001))
    if [ "$trafficPort" == "${port}" ]; then
        trafficPort=$(${port} + 1)
    fi
    addOrUpdateYaml "$yaml_file" "trafficStats.listen" "127.0.0.1:${trafficPort}"
    addOrUpdateYaml "$yaml_file" "trafficStats.secret" "${auth_secret}"

    if [ $block_http3 == "true" ]; then
        echo -e "reject(all, udp/443)" > ${acl_file}
    fi
    
    sysctl -w net.core.rmem_max=${max_CRW}
    sysctl -w net.core.wmem_max=${max_CRW}
    if echo "${portHoppingStatus}" | grep -q "true"; then
        sysctl -w net.ipv4.ip_forward=1
        sysctl -w net.ipv6.conf.all.forwarding=1
    fi
    if [ ! -f "/etc/sysctl.conf" ]; then
        touch /etc/sysctl.conf
    fi
    sysctl -p
    echo -e "\033[1;35m\nTesting configuration...\n\033[0m"
    /etc/hihy/bin/appS -c ${yaml_file} server > ./hihy_debug.info 2>&1 &

    if [ "${useAcme}" == "true" ]; then
        countdown 20
    else
        countdown 5
    fi
    
    msg=`cat ./hihy_debug.info`
    case ${msg} in 
        *"failed to get a certificate with ACME"*)
            echoColor red "Domain: ${u_host} certificate acquisition failed..."
            exit 1
        ;;
    esac
}

delPortHoppingNat() {
    # Remove OpenRC service (if exists)
    if [ -f "/etc/alpine-release" ] && [ -f "/etc/init.d/port-hopping" ]; then
        rc-service port-hopping stop
        rc-update del port-hopping default
        rm -f /etc/init.d/port-hopping
    fi

    # Remove port-hopping rules
    if [ -f "/etc/rc.d/port-hopping" ]; then
        rm -f /etc/rc.d/port-hopping
    fi

    # Remove port-hopping rules from rc.local (if exists)
    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/port-hopping/d' /etc/rc.local
    fi

    # Remove all hihysteria-related NAT rules
    local nat_rules_v4=$(iptables-save | grep -E "PortHopping-hihysteria|hihysteria")
    local nat_rules_v6=$(ip6tables-save | grep -E "PortHopping-hihysteria|hihysteria")

    if [ -n "$nat_rules_v4" ]; then
        while IFS= read -r rule; do
            local clean_rule=$(echo "$rule" | sed 's/-A/-D/')
            if eval "iptables $clean_rule 2>/dev/null" || ! iptables -t nat -C $(echo "$clean_rule" | cut -d' ' -f2-) 2>/dev/null; then
                continue
            fi
        done <<< "$nat_rules_v4"
    fi

    if [ -n "$nat_rules_v6" ]; then
        while IFS= read -r rule; do
            local clean_rule=$(echo "$rule" | sed 's/-A/-D/')
            if eval "ip6tables $clean_rule 2>/dev/null" || ! ip6tables -t nat -C $(echo "$clean_rule" | cut -d' ' -f2-) 2>/dev/null; then
                continue
            fi
        done <<< "$nat_rules_v6"
    fi
    # Save iptables rules
    if [ -d "/etc/iptables" ]; then
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    fi

    echoColor purple "Port Hopping NAT rules cleaned up."
}

checkRoot() {
    if [ "$(id -u)" -ne 0 ]; then
        echoColor red "Please run this script with root privileges!"
        exit 1
    fi
}

uninstall() {
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ ! -f "/etc/hihy/bin/appS" ]; then
        echoColor red "Hysteria not installed!"
        exit 1
    fi

    # Stop service
    if [ -f "/etc/alpine-release" ]; then
        if [ -f "/etc/init.d/hihy" ]; then
            rc-service hihy stop
            rc-update del hihy default
            rm -f /etc/init.d/hihy
        fi
    else
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop
            rm -f /etc/rc.d/hihy
        fi
    fi

    # Remove iptables rules
    iptables-save | grep -v "hihysteria" | iptables-restore
    ip6tables-save | grep -v "hihysteria" | ip6tables-restore

    # Save iptables rules
    if [ -d "/etc/iptables" ]; then
        iptables-save > /etc/iptables/rules.v4
        ip6tables-save > /etc/iptables/rules.v6
    fi

    # Remove cron tasks
    crontab -l 2>/dev/null | grep -v "hihy cronTask" | crontab -

    delHihyFirewallPort udp
    delHihyFirewallPort tcp
    if echo ${portHoppingStatus} | grep -q "true"; then
        delPortHoppingNat
    fi

    # Remove directories and files
    rm -rf /etc/hihy
    rm -f /var/run/hihy.pid

    if [ -f "/etc/rc.local" ]; then
        sed -i '/\/etc\/rc.d\/hihy start/d' /etc/rc.local
        if grep -q "/etc/rc.d/allow-port" /etc/rc.local; then
            sed -i '/\/etc\/rc.d\/allow-port start/d' /etc/rc.local
        fi
    fi

    if [ -f "/usr/bin/hihy" ]; then
        rm /usr/bin/hihy
    fi

    # Remove Arch Linux rc.local systemd service
    uninstall_rc_local_for_arch
    # Check if fully removed
    if [ ! -d "/etc/hihy" ]; then
        echoColor green "Hysteria fully uninstalled!"
    else
        echoColor red "An error occurred during uninstallation. Check for residual files or processes."
        exit 1
    fi
}

generate_qr() {
    local url=$1
    
    # Use smallest valid size
    local qr_size=1
    local margin=1
    local level="L"  # Use lowest error correction level
    # Generate and display QR code
    qrencode -t ANSIUTF8 -o - -l "$level" -m "$margin" -s 1 "${url}"
    
    if [ $? -eq 0 ]; then
        echoColor green "\nQR code generated successfully."
    else
        echoColor red "\nFailed to generate QR code."
        return 1
    fi
}

generate_client_config() {
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "hysteria2 not installed!"
        exit 1
    fi
    remarks=$(getYamlValue "/etc/hihy/conf/backup.yaml" "remarks")
    serverAddress=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverAddress")
    port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen" | awk '{gsub(/^:/, ""); print}')
    auth_secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
    tls_sni=$(getYamlValue "/etc/hihy/conf/backup.yaml" "domain")
    insecure=$(getYamlValue "/etc/hihy/conf/backup.yaml" "insecure")
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
    obfs_pass=$(getYamlValue "/etc/hihy/conf/config.yaml" "obfs.salamander.password")
    if [ "${obfs_pass}" == "" ]; then
        obfs_status="true"
    fi
    SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initStreamReceiveWindow")
    CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxStreamReceiveWindow")
    download=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.up")
    upload=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.down")
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ]; then
        portHoppingStart=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStart")
        portHoppingEnd=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingEnd")
    fi
    client_configfile="./Hy2-${remarks}-v2rayN.yaml"
    if [ -f "${client_configfile}" ]; then
        rm -r ${client_configfile}
    fi
    touch ${client_configfile}
    if [ "${portHoppingStatus}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "server" "hysteria2://${auth_secret}@${serverAddress}:${port},${portHoppingStart}-${portHoppingEnd}/"
    fi
    
    addOrUpdateYaml "$client_configfile" "tls.sni" "${tls_sni}"
    if [ "${insecure}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "tls.insecure" "true"
    elif [ "${insecure}" == "false" ]; then
        addOrUpdateYaml "$client_configfile" "tls.insecure" "false"
    fi
    addOrUpdateYaml "$client_configfile" "transport.type" "udp"
    addOrUpdateYaml "$client_configfile" "transport.udp.hopInterval" "120s"
    if [ "${obfs_status}" == "true" ]; then
        addOrUpdateYaml "$client_configfile" "obfs.type" "salamander"
        addOrUpdateYaml "$client_configfile" "obfs.salamander.password" "${obfs_pass}"
    fi
    addOrUpdateYaml "$client_configfile" "quic.initStreamReceiveWindow" "${SRW}"
    addOrUpdateYaml "$client_configfile" "quic.initConnReceiveWindow" "${CRW}"
    addOrUpdateYaml "$client_configfile" "quic.maxConnReceiveWindow" "${max_CRW}"
    addOrUpdateYaml "$client_configfile" "quic.maxStreamReceiveWindow" "${max_SRW}"
    addOrUpdateYaml "$client_configfile" "quic.keepAlivePeriod" "60s"
    addOrUpdateYaml "$client_configfile" "bandwidth.down" "${download}"
    addOrUpdateYaml "$client_configfile" "bandwidth.up" "${upload}"
    addOrUpdateYaml "$client_configfile" "fastOpen" "true"
    addOrUpdateYaml "$client_configfile" "lazy" "true"
    addOrUpdateYaml "$client_configfile" "socks5.listen" "127.0.0.1:20808"
    url_base="hy2://${auth_secret}@${serverAddress}"
    
    if [ "${portHoppingStatus}" == "true" ]; then
        url_base="${url_base}:${port}/?mport=${portHoppingStart}-${portHoppingEnd}&"
    else
        url_base="${url_base}:${port}/?"
    fi
    
    if [ "${insecure}" == "true" ]; then
        url_base="${url_base}insecure=1"
    else
        url_base="${url_base}insecure=0"
    fi
    
    if [ "${obfs_status}" == "true" ]; then
        url_base="${url_base}&obfs=salamander&obfs-password=${obfs_pass}"
    fi
    url="${url_base}&sni=${tls_sni}#Hy2-${remarks}"
    echo -e "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "📝 Generating client configuration file..."
    
    echo -e "\n✨ Configuration details:"
    local localV=$(echo app/$(/etc/hihy/bin/appS version | grep Version: | awk '{print $2}' | head -n 1))
    echo -e "\n📌 Current Hysteria2 server version: " `echoColor red ${localV}` ""
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    if [ "${portHoppingStatus}" == "false" ]; then
        echo -e "⚠️ Note: Masquerading does not listen on TCP port"
        echo -e "💡 You may need to " `echoColor red "manually enable H3 in the browser"` " to access"
    fi
    
    if [ "${insecure}" == "true" ]; then
        echo -e "\n⚠️ Security note:"
        echo -e "🔒 You are using a self-signed certificate. To verify the masquerade website:"
        echo -e "   1. Modify browser trusted certificates"
        echo -e "   2. Set hosts to map the IP to the domain"
    fi
    echoColor purple "\n🌐 1. Masquerade address: " `echoColor red https://${tls_sni}:${port}` ""

    echoColor purple "\n🔗 2. [v2rayN-Windows/v2rayN-Android/nekobox/passwall/Shadowrocket] Share link:\n"
    echoColor green "${url}"
    echo -e "\n"
    generate_qr "${url}"

    echoColor purple "\n📄 3. [Recommended] [Nekoray/V2rayN/NekoBoxforAndroid] Native configuration file, fastest updates, most complete parameters, best results. File location: " `echoColor green ${client_configfile}` ""
    echoColor green "↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓COPY↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓"
    cat ${client_configfile}
    echoColor green "↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑COPY↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑"
    generateMetaYaml
    
    echo -e "\n✅ Configuration generation completed!"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

generateMetaYaml() {
    remarks=$(getYamlValue "/etc/hihy/conf/backup.yaml" "remarks")
    local metaFile="./Hy2-${remarks}-ClashMeta.yaml"
    if [ -f "${metaFile}" ]; then
        rm -f ${metaFile}
    fi
    touch ${metaFile}

    cat <<EOF > ${metaFile}
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: true
dns:
  enable: true
  listen: 0.0.0.0:53
  ipv6: true
  default-nameserver:
    - 114.114.114.114
    - 223.5.5.5
  enhanced-mode: redir-host
  nameserver:
    - https://dns.alidns.com/dns-query
    - https://223.5.5.5/dns-query
  fallback:
    - 114.114.114.114
    - 223.5.5.5
rule-providers:
  reject:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./ruleset/reject.yaml
    interval: 86400

  icloud:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/icloud.txt"
    path: ./ruleset/icloud.yaml
    interval: 86400

  apple:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/apple.txt"
    path: ./ruleset/apple.yaml
    interval: 86400

  google:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/google.txt"
    path: ./ruleset/google.yaml
    interval: 86400

  proxy:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/proxy.txt"
    path: ./ruleset/proxy.yaml
    interval: 86400

  direct:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/direct.txt"
    path: ./ruleset/direct.yaml
    interval: 86400

  private:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/private.txt"
    path: ./ruleset/private.yaml
    interval: 86400

  gfw:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/gfw.txt"
    path: ./ruleset/gfw.yaml
    interval: 86400

  greatfire:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/greatfire.txt"
    path: ./ruleset/greatfire.yaml
    interval: 86400

tld-not-cn:
    type: http
    behavior: domain
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/tld-not-cn.txt"
    path: ./ruleset/tld-not-cn.yaml
    interval: 86400

telegramcidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/telegramcidr.txt"
    path: ./ruleset/telegramcidr.yaml
    interval: 86400

cncidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/cncidr.txt"
    path: ./ruleset/cncidr.yaml
    interval: 86400

lancidr:
    type: http
    behavior: ipcidr
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/lancidr.txt"
    path: ./ruleset/lancidr.yaml
    interval: 86400

applications:
    type: http
    behavior: classical
    url: "https://ghgo.xyz/https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/applications.txt"
    path: ./ruleset/applications.yaml
    interval: 86400

rules:
  - RULE-SET,applications,DIRECT
  - DOMAIN,clash.razord.top,DIRECT
  - DOMAIN,yacd.haishan.me,DIRECT
  - DOMAIN,services.googleapis.cn,PROXY
  - RULE-SET,private,DIRECT
  - RULE-SET,reject,REJECT
  - RULE-SET,icloud,DIRECT
  - RULE-SET,apple,DIRECT
  - RULE-SET,google,DIRECT
  - RULE-SET,proxy,PROXY
  - RULE-SET,direct,DIRECT
  - RULE-SET,lancidr,DIRECT
  - RULE-SET,cncidr,DIRECT
  - RULE-SET,telegramcidr,PROXY
  - GEOIP,LAN,DIRECT
  - GEOIP,CN,DIRECT
  - MATCH,PROXY
  
  EOF
	serverAddress=$(getYamlValue "/etc/hihy/conf/backup.yaml" "serverAddress")
    port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen" | awk '{gsub(/^:/, ""); print}')
	auth_secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
	tls_sni=$(getYamlValue "/etc/hihy/conf/backup.yaml" "domain")
	insecure=$(getYamlValue "/etc/hihy/conf/backup.yaml" "insecure")
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
	obfs_pass=$(getYamlValue "/etc/hihy/conf/config.yaml" "obfs.salamander.password")
	if [ "${obfs_pass}" == "" ];then
		obfs_status="true"
	fi
	SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initStreamReceiveWindow")
	CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.initConnReceiveWindow")
    max_CRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxConnReceiveWindow")
    max_SRW=$(getYamlValue "/etc/hihy/conf/config.yaml" "quic.maxStreamReceiveWindow")
	download=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.up")
    download=$(echo ${download} | sed 's/[^0-9]//g')
	upload=$(getYamlValue "/etc/hihy/conf/config.yaml" "bandwidth.down")
    upload=$(echo ${upload} | sed 's/[^0-9]//g')
	portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    addOrUpdateYaml "${metaFile}" "proxies[0].name" "${remarks}"
    addOrUpdateYaml "${metaFile}" "proxies[0].type" "hysteria2"
    addOrUpdateYaml "${metaFile}" "proxies[0].server" "${serverAddress}"
    addOrUpdateYaml "${metaFile}" "proxies[0].port" "${port}"
    if [ "${portHoppingStatus}" == "true" ];then
        addOrUpdateYaml "${metaFile}" "proxies[0].ports" "${portHoppingStart}-${portHoppingEnd}"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].password" "${auth_secret}"
    addOrUpdateYaml "${metaFile}" "proxies[0].up" "${upload} Mbps"
    addOrUpdateYaml "${metaFile}" "proxies[0].down" "${download} Mbps"
    addOrUpdateYaml "${metaFile}" "proxies[0].skip-cert-verify" "${insecure}" 
    if [ "${obfs_status}" == "true" ];then
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs" "salamander"
        addOrUpdateYaml "${metaFile}" "proxies[0].obfs-password" "${obfs_pass}"
    fi
    addOrUpdateYaml "${metaFile}" "proxies[0].sni" "${tls_sni}"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].name" "PROXY"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].type" "select"
    addOrUpdateYaml "${metaFile}" "proxy-groups[0].proxies" "[${remarks}]"
	echoColor purple "\n📱 4) [Clash.Mini/ClashX.Meta/Clash.Meta for Android/Clash.verge/openclash] ClashMeta configuration. File location: `echoColor green ${metaFile}`"

checkLogs () {
    if [ -f "/etc/hihy/logs/hihy.log" ]; then
        tail -f /etc/hihy/logs/hihy.log
    else
        echoColor red "Log file does not exist!"
    fi
}

start () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy start
        else
            /etc/init.d/hihy start
        fi
        if [ $? -eq 0 ]; then
            echoColor green "Started successfully!"
        else
            echoColor red "Startup failed!"
        fi
    else
        echoColor red "Startup script not found!"
    fi
}

stop () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy stop
        else
            /etc/init.d/hihy stop
        fi
        if [ $? -eq 0 ]; then
            echoColor green "Stopped successfully!"
        else
            echoColor red "Stop failed!"
        fi
    else
        echoColor red "Startup script not found!"
    fi
}

restart () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            /etc/rc.d/hihy restart
        else
            /etc/init.d/hihy restart
        fi
        if [ $? -eq 0 ]; then
            echoColor green "Restarted successfully!"
        else
            echoColor red "Restart failed!"
        fi
    else
        echoColor red "Startup script not found!"
    fi
}

checkStatus () {
    if [ -f "/etc/rc.d/hihy" ] || [ -f "/etc/init.d/hihy" ]; then
        if [ -f "/etc/rc.d/hihy" ]; then
            msg=$(/etc/rc.d/hihy status)
        else
            msg=$(/etc/init.d/hihy status)
        fi
        if [ $? -ne 0 ]; then
            echoColor red "Status check failed!"
            exit 1
        fi
        if echo "$msg" | grep -q "hihy is running"; then
            echoColor green "Hysteria is running"
            version=$(/etc/hihy/bin/appS version | grep "^Version" | awk '{print $2}')
            echoColor purple "Current version: `echoColor red ${version}`"
        else
            echoColor red "Hysteria is not running"
        fi
    else
        echoColor red "Startup script not found!"
    fi
}
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt $((1024 * 1024)) ]; then
        echo "$(echo "scale=2; $bytes/1024" | bc)KB"
    elif [ $bytes -lt $((1024 * 1024 * 1024)) ]; then
        echo "$(echo "scale=2; $bytes/(1024*1024)" | bc)MB"
    else
        echo "$(echo "scale=2; $bytes/(1024*1024*1024)" | bc)GB"
    fi
}
getHysteriaTrafic() {
    local api_port=$(getYamlValue "/etc/hihy/conf/backup.yaml" "trafficPort")
    local secret=$(getYamlValue "/etc/hihy/conf/config.yaml" "auth.password")
    
    if [ -n "$secret" ]; then
        CURL_OPTS=(-H "Authorization: $secret")
    else
        CURL_OPTS=()
    fi
    
    echo "=========== Hysteria Server Status ==========="
    
    echoColor green "[Traffic Statistics]"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/traffic" | \
    grep -oE '"[^"]+":{"tx":[0-9]+,"rx":[0-9]+}' | \
    while IFS=: read -r user stats; do
        tx=$(echo $stats | grep -oE '"tx":[0-9]+' | cut -d: -f2)
        rx=$(echo $stats | grep -oE '"rx":[0-9]+' | cut -d: -f2)
        user=$(echo $user | tr -d '"')
        tx_formatted=$(format_bytes $tx)
        rx_formatted=$(format_bytes $rx)
        printf "User: %-20s Upload: %8s Download: %8s\n" "$user" "$tx_formatted" "$rx_formatted"
    done
    
    echoColor green "\n[Online Users]"
    curl -s "${CURL_OPTS[@]}" "http://127.0.0.1:${api_port}/online" | \
    grep -oE '"[^"]+":[0-9]+' | \
    while IFS=: read -r user count; do
        user=$(echo $user | tr -d '"')
        count=$(echo $count | tr -d ' ')
        printf "User: %-20s Device Count: %d\n" "$user" "$count"
    done
    
    echoColor green "\n[Active Connections]"
    STREAMS_OUTPUT=$(curl -s "${CURL_OPTS[@]}" -H "Accept: text/plain" "http://127.0.0.1:${api_port}/dump/streams")
    
    if [ "$(echo "$STREAMS_OUTPUT" | wc -l)" -le 1 ]; then
        echo "No active connections currently"
    else
        printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
            "Status" "User" "Connection ID" "Streams" "Upload" "Download" "Alive Time" "Last Active" "Request Address" "Target Address"
        echo "----------|-----------------|------------|------|------------|------------|--------------|--------------|----------------------|----------------------"
        
        temp_file=$(mktemp)
        
        echo "$STREAMS_OUTPUT" | awk 'BEGIN {
            status["ESTAB"]="Established"
            status["CLOSED"]="Closed"
        }
        
        function format_bytes(bytes) {
            if (bytes < 1024) return bytes "B"
            if (bytes < 1024*1024) return sprintf("%.2fKB", bytes/1024)
            if (bytes < 1024*1024*1024) return sprintf("%.2fMB", bytes/(1024*1024))
            return sprintf("%.2fGB", bytes/(1024*1024*1024))
        }
        
        function format_time(time) {
            if (time == "-") return 0
            if (index(time, "ms") > 0) {
                gsub("ms", "", time)
                return time/1000
            }
            if (index(time, "s") > 0) {
                gsub("s", "", time)
                return time
            }
            if (index(time, "m") > 0) {
                gsub("m", "", time)
                return time * 60
            }
            if (index(time, "h") > 0) {
                gsub("h", "", time)
                return time * 3600
            }
            return time
        }
        
        function format_time_display(seconds) {
            if (seconds < 1) return sprintf("%.0fms", seconds * 1000)
            if (seconds < 60) return sprintf("%.1f seconds", seconds)
            if (seconds < 3600) return sprintf("%.1f minutes", seconds/60)
            return sprintf("%.1f hours", seconds/3600)
        }
        
        NR > 1 {
            last_active = format_time($8)
            printf "%s|%s|%s|%s|%s|%s|%s|%.2f|%s|%s\n", \
                status[$1], $2, $3, $4, \
                format_bytes($5), format_bytes($6), \
                format_time_display(format_time($7)), \
                last_active, \
                $9, $10
        }' | sort -t'|' -k8,8nr > "$temp_file"
        
        while IFS='|' read -r state user conn_id flows up down alive last_active req_addr target_addr; do
            printf "%-8s | %-15s | %-10s | %-3s | %-10s | %-10s | %-12s | %-12s | %-20s | %-20s\n" \
                "$state" "$user" "$conn_id" "$flows" "$up" "$down" \
                "$alive" "$(format_time_display $last_active)" "$req_addr" "$target_addr"
        done < "$temp_file"
        
        rm -f "$temp_file"
    fi

    echo "========================================"
}

format_time_display() {
    local seconds=$1
    
    if (( $(echo "$seconds < 1" | bc -l) )); then
        printf "%.0f milliseconds" $(echo "$seconds * 1000" | bc -l)
        return
    fi
    
    if (( $(echo "$seconds < 60" | bc -l) )); then
        printf "%.1f seconds" "$seconds"
        return
    fi
    
    if (( $(echo "$seconds < 3600" | bc -l) )); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "%.1f minutes" "$minutes"
        return
    fi
    
    local hours=$(echo "$seconds / 3600" | bc -l)
    if (( $(echo "$hours < 0.1" | bc -l) )); then
        local minutes=$(echo "$seconds / 60" | bc -l)
        printf "%.1f minutes" "$minutes"
    else
        printf "%.1f hours" "$hours"
    fi
}

delHihyFirewallPort() {
    local port=$(getYamlValue "/etc/hihy/conf/config.yaml" "listen" | awk '{gsub(/^:/, ""); print}')
    local protocol=$1

    if command -v ufw > /dev/null && ufw status | grep -qw "active"; then
        if ufw status | grep -qw "${port}"; then
            ufw delete allow "${port}" 2> /dev/null
            echoColor purple "UFW DELETE: ${port}"
        fi
    elif command -v firewall-cmd > /dev/null && systemctl is-active --quiet firewalld; then
        if firewall-cmd --list-ports --permanent | grep -qw "${port}/${protocol}"; then
            firewall-cmd --zone=public --remove-port="${port}/${protocol}" --permanent 2> /dev/null
            firewall-cmd --reload 2> /dev/null
            echoColor purple "FIREWALLD DELETE: ${port}/${protocol}"
        fi
    elif command -v iptables > /dev/null; then
        iptables-save | sed -e "/hihysteria/d" | iptables-restore
        ip6tables-save | sed -e "/hihysteria/d" | ip6tables-restore
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active --quiet netfilter-persistent; then
                netfilter-persistent save
            fi
        fi
        if [ -f "/etc/rc.d/allow-port" ]; then
            sed -i "/${protocol}\/${port}(hihysteria)/d" /etc/rc.d/allow-port
        fi

        echoColor purple "IPTABLES DELETE: ${port}/${protocol}"
    fi
}

changeIp64(){
    local socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
    local config_file="/etc/hihy/conf/config.yaml"
    if [ "${socks5_status}" == "true" ];then
        echoColor red "SOCKS5 forwarding is currently enabled; modifying priority is not supported. Use ACL management for traffic splitting."
        exit 1
    fi
    mode_now=$(getYamlValue "$config_file" "outbounds[0].direct.mode")

    echoColor purple "Current mode: `echoColor red ${mode_now}`"
    echoColor yellow "1) IPv4 priority"
    echoColor yellow "2) IPv6 priority"
    echoColor yellow "3) Auto-select"
    echoColor yellow "0) Exit"
    read -p "Select an option: " input
    case $input in
        1)
            if [ "${mode_now}" == "46" ];then
                echoColor yellow "Already in IPv4 priority mode"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "46"
                restart
                echoColor green "Switch successful"
            fi
        ;;
        2) 
            if [ "${mode_now}" == "64" ];then
                echoColor yellow "Already in IPv6 priority mode"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "64"
                restart
                echoColor green "Switch successful"
            fi
        ;;
        3) 
            if [ "${mode_now}" == "auto" ];then
                echoColor yellow "Already in auto-select mode"
            else
                addOrUpdateYaml "$config_file" "outbounds[0].direct.mode" "auto"
                restart
                echoColor green "Switch successful"
            fi
        ;;
        0) exit 0 ;;
        *) echoColor red "Invalid input!"; exit 1 ;;
    esac
}

changeServerConfig(){
    if [ ! -e "/etc/rc.d/hihy" ] && [ ! -e "/etc/init.d/hihy" ]; then
        echoColor red "Please install Hysteria2 before modifying the configuration..."
        exit
    fi
    portHoppingStatus=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStatus")
    if [ "${portHoppingStatus}" == "true" ];then
        portHoppingStart=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingStart")
        portHoppingEnd=$(getYamlValue "/etc/hihy/conf/backup.yaml" "portHoppingEnd")
    fi
    masquerade_tcp=$(getYamlValue "/etc/hihy/conf/backup.yaml" "masquerade_tcp")
    stop
    if [ "${portHoppingStatus}" == "true" ];then
        delPortHoppingNat
    fi
    if [ "${masquerade_tcp}" == "true" ];then
        delHihyFirewallPort tcp
        delHihyFirewallPort udp
    else
        delHihyFirewallPort udp
    fi
    updateHysteriaCore
    setHysteriaConfig
    start
    generate_client_config
    echoColor green "Configuration modified successfully"
}

aclControl(){
    local acl_file="/etc/hihy/acl/acl.txt"
    if [ ! -f "${acl_file}" ]; then
        echoColor red "ACL file not found"
        exit 1
    fi
    echoColor purple "Select a management operation:"
    echoColor yellow "1) Add"
    echoColor yellow "2) Delete"
    echoColor yellow "3) View"
    echoColor yellow "0) Exit"
    read -p "Select an option: " input
    case $input in
        1)
            echoColor green "Select an ACL control method"
            echoColor yellow "1) Add IPv4-only domain routing"
            echoColor yellow "2) Add IPv6-only domain routing"
            echoColor yellow "3) Add blocked domain"
            read -p "Select an option: " input
            case $input in
                1)
                    read -p "Enter the domain for IPv4 routing: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "Domain cannot be empty"
                        exit 1
                    fi
                    if grep -q "v4_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "Rule already exists"
                    else
                        echo "v4_only(suffix:${domain})" >> "${acl_file}"
                        echoColor green "Added successfully"
                        restart
                    fi
                ;;
                2)
                    read -p "Enter the domain for IPv6 routing: " domain
                    if [ -z "${domain}" ]; then
                        echoColor red "Domain cannot be empty"
                        exit 1
                    fi
                    if grep -q "v6_only(suffix:${domain})" "${acl_file}"; then
                        echoColor red "Rule already exists"
                    else
                        echo "v6_only(suffix:${domain})" >> "${acl_file}"
                        echoColor green "Added successfully"
                        restart
                    fi
                ;;
                3)
                    read -p "Enter the domain to block: " rejectInput
                    if [ -z "${rejectInput}" ]; then
                        echoColor red "Domain cannot be empty"
                        exit 1
                    fi
                    if grep -q "reject(suffix:${rejectInput})" "${acl_file}"; then
                        echoColor red "Rule already exists"
                    else
                        echo "reject(suffix:${rejectInput})" >> "${acl_file}"
                        echoColor green "Added successfully"
                        restart
                    fi
                ;;
                *) echoColor red "Invalid input!"; exit 1 ;;
            esac
        ;;
        2)
            read -p "Enter the domain rule to delete: " domain
            if [ -z "${domain}" ]; then
                echoColor red "Domain cannot be empty"
                exit 1
            fi
            if grep -q "${domain}" "${acl_file}"; then
                sed -i "/${domain}/d" "${acl_file}"
                echoColor green "Deleted successfully"
                restart
            else
                echoColor red "Rule does not exist"
            fi
        ;;
        3)
            echoColor purple "Current ACL list:"
            cat "${acl_file}"
        ;;
        0) exit 0 ;;
        *) echoColor red "Invalid input!"; exit 1 ;;
    esac
}

addSocks5Outbound(){
    if [ ! -f "/etc/hihy/conf/config.yaml" ]; then
        echoColor red "Configuration file not found"
        exit 1
    fi
    local server_config="/etc/hihy/conf/config.yaml"
    local backup_config="/etc/hihy/conf/backup.yaml"
    echo -e "Tip: WireProxy uses Cloudflare Warp to provide a free and efficient SOCKS5 proxy, with lower overhead than full Warp, recommended for low-performance machines."
    echo -e "\033[32mSelect an option:\n\n\033[0m\033[33m\033[01m1) Automatically add a Warp SOCKS5 interface as Hysteria2 outbound (default, using fscarmen WireProxy solution)\n2) Custom SOCKS5 address\n3) Remove configured outbound\033[0m\033[32m\n\nEnter option number:\033[0m"
    read num
    if [ -z "${num}" ] || [ ${num} == "1" ];then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ];then
            echoColor red "SOCKS5 outbound is already enabled; remove it before adding a new one"
            exit 1
        fi
        local conf_file="/etc/wireguard/proxy.conf"
        if [ -f "$conf_file" ]; then
            echoColor green "Found WireProxy configuration file, using current settings"
        else
            wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh w
        fi
        
        if [ ! -f "$conf_file" ]; then
            echoColor red "WireProxy configuration file not found; ensure WireProxy is installed correctly"
            exit 1
        fi
        local port=$(grep "BindAddress" "$conf_file" | grep -v "^#" | awk -F':' '{print $2}')
        echoColor purple "-> Local WireProxy SOCKS5 port: `echoColor red ${port}`"
        
        yq eval '.outbounds = [{"name": "warp", "type": "socks5", "socks5": {"addr": "127.0.0.1:'$port'"}}] + .outbounds' -i "${server_config}"

        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "Added Warp outbound successfully"

    elif [ ${num} == "2" ];then
        socks5_status=$(getYamlValue "/etc/hihy/conf/backup.yaml" "socks5_status")
        if [ "${socks5_status}" == "true" ];then
            echoColor red "SOCKS5 outbound is already enabled; remove it before adding a new one"
            exit 1
        fi
        read -p "Enter SOCKS5 address (IP:port): " socks5_addr
        if [ -z "${socks5_addr}" ]; then
            echoColor red "Address cannot be empty"
            exit 1
        fi
        read -p "Enter SOCKS5 username (leave empty if no authentication): " socks5_user
        if [ -n "${socks5_user}" ]; then
            read -p "Enter SOCKS5 password: " socks5_pass
            if [ -z "${socks5_pass}" ]; then
                echoColor red "Password cannot be empty"
                exit 1
            fi
        fi
        local server_config="/etc/hihy/conf/config.yaml"
        if [ -n "${socks5_user}" ]; then
            yq eval '.outbounds = [{"name": "warp", "type": "socks5", "socks5": {"addr": "127.0.0.1:'$port'", "username": "'$socks5_user'", "password": "'$socks5_pass'"}}] + .outbounds' -i "${server_config}"
        else
            yq eval '.outbounds = [{"name": "warp", "type": "socks5", "socks5": {"addr": "127.0.0.1:'$port'"}}] + .outbounds' -i "${server_config}"
        fi
        restart
        addOrUpdateYaml ${backup_config} "socks5_status" "true"
        echoColor green "Added SOCKS5 outbound successfully"
    elif [ ${num} == "3" ];then
        outbound_name=$(getYamlValue ${server_config} "outbounds[0].name")
        if [ "${outbound_name}" == "warp" ] || [ "${outbound_name}" == "custom" ];then
            yq eval 'del(.outbounds[0])' -i "${server_config}"
            if [ "${outbound_name}" == "warp" ];then
                warp u
            fi
            restart
            addOrUpdateYaml ${backup_config} "socks5_status" "false"
            echoColor green "Removed successfully"
        else
            echoColor red "No SOCKS5 outbound found"
        fi
    else
        echoColor red "Invalid input"
        exit 1
    fi
}

show_menu() {
    clear
    echo -e " -------------------------------------------"
    echo -e "|**********      Hi Hysteria       **********|"
    echo -e "|**********    Author: emptysuns   **********|"
    echo -e "|**********     Version: $(echoColor red "${hihyV}")    **********|"
    echo -e " -------------------------------------------"
    echo -e "Tip: Run `hihy` command to execute this script again."
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "1)  Install Hysteria2")"
    echo -e "$(echoColor magenta "2)  Uninstall")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "3)  Start")"
    echo -e "$(echoColor magenta "4)  Stop")"
    echo -e "$(echoColor yellow "5)  Restart")"
    echo -e "$(echoColor yellow "6)  Check status")"
    echo -e "$(echoColor skyBlue ".....................")"
    echo -e "$(echoColor yellow "7)  Update core")"
    echo -e "$(echoColor yellow "8)  View current configuration")"
    echo -e "$(echoColor red "9)  Reconfigure")"
    echo -e "$(echoColor yellow "10) Switch IPv4/IPv6 priority")"
    echo -e "$(echoColor yellow "11) Update hihy")"
    echo -e "$(echoColor lightMagenta "12) ACL domain routing")"
    echo -e "$(echoColor skyBlue "13) View Hysteria2 statistics")"
    echo -e "$(echoColor yellow "14) View real-time logs")"
    echo -e "$(echoColor yellow "15) Add SOCKS5 outbound [supports Warp auto-configuration]")"

    echo -e "$(echoColor purple "###############################")"

    echo -e "$(echoColor magenta "0) Exit")"
    echo -e "$(echoColor skyBlue ".............................................")"
    echo -e ""
    hihy_update_notifycation
    hyCore_update_notifycation
    echo -e "\n"
}

wait_for_continue() {
    echo -e "\n$(echoColor green "Press any key to return to the main menu...")"
    read -n 1 -s
}

menu() {
    while true; do
        show_menu
        read -p "Select an option: " input
        case $input in
            1) install; exit 0 ;;
            2) uninstall; exit 0 ;;
            3) start; wait_for_continue ;;
            4) stop; wait_for_continue ;;
            5) restart; wait_for_continue ;;
            6) checkStatus; wait_for_continue ;;
            7) updateHysteriaCore; exit 0 ;;
            8) generate_client_config; wait_for_continue ;;
            9) changeServerConfig; exit 0 ;;
            10) changeIp64; exit 0 ;;
            11) hihyUpdate; exit 0 ;;
            12) aclControl; exit 0 ;;
            13) getHysteriaTrafic; wait_for_continue ;;
            14) checkLogs; exit 0 ;;
            15) addSocks5Outbound; exit 0 ;;
            0) exit 0 ;;
            *) echoColor red "Invalid input!"; wait_for_continue ;;
        esac
    done
}

checkRoot
case "$1" in
    install|1) echoColor purple "-> 1) Install Hysteria"; install ;;
    uninstall|2) echoColor purple "-> 2) Uninstall Hysteria"; uninstall ;;
    start|3) echoColor purple "-> 3) Start Hysteria"; start ;;
    stop|4) echoColor purple "-> 4) Stop Hysteria"; stop ;;
    restart|5) echoColor purple "-> 5) Restart Hysteria"; restart ;;
    checkStatus|6) echoColor purple "-> 6) Check status"; checkStatus ;;
    updateHysteriaCore|7) echoColor purple "-> 7) Update core"; updateHysteriaCore ;;
    generate_client_config|8) echoColor purple "-> 8) View current configuration"; generate_client_config ;;
    changeServerConfig|9) echoColor purple "-> 9) Reconfigure"; changeServerConfig ;;
    changeIp64|10) echoColor purple "-> 10) Switch IPv4/IPv6 priority"; changeIp64 ;;
    hihyUpdate|11) echoColor purple "-> 11) Update hihy"; hihyUpdate ;;
    aclControl|12) echoColor purple "-> 12) ACL management"; aclControl ;;
    getHysteriaTrafic|13) echoColor purple "-> 13) View Hysteria statistics"; getHysteriaTrafic ;;
    checkLogs|14) echoColor purple "-> 14) View real-time logs"; checkLogs ;;
    addSocks5Outbound|15) echoColor purple "-> 15) Add SOCKS5 outbound"; addSocks5Outbound ;;
    cronTask) cronTask ;;
    *) menu ;;
esac
