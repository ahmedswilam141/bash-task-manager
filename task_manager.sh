#!/bin/bash
DATA_FILE="tasks.txt"
DELIM="|"

# Ensure data file exists
touch "$DATA_FILE"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

print_header() {
    echo -e "${BOLD}${CYAN}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║         🗂  Mini Task Manager         ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${RESET}"
}

print_section() {
    echo -e "\n${BOLD}${BLUE}── $1 ──────────────────────────────────${RESET}"
}

print_table_header() {
    echo -e "${BOLD}$(printf "%-5s %-20s %-10s %-12s %-12s" "ID" "Title" "Priority" "Due Date" "Status")${RESET}"
    echo -e "${DIM}$(printf '─%.0s' {1..63})${RESET}"
}

# Color-code a single task row based on its priority and status
print_task_row() {
    local id="$1" title="$2" priority="$3" due="$4" status="$5"

    local priority_color="$RESET"
    case "$priority" in
        high)   priority_color="$RED"    ;;
        medium) priority_color="$YELLOW" ;;
        low)    priority_color="$GREEN"  ;;
    esac

    local status_color="$RESET"
    case "$status" in
        *pending*)     status_color="$YELLOW" ;;
        *in-progress*) status_color="$CYAN"   ;;
        *done*)        status_color="$GREEN"  ;;
    esac

    printf "%-5s %-20s ${priority_color}%-10s${RESET} %-12s ${status_color}%-12s${RESET}\n" \
        "$id" "$title" "$priority" "$due" "$status"
}

generate_id() {
    if [[ ! -s "$DATA_FILE" ]]; then
        echo 1
    else
        awk -F"$DELIM" '{print $1}' "$DATA_FILE" | sort -n | tail -1 | awk '{print $1+1}'
    fi
}

validate_priority() {
    [[ "$1" =~ ^(high|medium|low)$ ]]
}

validate_date() {
    date -d "$1" "+%Y-%m-%d" &>/dev/null
}

task_exists() {
    grep -q "^$1$DELIM" "$DATA_FILE"
}

pause() {
    echo -e "\n${DIM}Press Enter to continue...${RESET}"
    read -rp ""
}

add_task() {
    print_section "Add New Task"

    read -rp "$(echo -e "${CYAN}Title: ${RESET}")" title
    [[ -z "$title" ]] && echo -e "${RED}Title cannot be empty${RESET}" && return

    read -rp "$(echo -e "${CYAN}Priority (high|medium|low): ${RESET}")" priority
    validate_priority "$priority" || { echo -e "${RED}Invalid priority${RESET}"; return; }

    read -rp "$(echo -e "${CYAN}Due date (YYYY-MM-DD): ${RESET}")" due
    validate_date "$due" || { echo -e "${RED}Invalid date${RESET}"; return; }

    id=$(generate_id)
    echo "$id$DELIM$title$DELIM$priority$DELIM$due${DELIM}pending" >> "$DATA_FILE"
    echo -e "\n${GREEN}✔ Task added successfully.${RESET}"
}

list_tasks() {
    print_section "All Tasks"

    if [[ ! -s "$DATA_FILE" ]]; then
        echo -e "${YELLOW}No tasks found.${RESET}"
        return
    fi

    print_table_header

    while IFS="$DELIM" read -r id title priority due status; do
        print_task_row "$id" "$title" "$priority" "$due" "$status"
    done < "$DATA_FILE"
}

update_task() {
    print_section "Update Task"

    read -rp "$(echo -e "${CYAN}Enter Task ID: ${RESET}")" id
    task_exists "$id" || { echo -e "${RED}Task not found${RESET}"; return; }

    read -rp "$(echo -e "${CYAN}New Title: ${RESET}")" title
    read -rp "$(echo -e "${CYAN}New Priority (high|medium|low): ${RESET}")" priority
    read -rp "$(echo -e "${CYAN}New Due Date (YYYY-MM-DD): ${RESET}")" due
    read -rp "$(echo -e "${CYAN}New Status (pending|in-progress|done): ${RESET}")" status

    validate_priority "$priority" || { echo -e "${RED}Invalid priority${RESET}"; return; }
    validate_date "$due"          || { echo -e "${RED}Invalid date${RESET}"; return; }

    sed -i "/^$id$DELIM/c\\$id$DELIM$title$DELIM$priority$DELIM$due$DELIM$status" "$DATA_FILE"
    echo -e "\n${GREEN}✔ Task updated.${RESET}"
}

