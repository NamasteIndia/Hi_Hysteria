#!/bin/bash
echo -e "\033[32mPlease select the version of hysteria to install:\n\n\033[0m\033[33m\033[01m1. hysteria2 (recommended, LTS with better performance)\n2. hysteria1 (NLTS, no future feature updates, but supports faketcp. Choose if affected by UDP QoS)\033[0m\033[32m\n\nEnter the number:\033[0m"
read hysteria_version
if [ "$hysteria_version" = "1" ] || [ -z "$hysteria_version" ]; then
    hysteria_version="hysteria2"
elif [ "$hysteria_version" = "2" ]; then
    hysteria_version="hysteria1"
else
    echo -e "\033[31mInvalid input, please rerun the script\033[0m"
    exit 1
fi
echo -e "-> The selected hysteria version is: \033[32m$hysteria_version\033[0m"
echo -e "Downloading hihy..."

if [ "$hysteria_version" = "hysteria2" ]; then
    wget -q --no-check-certificate -O /usr/bin/hihy https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/main/server/hy2.sh && chmod +x /usr/bin/hihy
else
    wget -q --no-check-certificate -O /usr/bin/hihy https://raw.githubusercontent.com/emptysuns/Hi_Hysteria/refs/heads/v1/server/install.sh && chmod +x /usr/bin/hihy
fi
/usr/bin/hihy
