#!/bin/bash

SCRIPTROOT=$(dirname "$(realpath "$0")") # path like /usr/path

set_export_if_undef() {
    local varname="$1"
    local default_value="$2"

    if [ -z "${!varname+x}" ]; then
        eval "export $varname=$default_value";
    fi
}
get_from_user() {
  INPUT=
  read -e -p "> " INPUT
}
check_number_opt_valid() {
  local test="$1"
  if [[ ! $test =~ ^[0-9]+$ ]]; then
    printf "Invalid input ($test). Try again\n";
    exit;
  elif [[ $test -lt 1 || $test -gt 4 ]]; then
    printf "Out of range. Try again\n";
    exit;
  fi
}

if [[ "$#" -gt 1 ]]; then
  OPTION="$1"

  check_number_opt_valid "$OPTION"

  declare -a args=("${@:2}")
  args_len="${#args[@]}"

  if [[ $OPTION -eq 1 ]];   then
    $SCRIPTROOT/Scripts/convert_all_media_for_backup.sh;
  elif [[ $OPTION -eq 2 ]]; then

    set_export_if_undef CQP 21
    set_export_if_undef PRESET slow
    set_export_if_undef AUDIO_KBPS 320
    set_export_if_undef SCALE 0
    set_export_if_undef MOVE_FILES_TO_TRASH_ONCE_CONVERTED false

    for item in "${args[@]}"; do
      $SCRIPTROOT/Scripts/new_convert_video_file.sh "$item"
    done
  elif [[ $OPTION -eq 3 ]]; then
    $SCRIPTROOT/Scripts/connect_ssh_minecraft.sh;
  elif [[ $OPTION -eq 4 ]]; then
    if [[ "$args_len" -eq 2 ]]; then
      $SCRIPTROOT/Scripts/connect_ssh_minecraft_transfer_file_to.sh "${args[@]}";
    else
      printf "Invalid number of args for command. Expected opt + file + path\n"
    fi
  fi

else
  if [[ -z $OPTION ]]; then
    printf "Welcome to Lohk's generic script launcher. Choose an option to call: (You can also call it directly with [<script> <option>] <args...>)\n"
    printf "1 => Script to convert files\n"
    printf "2 => Script to convert a single file to HEVC (YouTube)\n"
    printf "3 => Script to connect to Minecraft VPN shell via SSH\n"
    printf "4 => Script to connect and transfer files to Minecraft VPN via ssh\n"
    get_from_user;
    OPTION=$INPUT
    printf "You've selected option %d\n" $OPTION;
  fi

  check_number_opt_valid "$OPTION"

  if [[ $OPTION -eq 1 ]];   then
    $SCRIPTROOT/Scripts/convert_all_media_for_backup.sh;
  elif [[ $OPTION -eq 2 ]]; then
    printf "Type the video file name now:\n"
    get_from_user;

    export CQP=21
    export PRESET=slow
    export AUDIO_KBPS=320
    export SCALE=0
    export MOVE_FILES_TO_TRASH_ONCE_CONVERTED=false

    $SCRIPTROOT/Scripts/new_convert_video_file.sh "$INPUT";
  elif [[ $OPTION -eq 3 ]]; then
    $SCRIPTROOT/Scripts/connect_ssh_minecraft.sh;
  elif [[ $OPTION -eq 4 ]]; then
    printf "Type the file to send:\n"
    get_from_user;
    FROM_FILE="$INPUT"

    printf "Type to which folder to save on:"
    get_from_user;
    TO_PATH="$INPUT"

    $SCRIPTROOT/Scripts/connect_ssh_minecraft_transfer_file_to.sh "$FROM_FILE" "$TO_PATH";
  fi;
fi;
