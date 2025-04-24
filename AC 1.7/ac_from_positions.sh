#!/bin/bash

RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
BOLD="\033[1m"
RESET="\033[0m"

declare -A SECTION_BY_RACK
for i in $(seq 1 10); do SECTION_BY_RACK[$i]="A"; done
for i in $(seq 11 20); do SECTION_BY_RACK[$i]="B"; done
for i in $(seq 21 30); do SECTION_BY_RACK[$i]="C"; done
for i in $(seq 31 40); do SECTION_BY_RACK[$i]="D"; done

ALL_IPS=()
for rack in $(seq 1 40); do
    for host in 4 7 10 13; do
        ALL_IPS+=("172.26.$rack.$host")
    done
done
for rack in $(seq 92 99); do
    for host in 4 7 10 13; do
        ALL_IPS+=("172.26.$rack.$host")
    done
done

check_ip() {
    ip=$1
    if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
        echo "$ip|ON"
    else
        echo "$ip|OFF"
    fi
}
export -f check_ip

echo -e "\n${CYAN}"
cat << "EOF"
 █████╗  ██████╗    ████████╗███████╗███████╗████████╗███████╗██████╗ ███████╗
██╔══██╗██╔════╝    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝██╔════╝██╔══██╗██╔════╝
███████║██║            ██║   █████╗  ███████╗   ██║   █████╗  ██████╔╝███████╗
██╔══██║██║            ██║   ██╔══╝  ╚════██║   ██║   ██╔══╝  ██╔══██╗╚════██║
██║  ██║╚██████╗       ██║   ███████╗███████║   ██║   ███████╗██║  ██║███████║
╚═╝  ╚═╝ ╚═════╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   ╚══════╝╚═╝  ╚═╝╚══════╝
-------------------------------------------------------------------------------
EOF

echo -e "${CYAN}Execution time: $(date '+%Y-%m-%d %H:%M:%S')${RESET}\n"
echo
echo -e "${RED}                         By Eng. Jonathan Jimenez 💻${RESET}"
echo -e ">>Checking tester status..."
results=$(printf "%s\n" "${ALL_IPS[@]}" | xargs -P 80 -I{} bash -c 'check_ip "$@"' _ {})

declare -A STATUS_MAP
for line in $results; do
    ip="${line%%|*}"
    status="${line##*|}"
    STATUS_MAP["$ip"]=$status

done

main_lines=()
nv_lines=()

for section in A B C D; do
    main_lines+=("  Section $section")
    for rack in $(seq 1 40); do
        if [[ "${SECTION_BY_RACK[$rack]}" == "$section" ]]; then
            line=""
            for host in 4 7 10 13; do
                ip="172.26.$rack.$host"
                status="${STATUS_MAP[$ip]}"
                color=$([[ "$status" == "ON" ]] && echo "$GREEN" || echo "$RED")
                line+=$(printf "${color}[%4s]${RESET} %-17s" "$status" "$ip")
            done
            main_lines+=("$line")
        fi
    done
    main_lines+=("")
done

nv_lines+=("NV Vulcan")
for rack in $(seq 92 95); do
    line=""
    for host in 4 7 10 13; do
        ip="172.26.$rack.$host"
        status="${STATUS_MAP[$ip]}"
        color=$([[ "$status" == "ON" ]] && echo "$GREEN" || echo "$RED")
        line+=$(printf "${color}[%4s]${RESET} %-17s" "$status" "$ip")
    done
    nv_lines+=("$line")
done

nv_lines+=("NV Umbriel")
for rack in $(seq 96 99); do
    line=""
    for host in 4 7 10 13; do
        ip="172.26.$rack.$host"
        status="${STATUS_MAP[$ip]}"
        color=$([[ "$status" == "ON" ]] && echo "$GREEN" || echo "$RED")
        line+=$(printf "${color}[%4s]${RESET} %-17s" "$status" "$ip")
    done
    nv_lines+=("$line")
done

max_lines=${#main_lines[@]}
for i in $(seq 0 $((max_lines - 1))); do
    left="${main_lines[$i]}"
    right="${nv_lines[$i]:-}"
    printf "${CYAN}|${RESET} %-96s ${CYAN}|    ${RESET} %s\n" "$left" "$right"
done

declare -A base_rack=( ["A"]=1 ["B"]=11 ["C"]=21 ["D"]=31 )
declare -a letters=("D" "C" "B" "A")

echo -e "Paste section and tester numbers (end with Ctrl+D):"
input=$(</dev/stdin)

current_section=""
args=()

reading_apagar=false

while IFS= read -r line; do
    if [[ $line =~ (SECTION|SECCION)[[:space:]]+([A-D]) ]]; then
        current_section="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ TESTER[[:space:]]+PARA[[:space:]]+APAGAR ]]; then
        reading_apagar=true
    elif [[ "$line" =~ TESTER[[:space:]]+PARA[[:space:]]+ATENDER ]]; then
        reading_apagar=false
    elif $reading_apagar && [[ $line =~ ^[0-9] ]]; then
        for pos in $line; do
            rack_local=$(( (pos - 1) / 4 + 1 ))
            rack_real=$(( ${base_rack[$current_section]} + rack_local - 1 ))
            tester_index=$(( (pos - 1) % 4 ))
            letter=${letters[$tester_index]}
            args+=("$rack_real" "$letter")
        done
    fi
done <<< "$input"



echo -e ">>Executing script AC.sh with: ${args[*]}"
./AC.sh "${args[@]}"