delete_task() {
    print_section "Delete Task"

    read -rp "$(echo -e "${CYAN}Enter Task ID: ${RESET}")" id
    task_exists "$id" || { echo -e "${RED}Task not found${RESET}"; return; }

    read -rp "$(echo -e "${RED}Are you sure? (y/n): ${RESET}")" confirm
    if [[ "$confirm" == "y" ]]; then
        sed -i "/^$id$DELIM/d" "$DATA_FILE"
        echo -e "${GREEN}✔ Task deleted.${RESET}"
    else
        echo -e "${YELLOW}Deletion cancelled.${RESET}"
    fi
}

search_tasks() {
    print_section "Search Tasks"

    read -rp "$(echo -e "${CYAN}Keyword: ${RESET}")" keyword

    if [[ ! -s "$DATA_FILE" ]]; then
        echo -e "${YELLOW}No tasks found.${RESET}"
        return
    fi

    print_table_header

    local count=0
    while IFS="$DELIM" read -r id title priority due status; do
        if echo "$title" | grep -qi "$keyword"; then
            print_task_row "$id" "$title" "$priority" "$due" "$status"
            ((count++))
        fi
    done < "$DATA_FILE"

    echo -e "\n${BOLD}Found: ${count} task(s)${RESET}"
}

task_summary() {
    print_section "Task Summary"

    local pending=0 in_progress=0 done_count=0

    while IFS="$DELIM" read -r id title priority due status; do
        case "$status" in
            *pending*)     ((pending++))     ;;
            *in-progress*) ((in_progress++)) ;;
            *done*)        ((done_count++))  ;;
        esac
    done < "$DATA_FILE"

    echo -e "  ${YELLOW}Pending     : ${pending}${RESET}"
    echo -e "  ${CYAN}In-Progress : ${in_progress}${RESET}"
    echo -e "  ${GREEN}Done        : ${done_count}${RESET}"
    echo -e "  ${BOLD}──────────────────${RESET}"
    echo -e "  ${BOLD}Total       : $((pending + in_progress + done_count))${RESET}"
}

overdue_tasks() {
    print_section "Overdue Tasks"

    today=$(date +%Y-%m-%d)
    echo -e "${DIM}Today: ${today}${RESET}\n"

    if [[ ! -s "$DATA_FILE" ]]; then
        echo -e "${YELLOW}No tasks found.${RESET}"
        return
    fi

    print_table_header

    local count=0
    while IFS="$DELIM" read -r id title priority due status; do
        if [[ "$due" < "$today" && "$status" != *done* ]]; then
            print_task_row "$id" "$title" "$priority" "$due" "$status"
            ((count++))
        fi
    done < "$DATA_FILE"

    if [[ $count -eq 0 ]]; then
        echo -e "${GREEN}No overdue tasks!${RESET}"
    else
        echo -e "\n${RED}${BOLD}${count} overdue task(s).${RESET}"
    fi
}

priority_report() {
    print_section "Priority Report"

    for level in high medium low; do
        case "$level" in
            high)   echo -e "\n${RED}${BOLD}▶ HIGH${RESET}"     ;;
            medium) echo -e "\n${YELLOW}${BOLD}▶ MEDIUM${RESET}" ;;
            low)    echo -e "\n${GREEN}${BOLD}▶ LOW${RESET}"     ;;
        esac

        print_table_header

        local count=0
        while IFS="$DELIM" read -r id title priority due status; do
            if [[ "$priority" == "$level" ]]; then
                print_task_row "$id" "$title" "$priority" "$due" "$status"
                ((count++))
            fi
        done < "$DATA_FILE"

        [[ $count -eq 0 ]] && echo -e "  ${DIM}(none)${RESET}"
    done
}

while true; do
    clear
    print_header
    echo -e "  ${CYAN}1${RESET}) ➕  Add Task"
    echo -e "  ${CYAN}2${RESET}) 📋  List Tasks"
    echo -e "  ${CYAN}3${RESET}) ✏️   Update Task"
    echo -e "  ${CYAN}4${RESET}) 🗑️   Delete Task"
    echo -e "  ${CYAN}5${RESET}) 🔍  Search Tasks"
    echo -e "  ${CYAN}6${RESET}) 📊  Task Summary"
    echo -e "  ${CYAN}7${RESET}) ⏰  Overdue Tasks"
    echo -e "  ${CYAN}8${RESET}) 🏷️   Priority Report"
    echo -e "  ${CYAN}9${RESET}) 🚪  Exit"
    echo ""
    read -rp "$(echo -e "${CYAN}Choose: ${RESET}")" choice

    case $choice in
        1) add_task        ;;
        2) list_tasks      ;;
        3) update_task     ;;
        4) delete_task     ;;
        5) search_tasks    ;;
        6) task_summary    ;;
        7) overdue_tasks   ;;
        8) priority_report ;;
        9) echo -e "\n${GREEN}Goodbye! 👋${RESET}\n"; exit ;;
        *) echo -e "${RED}Invalid option${RESET}" ;;
    esac

    pause
done
