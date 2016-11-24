#!/bin/bash

#move this to seperate cfg
map_data_age_threshold=60
minimum_map_display_duration=10

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

set_platform(){
  if [[ "$(uname)" == *inux* ]]; then
    platform="Linux"
  elif [[ "$(uname)" == *arwin* ]] || [ "$(uname)" == *BSD* ]] ; then
    platform="BSD"
  else
    platform="Linux"
  fi
}

get_mod_date(){
  [[ "${platform}" == "Linux" ]] && date -d @$(stat -c %Y "$1")
  [[ "${platform}" == "BSD" ]] && date -r $(stat -f "%m" "$1")
}

gfx(){
  case "$1" in
    init)
      gfx_meta reset
      gfx_meta set_display_properties
      gfx_meta render_header
      ;;
    condreset)
      if [[ "$(tput cols)" -ne "$terminal_width" ]] || \
      [[ "$(tput lines)" -ne "$terminal_height" ]]; then
        clear
        echo "Resizing terminal.."
        sleep 0.1
        gfx init
        return 0
      else
        return 1
      fi
      ;;
    render_map_name)
      shift
      tput sc
      tput cup 0 "$current_map_prefix_length"
      tput ech $(( terminal_width - date_field_length - current_map_prefix_length ))
      echo "$1"
      tput rc
      ;;

    render_current_time)
      shift
      tput sc
      tput cup 0 "$date_field_time_startpos"
      echo -en "$(date)"
      tput rc
      ;;

      render_last_update)
        #debug
        #tput sc
        #tput cup 1 0 #"$date_field_time_startpos"
        #echo -n "TW: $terminal_width, TH: $terminal_height, "
        #echo -n "MVW: $map_viewer_width, MVH: $map_viewer_height, "
        #echo -n "MW:$map_width, MH:$map_height, "
        #echo -n "MTBE: $($map_to_big_error && echo 1 || echo 0), "
        #echo -n "LC: $line_counter, YMAP: $map_center_align_ycord, XMAP: $map_center_align_xcord, MLR: $map_lines_rendered     "
        #tput rc
        current_mod_date="$(get_mod_date ping_engine.export)"
        tput sc
        tput cup 1 "$date_field_time_startpos"
        [[ "$current_mod_date" != "$previous_mod_date" ]] && SECONDS=0 && previous_mod_date="$current_mod_date"
        [[ "$SECONDS" -gt "$map_data_age_threshold" ]] && echo -e "${YELLOW}${current_mod_date}$DEF" || echo -e "${current_mod_date}"
        tput rc
        ;;

      render_progress_indicator)
        shift
        tput sc
        if ((10<=$1 && $1<=19)); then
          tput cup 0 1 && echo -ne "p"
        elif ((20<=$1 && $1<=29)); then
          tput cup 0 1 && echo -ne "${MAGENTA}p${DEF}"
          tput cup 0 2 && echo -ne "m"
        elif ((30<=$1 && $1<=39)); then
          tput cup 0 2 && echo -ne "${MAGENTA}m${DEF}"
          tput cup 0 3 && echo -ne "-"
        elif ((40<=$1 && $1<=49)); then
          tput cup 0 3 && echo -ne "${MAGENTA}-${DEF}"
          tput cup 0 4 && echo -ne "v"
        elif ((50<=$1 && $1<=59)); then
          tput cup 0 4 && echo -ne "${MAGENTA}v${DEF}"
          tput cup 0 5 && echo -ne "i"
        elif ((60<=$1 && $1<=69)); then
          tput cup 0 5 && echo -ne "${MAGENTA}i${DEF}"
          tput cup 0 6 && echo -ne "e"
        elif ((70<=$1 && $1<=79)); then
          tput cup 0 6 && echo -ne "${MAGENTA}e${DEF}"
          tput cup 0 7 && echo -ne "w"
        elif ((80<=$1 && $1<=89)); then
          tput cup 0 7 && echo -ne "${MAGENTA}w${DEF}"
          tput cup 0 8 && echo -ne "e"
        elif ((90<=$1 && $1<=100)); then
          tput cup 0 8 && echo -ne "${MAGENTA}e${DEF}"
          tput cup 0 9 && echo -ne "r"
        elif [[ "$1" == "done" ]]; then
          tput cup 0 0 && echo -en "$current_map_prefix"
        fi
        tput rc
        ;;

    map_render)
      shift

      line_counter=0
      unset map_lines_rendered

      tput cup 2 0

      until [[ "$line_counter" == "$map_viewer_height" ]]; do
        if [[ "$line_counter" == "$map_center_align_ycord" ]]; then
          while read -r line; do
            tput el
            tput cuf "$map_center_align_xcord"
            echo -e "$line"
            (( map_lines_rendered++ ))
            if [[ "$map_lines_rendered" == "$map_height" ]]; then
              line_counter=$(( line_counter + map_lines_rendered ))
            fi
          done<"$1"
        else
          tput el
          (( line_counter++ ))
          if [[ $line_counter -ne "$map_viewer_height" ]]; then
            echo -e
          else
            echo -n
          fi
        fi

      done
      ;;


  esac
}

