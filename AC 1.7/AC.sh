#!/bin/bash

################################################################
#                                                              #
#       Jonfer AC v1.6 - Dual Mode + Dynamic UI Release        #
#       - Spinner animation (visible)                          #
#       - Dynamic Time Remaining (ETA)                         #
#       - Progress bar with color                              #
#       - Improved input editing with readline                 #
#       - Supports both interactive and automatic input        #
#       - Red error output for failed IPs                      #
#       - Now accepts lowercase or uppercase input             #
#       Release date: 2025-04-11                               #
#                                                              #
################################################################

ipmi_user="admin"
ipmi_password="admin"

ssh_user="sysadmin"
ssh_password="superuser"

failed_ips=()

# Remove the host key.
remove_key() {
    local ip=$1
    if ssh-keygen -F "$ip" &>/dev/null; then
        ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R "$ip" &>/dev/null
    fi
}

# Spinner animation
show_spinner() {
    local pid=$1
    local delay=0.15
    local spinstr='⣷⣯⣟⡿⢿⣻⣽⣾'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        remaining_ips=$((total_ips - processed_ips))
        time_remaining=$((remaining_ips * 3))
        spinner_char="${spinstr:$i:1}"

        printf "\rRestarting IP: %s [ \033[38;5;10m%-50s\033[0m ] %3d%%  %s  ⏳ Time Remaining: %2ds" \
            "$current_ip" "$filled_bar" "$progress" "$spinner_char" "$time_remaining"

        i=$(( (i + 1) % ${#spinstr} ))
        sleep $delay
    done
}

# Reboot the chassis.
chassis_reboot() {
    local ip=$1
    restart_command="ipmitool -I lanplus -H $ip -U $ipmi_user -P $ipmi_password chassis power on &>/dev/null && ipmitool -I lanplus -H $ip -U $ipmi_user -P $ipmi_password chassis power reset &>/dev/null && sleep 1 && ipmitool -I lanplus -H $ip -U $ipmi_user -P $ipmi_password chassis power cycle &>/dev/null && sleep 1 && ipmitool -I lanplus -H $ip -U $ipmi_user -P $ipmi_password chassis power on &>/dev/null"

    timeout 10 sshpass -p "$ssh_password" ssh -o StrictHostKeyChecking=no "$ssh_user@$ip" "$restart_command" 2>/dev/null
    return $?
}

# Build and process IPs from the combination of octets and letters.
process_ips() {
    local total=$1
    shift
    local ip_list=("$@")

    total_ips=$total
    processed_ips=0

    for ip in "${ip_list[@]}"; do
        current_ip=$ip
        remove_key $ip

        progress=$((processed_ips * 100 / total_ips))
        filled_bar=$(printf "%0.s#" $(seq 1 $((progress / 2))))
        empty_bar=$(printf "%0.s-" $(seq 1 $((50 - progress / 2))))

        chassis_reboot "$ip" &
        spinner_pid=$!
        show_spinner "$spinner_pid"
        wait "$spinner_pid"
        result=$?

        if [ $result -ne 0 ]; then
            failed_ips+=("$ip")
        fi

        processed_ips=$((processed_ips + 1))
    done

    # Asegurar que la barra llegue al 100%
    printf "\rRestarting IP: %s [ \033[38;5;10m%-50s\033[0m ] 100%%\n" "${ip_list[-1]}" $(printf "%0.s#" $(seq 1 50))
}

# Request and process input.
if [[ $# -gt 0 ]]; then
    # 🎯 Modo automático (parámetros desde otro script)
    array=("$@")
    skip_input=true
else
    # 🧑 Modo manual (interactivo)
    skip_input=false
fi

valid_input=true
ip_list=()

if $skip_input; then
    combinations="${array[*]}"
else
    read -e -p "Input IP list to restart (for example, 1 AD 2 bc 3 ad 4 all): " combinations
    IFS=' ' read -r -a array <<< "$combinations"
fi

for ((i=0; i<${#array[@]}; i+=2)); do
    third_octet=${array[i]}
    letters=${array[i+1]}

    if ! [[ "$third_octet" =~ ^[0-9]+$ ]] || [ "$third_octet" -lt 0 ] || [ "$third_octet" -gt 255 ]; then
        echo "Please, input a valid value for the third octet."
        valid_input=false
        break
    fi

    if [[ "${letters^^}" == "ALL" ]]; then
        letters="ABCD"
    fi

    for letter in $(echo "$letters" | tr '[:lower:]' '[:upper:]' | grep -o .); do
        case $letter in
            A) fourth_octet=5 ;;
            B) fourth_octet=8 ;;
            C) fourth_octet=11 ;;
            D) fourth_octet=14 ;;
            *)
                echo "Invalid option: $letter"
                continue
                ;;
        esac

        ip="172.26.$third_octet.$fourth_octet"
        ip_list+=("$ip")
    done
done

if $valid_input; then
    total_ips=${#ip_list[@]}
    echo -e "\nStarting process for $total_ips IPs...\n"
    process_ips $total_ips "${ip_list[@]}"
fi

# Show IPs unable to establish connection with.
if [ ${#failed_ips[@]} -ne 0 ]; then
    echo -e "\n\033[0;31mUnable to establish connection with:\033[0m"
    for ip in "${failed_ips[@]}"; do
        echo -e "\033[0;31m$ip\033[0m"
    done
fi
