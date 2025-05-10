#!/bin/bash

SCRIPTROOT=$(dirname "$(realpath "$0")") # path like /usr/path

get_numerical_input()
{
    re='^[0-9]+$' # regex to get number
    text="$1"

    min_val=$2
    max_val=$3

    _IN=

    while [[ $_IN < $min_val || $_IN > $max_val ]]; do
        if [[ -n $_IN ]]; then printf "Try again. Invalid number, not a number or not in range.\n"; fi
        _IN=
        while ! [[ $_IN =~ $re ]]; do
            printf "%s\n" "$text"
            read -p "> " _IN
        done
    done
}

declare -a FFMPEG_SUPPORTED=("mp4" "avi" "mov" "mkv" "flv" "webm" "mpeg" "asf" "ogv" "mxf")
declare -a MAGICK_SUPPORTED=("png" "jpg" "jpeg" "bmp" "gif" "ppm" "pgm" "tiff" "tga" "svg" "heic" "heif" "dng")

printf "Starting script...\n"

#CURRENT_PATH=$PWD
TRASH_PATH=$PWD/.converted

get_numerical_input "Do you want to scan current folder (1) or all files recursively (2)?" 1 2

pattern_ffmpeg=""
pattern_magick=""

FFMPEG_LIST=()
MAGICK_LIST=()

if [[ $_IN == 1 ]]; then
    # Local directory only
    for ext in "${FFMPEG_SUPPORTED[@]}"; do
        for file in *."$ext"; do
            [[ -e "$file" ]] && FFMPEG_LIST+=("$file")
        done
    done

    for ext in "${MAGICK_SUPPORTED[@]}"; do
        for file in *."$ext"; do
            [[ -e "$file" ]] && MAGICK_LIST+=("$file")
        done
    done

else
    # Recursive using find
    for ext in "${FFMPEG_SUPPORTED[@]}"; do
        while IFS= read -r -d '' file; do
            FFMPEG_LIST+=("$file")
        done < <(find . -type f -iname "*.${ext}" -print0)
    done

    for ext in "${MAGICK_SUPPORTED[@]}"; do
        while IFS= read -r -d '' file; do
            MAGICK_LIST+=("$file")
        done < <(find . -type f -iname "*.${ext}" -print0)
    done
fi



printf "\nGot listings:\n\n"

FFMPEG_LEN="${#FFMPEG_LIST[@]}"
MAGICK_LEN="${#MAGICK_LIST[@]}"

printf "FFMPEG (videos) amout: $FFMPEG_LEN\n"
printf "MAGICK (photos) amount: $MAGICK_LEN\n"

get_numerical_input "Type 1 to start, or just Ctl C to quit" 1 1

mkdir -p "$TRASH_PATH"

printf "\nStarting with images first...\n\n"

counter=1
for item in "${MAGICK_LIST[@]}"; do
  printf "Working on $item ($counter of $MAGICK_LEN)...\n"

  $SCRIPTROOT/new_convert_photo_file.sh "$item"
  mv "$item" "$TRASH_PATH/"

  counter=$((counter + 1))
done

printf "\nWorking on videos now...\n\n"

counter=1
for item in "${FFMPEG_LIST[@]}"; do
  printf "Working on $item ($counter of $FFMPEG_LEN)...\n"

  $SCRIPTROOT/new_convert_video_file.sh "$item"
  mv "$item" "$TRASH_PATH/"

  counter=$((counter + 1))
done

