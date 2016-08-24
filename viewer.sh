#!/bin/bash

# Pretty colors for the terminal:
DEF="\x1b[0m"
GRAY="\x1b[37;0m"
LIGHTBLACK="\x1b[30;01m"
DARKGRAY="\x1b[30;11m"
LIGHTBLUE="\x1b[34;01m"
BLUE="\x1b[34;11m"
LIGHTCYAN="\x1b[36;01m"
CYAN="\x1b[36;11m"
LIGHTGRAY="\x1b[37;01m"
WHITE="\x1b[37;11m"
LIGHTGREEN="\x1b[32;01m"
GREEN="\x1b[32;11m"
LIGHTMAGENTA="\x1b[35;01m"
MAGENTA="\x1b[35;11m"
LIGHTRED="\x1b[31;01m"
RED="\x1b[31;11m"
LIGHTYELLOW="\x1b[33;01m"
YELLOW="\x1b[33;11m"

#move this into seperate cfg file
map_data_age_threshold=60

#todo
#map term size validations
#multiview for maps
#fix highlighting for hostnames containing hyphens etc
#group/alias support

#Platform specific compatibilty

if [[ "$(uname)" == *inux* ]]; then
  platform="Linux"
elif [[ "$(uname)" == *arwin* ]]; then
  platform="BSD"
else
  platform="Linux"
fi

# checksum related

hash md5 2>/dev/null && md5bin="md5"
hash md5sum 2>/dev/null && md5bin="md5sum"
[[ -z "$md5bin" ]] && utpf "md5/md5sum binary not found, please install."

sumbin(){
	[[ $md5bin == "md5sum" ]] &&	echo -n $(md5sum "$1" | cut -c -32) || echo -n $(md5 -q "$1")
}

mod_date(){
  [[ "${platform}" == "Linux" ]] && date -d @$(stat -c %Y "$1")
  [[ "${platform}" == "BSD" ]] && date -r $(stat -f "%m" "$1")
}

refresh(){
  old_sum=$(sumbin ping_engine.export)
  #echo "Waiting for file change"
  until [[ $(sumbin ping_engine.export) != "${old_sum}" ]]; do
    sleep 1
    refresh_dates
  done
  #echo "File changed!"
  export ping_results=$(cat ping_engine.export)
}

ansi_inject(){
  #IFS=$'\n'
  if [[ "$term_width" -lt "$map_width" || "$term_height" -lt "$(( map_height + top_padding ))" ]]; then
    echo "${YELLOW}$(basename "$map") does not fit the current terminal" >tmp/current.map
    echo "The terminal is ${term_width}x${term_height}, pm-viewer needs ${map_width}x$(( map_height + top_padding )) to display this map.${DEF}" >>tmp/current.map
    calc_dimensions tmp/current.map && refresh_dates
  else
    cp "$1" tmp/current.map
    while read host; do
      if [[ -n "$host" ]]; then
        current_host=$(echo "$host" | cut -f1 -d:)
        host_status=$(echo "$host" | cut -f2 -d:)
        refresh_dates
        if [[ "$host_status" != "-" ]]; then
          sed -i.ansi -e "s/${current_host}/\\${GREEN}${current_host}\\${DEF}/g" tmp/current.map
        else
          sed -i.ansi -e "s/${current_host}/\\${RED}${current_host}\\${DEF}/g" tmp/current.map
        fi
        refresh_dates
      fi
    done<"ping_engine.export"
  fi
  #unset IFS
}

calc_dimensions(){
  longest_line_length=0

  # calculate longest line. Avoiding wc -L for compatibilty
  while read -r mapline; do
    current_length=${#mapline}
    [[ "$current_length" -gt "$longest_line_length" ]] && longest_line_length=$current_length
  done<"$1"

  term_width=$(tput cols)
  term_height=$(tput lines)
  date_field_length=$(( 29 + 14 ))
  date_xcord=$(( term_width - date_field_length ))
  refresh_dates

  [[ "$term_width" -ne "$previous_term_width" ]] || [[ "$term_height" -ne "$previous_term_height" ]] && echo -e "$pmprompt Terminal changed size, adjusting.." && reset && tput civis
  previous_term_width=$term_width
  previous_term_height=$term_height

  map_width="$longest_line_length"
  map_height="$(wc -l <"$1" | tr -d ' ')"

  top_padding="2"
  bottom_padding="0"

  map_center_align_xcord="$(( (term_width - map_width) / 2 ))"
  map_center_align_ycord="$(( (term_height + top_padding - map_height) / 2 ))"

  #echo "map_width $map_width"
  #echo "map_height $map_height"
  #echo "map_center_align_xcord $map_center_align_xcord"
  #echo "map_center_align_ycord $map_center_align_ycord"
  #sleep 5
}

render_header(){
  tput cup 0 0
  tput ech "$((term_width - date_field_length))"
  echo -e "$header $map ${map_width}x${map_height}"
}

render_map(){
  IFS=$'\n'
  tput cup $top_padding 0
  ypos=$top_padding

  until [[ "$ypos" -eq "$map_center_align_ycord" ]]; do
    tput cup $ypos 0
    tput el
    (( ypos++ ))
  done
  refresh_dates
  unset line_c
  while read -r line; do
    (( line_c++ ))
    tput cup $ypos "$map_center_align_xcord"
    tput el1
    tput el
    [[ "$line_c" -eq "$map_height" ]] && echo -e -n "$line" || echo -e "$line" && (( ypos++ ))
  done<"$1"

  until [[ "$ypos" -eq "$(( term_height - bottom_padding ))" ]]; do
    tput cup $ypos 0
    tput el
    (( ypos++ ))
  done

  unset IFS
}

refresh_dates(){
  tput sc
  tput cup 0 $date_xcord
  echo -e "Current time: $(date)"
  tput cup 1 $date_xcord
  current_mod_date="$(mod_date ping_engine.export)"
  [[ "$current_mod_date" != "$previous_mod_date" ]] && SECONDS=0 && previous_mod_date="$current_mod_date"
  [[ "$SECONDS" -gt "$map_data_age_threshold" ]] && echo -e "${YELLOW}Last update:  ${current_mod_date}$DEF" || echo -e "Last update:  ${current_mod_date}"

  tput rc
}

clean_up(){
  echo "Caught trap, aborting!"
  reset
  exit
}

idle_wait(){
  idle_c="$1"
  until [[ "$idle_c" -eq 0 ]]; do
    sleep 0.5
    refresh_dates
    sleep 0.4
    (( idle_c-- ))
  done
}
#init
trap clean_up SIGINT SIGTERM
reset
tput civis
pmprompt="${DARKGRAY}[${MAGENTA}pm-viewer${DARKGRAY}]${DEF}"
header="$pmprompt running on $(hostname) - Map:"
echo -e  "$pmprompt init.."
previous_term_width=$(tput cols)
previous_term_height=$(tput lines)

#main
while true; do
  for map in maps/*; do
    calc_dimensions "$map" && refresh_dates
    ansi_inject "$map" && refresh_dates
    render_header && refresh_dates
    render_map "tmp/current.map" && refresh_dates
    idle_wait 5
  done
  #refresh
done
