#!/bin/bash

# to-do move cfg vars to file
idle_wait=15

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
GRAY=$(tput setaf 7)
DARKGRAY=$(tput setaf 8)
LRED=$(tput setaf 9)
LGREEN=$(tput setaf 10)
LYELLOW=$(tput setaf 11)
LBLUE=$(tput setaf 12)
LMAGENTA=$(tput setaf 13)
LCYAN=$(tput setaf 14)
WHITE=$(tput setaf 15)
DEF=$(tput sgr0)


# tty write helpers

pt(){
  pmprompt="${DARKGRAY}[${MAGENTA}pm${DARKGRAY}]"
  pmprompt="${pmprompt}[${GRAY}$(date "+%b %d %H:%M:%S")${DARKGRAY}]"
  pmprompt="${pmprompt}[${MAGENTA}${pt_action}${DARKGRAY}]"
  pmprompt="${pmprompt}[${GREEN}${pt_host}${DARKGRAY}]${DEF}# "
  echo -en "${pmprompt}"
}

pt_set_host(){
 if [[ -z "$1" ]]; then
   pr_padding=0
   pt_host="$1"

 else
   current_hostname_length="${#1}"
   pr_hostpadding=$(( (longest_hostname - current_hostname_length) ))
   pr_padding=$(( (longest_hostname - current_hostname_length) - pr_hostpadding ))
   pt_host="$1$(printf ' %.0s' {1..#$(seq 1 $pr_hostpadding)})"

 fi

}

pt_set_action(){
 pt_action="$1"
}

pr(){

  pr_ommit_newline=false
  pr_highlight=false
  pr_warning=false
  pr_fatal=false
  pr_ok=false
  pr_aftercolor=false

  case "$1" in
    *n*)
      pr_ommit_newline=true
      ;;
    *h*)
      pr_highlight=true
      ;;
    *w*)
      pr_warning=true
      ;;
    *f*)
      pr_fatal=true
      ;;
    *o*)
      pr_ok=true
      ;;
    *r*)
      pr_aftercolor=true
      ;;
  esac
  # )
render="$(pt)"
[[ "$pr_padding" -gt 0 ]] && render="$(printf ' %.0s' {1..#$(seq 1 $padding)})"
$pr_fatal && render="${render}${RED}FATAL: ${DEF}"
$pr_warning && render="${render}${YELLOW}WARN:  ${DEF}"
$pr_highlight && render="${render}${DEF}$2 ${CYAN}${@:3}${DEF}" || render="${render}${DEF}${@:2}${DEF}"
$pr_aftercolor && render="${render} ${YELLOW}"

( $pr_ommit_newline || $pr_aftercolor ) && echo -en "$render" || echo -e "$render${DEF}"
$pr_fatal && exit

}

pr_debugger(){
  pr p "No formatting" "No formatting here either"
  pr w "Warning"
  pr f "Fatal"
  pr h "Highlight" "THIS"
  pr r "Read yellow:"
  read STUFF
  pr p "Formatting cleared after read"
}

dver(){
  [[ -d "$1" ]]
}

fver(){
  [[ -f "$1" ]]
}

clean_up() {
  pr p
  pr f "Caught trap, pm poller terminated."
  exit
}

ping_engine(){
  pt_set_action "ping-engine"
  pr p "Pinging all hosts.."

  IFS=$'\n'
  ping_results=()
  for ping_result in $(fping -C 1 -q -f hosts.cfg 2>&1); do
    pt_set_action "ping_result"
    unset IFS
    set $ping_result
    current_host="$1"
    pt_set_host "$current_host"
    host_status="$3"
    if [[ "$host_status" != "-" ]]; then
      pr h "Host is ${GREEN}up${DEF}, delay" "$host_status ms"
    else
      pr p "Host is ${RED}down${DEF}"
    fi
    ping_results+=("$current_host:$host_status")
  done
  unset IFS
  pt_set_host ""
  pt_set_action "ping-engine"
  pr p "Writing to file"

  echo > "ping_engine.mutex"
  for ping_result in "${ping_results[@]}"; do
    echo "${ping_result}" >> "ping_engine.mutex"
  done
  mv "ping_engine.mutex" "ping_engine.export"
  pr p "Ping results written to file"
}

init(){
  pt_set_action "init"
  trap clean_up SIGINT SIGTERM
  fver "hosts.cfg" || pr f "No hosts.cfg found. Can not proceed without any hosts to poll"
  hash fping 2>/dev/null || pr f "Poller requres fping. Please install."
  longest_hostname="$(awk '{ if (length($0) > max) {max = length($0); maxline = $0} } END { print maxline }' hosts.cfg | wc -c)"
}


#main
pr p "Starting up..."
init

while true; do
  pt_set_action "main"
  pr p "Starting poll."
  ping_engine
  pt_set_action "main"
  pr p "Idle wait ${idle_wait}"
  sleep ${idle_wait}
done