map(){
  case "$1" in
    process)
      map_process_starttime="$(date +%s)"
      shift 1
      current_map="$1"
      cp "$current_map" tmp/current.map
      map pre_flight_check tmp/current.map
      $map_to_big_error || map ansi_inject tmp/current.map
      map_process_endtime="$(date +%s)"
      map_process_duration="$(( map_process_endtime - map_process_starttime ))"

    ;;

    calculate_length)
      shift
      longest_line_length=0
      while read -r mapline; do
        current_length=${#mapline}
        [[ "$current_length" -gt "$longest_line_length" ]] && map_width="$current_length"
      done<"$1"
      ;;

    calculate_height)
      shift
      map_height="$(wc -l <"$1" | tr -d ' ')"
      ;;

    calculate_alignment)
      map_center_align_xcord="$(( (map_viewer_width - map_width) / 2 ))"
      map_center_align_ycord="$(( (map_viewer_height - map_height) / 2 ))"
      ;;

    pre_flight_check)
      shift
      map_to_big_error=false

      map calculate_length "$1"
      map calculate_height "$1"

      if [[ "$map_width" -gt "$map_viewer_width" ]] || [[ "$map_height" -gt "$map_viewer_height" ]]; then
        map_to_big_error=true
        echo "${YELLOW}$(basename "$current_map") does not fit the current terminal" >tmp/current.map
        echo "The terminal is ${terminal_width}x${terminal_height}, pm-viewer needs ${map_width}x${map_height} to display this map.${DEF}" >>tmp/current.map

        map calculate_length "$1"
        map calculate_height "$1"
      fi

      map calculate_alignment

      ;;

    ansi_inject)
      unset host_counter
      hosts_total="$(wc -l <ping_engine.export | tr -d ' ')"
      while read host; do
        (( host_counter++ ))
        gfx render_progress_indicator $(( host_counter * 100 / hosts_total ))
        if [[ -n "$host" ]]; then
          current_host=$(echo "$host" | cut -f1 -d,)
          host_status=$(echo "$host" | cut -f2 -d,)
          search_pattern="${current_host}"
          grep_result=$(grep -Eo ".{1,1}${current_host}.{1,1}" "$current_map")
          if [[ "$?" -eq 0 ]]; then
            IFS=$'\n'
            for match in $grep_result; do
              match_prechar="${match:0:1}"
              match_postchar="${match: -1}"
              if [[ "$match_prechar" != "-" ]] && [[ "$match_postchar" != "-" ]]; then
                if [[ "$host_status" != "-" ]]; then
                  sed -i.ansi -e "s/${match_prechar}${search_pattern}${match_postchar}/${match_prechar}\\${GREEN}${search_pattern}\\${DEF}${match_postchar}/g" tmp/current.map
                else
                  sed -i.ansi -e "s/${match_prechar}${search_pattern}${match_postchar}/${match_prechar}\\${RED}${search_pattern}\\${DEF}${match_postchar}/g" tmp/current.map
                fi
              fi
            done
            unset IFS
          fi

        fi
      done< <(sort -r --field-separator=',' ping_engine.export)
      gfx render_progress_indicator done
      ;;


  esac
}

gfx_meta(){
  case "$1" in
    reset)
      reset
      tput civis
      ;;
    set_display_properties)
      terminal_width="$(tput cols)"
      terminal_height="$(tput lines)"

      map_viewer_width="$terminal_width"
      map_viewer_height="$(( terminal_height - 2 ))"

      date_field_length="$(( date_prefix_length + date_length ))"
      date_field_startpos="$(( terminal_width - date_field_length ))"
      date_field_time_startpos="$(( terminal_width - date_length))"
      required_terminal_length="$(( map_info_prefix_length + date_field_time_length ))"
      ;;
    render_header)
      shift
      tput cup 0 0
      echo -en "$current_map_prefix"
      tput cup 0 "$date_field_startpos"
      echo -n "$date_prefix"
      tput cup 1 "$date_field_startpos"
      echo -n "$last_update_prefix"
      ;;
  esac
}

idle_wait(){
  $first_run && first_run=false && return 0
  idle_c="$1"
  until [[ "$idle_c" -eq 0 ]]; do
    sleep 0.5
    gfx render_current_time
    sleep 0.4
    (( idle_c-- ))
  done
}

init(){
  init_time="$(date)"
  first_run=true
  date_length="${#init_time}"

  trap clean_up SIGINT SIGTERM

  set_platform
  pmprompt="${DARKGRAY}[${MAGENTA}pm-viewer${DARKGRAY}]${DEF}"
  pmprompt_noformatting="[pm-viewer]"

  current_map_prefix="$pmprompt_noformatting @ $(hostname) - Map: "
  current_map_prefix_length="${#current_map_prefix}"
  current_map_prefix="$pmprompt @ $(hostname) - Map: "

  date_prefix="Current time: "
  date_prefix_length="${#date_prefix}"

  last_update_prefix="Last update:  "

  gfx init
  gfx render_map_name "(initializing)"
  gfx render_current_time
  gfx render_last_update

}

clean_up(){
  echo "Caught trap, aborting!"
  reset
  exit
}

#main
init

while true; do
  for map in maps/*; do
    map process "$map"
    idle_wait $(( minimum_map_display_duration - map_process_duration ))
    gfx condreset && map process "$map"
    gfx render_current_time
    gfx render_last_update
    gfx render_map_name "$map"
    gfx map_render tmp/current.map
  done
done

exit
