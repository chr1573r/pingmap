#!/bin/bash

# Pretty colors for the terminal:
DEF="\x1b[0m"
GRAY="\x1b[37;0m"
LIGHTBLACK="\x1b[30;01m"
BLACK="\x1b[30;11m"
LIGHTBLUE="\x1b[34;01m"
BLUE="\x1b[34;11m"
LIGHTCYAN="\x1b[36;01m"
CYAN="\x1b[36;11m"
LIGHTGRAY="\x1b[37;01m"
WHITE="\x1b[37;11m"
LIGHTGREEN="\x1b[32;01m"
GREEN="\x1b[32;11m"
LIGHTPURPLE="\x1b[35;01m"
PURPLE="\x1b[35;11m"
LIGHTRED="\x1b[31;01m"
RED="\x1b[31;11m"
LIGHTYELLOW="\x1b[33;01m"
YELLOW="\x1b[33;11m"

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
    date_snooze 1
  done
  #echo "File changed!"
  export ping_results=$(cat ping_engine.export)
}

ansi_inject(){
  #IFS=$'\n'
  cp "$1" tmp/current.map
  while read host; do
    if [[ -n "$host" ]]; then
      current_host=$(echo "$host" | cut -f1 -d:)
      host_status=$(echo "$host" | cut -f1 -d:)
      if [[ "$host_status" != "-" ]]; then
        sed -i.ansi -e "s/${current_host}/\\${GREEN}${current_host}\\${DEF}/g" tmp/current.map
      else
        sed -i.ansi -e "s/${current_host}/\\${RED}${current_host}\\${DEF}/g" tmp/current.map
      fi
    fi

  done<"ping_engine.export"
  #unset IFS
}

calc_dimensions(){
  unset longest_line_length

  # calculate longest line. Avoiding wc -L for compatibilty
  while read -r mapline; do
    current_length=${#mapline}
    [[ "$current_length" -gt "$longest_line_length" ]] && longest_line_length=$current_length
  done<"$1"

  term_width=$(tput cols)
  term_height=$(tput lines)

  map_width="$longest_line_length"
  map_height="$(wc -l <"$1" | tr -d ' ')"

  top_padding="2"
  bottom_padding="1"

  map_center_align_xcord="$(( (term_width - map_width) / 2 ))"
  map_center_align_ycord="$(( (term_height + top_padding - map_height) / 2 ))"
  date_field_length=$(( 29 + 14 ))
  date_xcord=$(( term_width - date_field_length ))
  #echo "map_width $map_width"
  #echo "map_height $map_height"
  #echo "map_center_align_xcord $map_center_align_xcord"
  #echo "map_center_align_ycord $map_center_align_ycord"
  #sleep 5
}

render_header(){
  tput cup 0 0
  tput ech "$((term_width - date_field_length))"
  echo "$header $map ${map_width}x${map_height}"
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

  while read -r line; do
    tput cuf "$map_center_align_xcord"
    tput el1
    tput el
    echo -e "$line"
    (( ypos++ ))
  done<"$1"

  (( ypos-- ))

  until [[ "$ypos" -eq "$(( term_height - bottom_padding ))" ]]; do
    tput cup $ypos 0
    tput el
    (( ypos++ ))
  done

  unset IFS
}

date_snooze(){
  tput sc
  timer=$1
  while [[ "$timer" -ne 0 ]]; do
    tput cup 0 $date_xcord
    echo -e "Current time: $(date)"
    tput cup 1 $date_xcord
    echo -e "Map data age: $(mod_date ping_engine.export)"
    (( timer-- ))
    sleep 0.9
  done

}

clean_up(){
  echo "Caught trap, aborting!"
  reset
  exit
}


#init
trap clean_up SIGINT SIGTERM
reset
tput civis
header="pm-viewer running on $(hostname) - Map: "

#main
while true; do
  for map in maps/*; do
    calc_dimensions "$map"
    ansi_inject "$map"
    render_header
    render_map "tmp/current.map"
    date_snooze 5
  done
  #refresh
done
