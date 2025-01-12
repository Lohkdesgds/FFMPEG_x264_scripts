#!/bin/bash

# Needs: ffmpeg, imagemagick.

# TUNE HERE, FFMPEG
CQP=37
PRESET=slow
TUNE=hq
PROFILE=main
RC=constqp
SCALE=9 # 0..9
AUDIO_KBPS=128
AUDIO_MIX=false
# TUNE HERE, MAGICK
QUALITY=40
#TUNE HERE, BEHAVIOR OF MOVING FILES
MOVE_FILES_TO_TRASH_ONCE_CONVERTED=true


CURRENT_PATH=$PWD

TRASH_PATH=$PWD/.converted


declare -a FFMPEG_SUPPORTED=("mp4" "avi" "mov" "mkv" "flv" "webm" "mpeg" "asf" "ogv" "mxf")
declare -a MAGICK_SUPPORTED=("png" "jpg" "jpeg" "bmp" "gif" "ppm" "pgm" "tiff" "tga" "svg" "heic" "heif" "dng")

_IN=
FFMPEG_LIST=
MAGICK_LIST=


# Question VARIABLE min_val max_val
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


clear
printf "Starting shell application to convert your stuff here!\n"
printf "Your current path is: %s\n\n" $CURRENT_PATH

get_numerical_input "Do you want to scan current folder (1) or all files recursively (2)?" 1 2

pattern_ffmpeg=""
pattern_magick=""


if [[ $_IN == 1 ]]; then # local only, *. ... for ls

    for ext in "${FFMPEG_SUPPORTED[@]}"; do
        pattern_ffmpeg+="*.$ext "
    done
    for ext in "${MAGICK_SUPPORTED[@]}"; do
        pattern_magick+="*.$ext "
    done

    FFMPEG_LIST=$(ls $pattern_ffmpeg 2>/dev/null)
    MAGICK_LIST=$(ls $pattern_magick 2>/dev/null)

else # recursive, \*. ... for recursive find

    find_ffmpeg_files="find . -type f \\("
    for ext in "${FFMPEG_SUPPORTED[@]}"; do
        find_ffmpeg_files+=" -name '*.${ext}' -o"
    done

    find_ffmpeg_files="${find_ffmpeg_files% -o} \\)"

    find_magick_files="find . -type f \\("
    for ext in "${MAGICK_SUPPORTED[@]}"; do
        find_magick_files+=" -name '*.${ext}' -o"
    done

    # Remove the trailing -o and close the parentheses
    find_magick_files="${find_magick_files% -o} \\)"
    
    FFMPEG_LIST=$(eval "$find_ffmpeg_files")
    MAGICK_LIST=$(eval "$find_magick_files")
fi


printf "\nGot listings:\n\n"


FFMPEG_LIST_SIZE=0
MAGICK_LIST_SIZE=0

printf "FFMPEG (videos):\n"
for item in $FFMPEG_LIST; do echo "- $item"; FFMPEG_LIST_SIZE=$(($FFMPEG_LIST_SIZE + 1)); done;
printf "MAGICK (photos):\n"
for item in $MAGICK_LIST; do echo "- $item"; MAGICK_LIST_SIZE=$(($MAGICK_LIST_SIZE + 1)); done;


CMD_FFMPEG_BEG="-hide_banner -loglevel error -progress - -y -i"
CMD_FFMPEG_END="-vcodec hevc_nvenc -vsync 0 "
if [[ "$AUDIO_MIX" == "true" ]]; then 
    CMD_FFMPEG_END+="-vol 256 -af \"pan=stereo^|c0=0.5^*c2^+0.707^*c0^+0.707^*c4^+0.5^*c3^|c1=0.5^*c2^+0.707^*c1^+0.707^*c5^+0.5^*c3\" "
fi

if [[ "$SCALE" == "1" ]];   then CMD_FFMPEG_END+="-filter:v \"scale=in_w*0.5:in_h*0.5\" ";
elif [[ "$SCALE" == "2" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=in_w*0.333:in_h*0.333\" ";
elif [[ "$SCALE" == "3" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=in_w*0.25:in_h*0.25\" ";
elif [[ "$SCALE" == "4" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=in_w*0.166:in_h*0.166\" ";
elif [[ "$SCALE" == "5" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=in_w*0.125:in_h*0.125\" ";
elif [[ "$SCALE" == "6" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=h='if(gt(iw\,ih)\,2160\,-2)':w='if(gt(iw\,ih)\,-2\,2160)\" ";
elif [[ "$SCALE" == "7" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=h='if(gt(iw\,ih)\,1440\,-2)':w='if(gt(iw\,ih)\,-2\,1440)\" ";
elif [[ "$SCALE" == "8" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=h='if(gt(iw\,ih)\,1080\,-2)':w='if(gt(iw\,ih)\,-2\,1080)\" ";
elif [[ "$SCALE" == "9" ]]; then CMD_FFMPEG_END+="-filter:v \"scale=h='if(gt(iw\,ih)\,720\,-2)':w='if(gt(iw\,ih)\,-2\,720)\" ";
fi

CMD_FFMPEG_END+="-ab "$AUDIO_KBPS"k -preset "$PRESET" -tune "$TUNE" -profile "$PROFILE" -rc "$RC" -qp "$CQP" -rc-lookahead 40 -2pass 1 -gpu any -spatial-aq 1 -temporal-aq 1 -aq-strength 15 -multipass fullres"

get_numerical_input "Type 1 to start, or just Ctl C to quit" 1 1

printf "\nStarting with images first...\n\n"

counter=1
for item in $MAGICK_LIST; do
    printf "Working on $item ($counter of $MAGICK_LIST_SIZE)...\n"
    magick $item "-quality" $QUALITY"%" $item"_conv.jpg"
    
    if [[ "$MOVE_FILES_TO_TRASH_ONCE_CONVERTED" == "true" ]]; then
        DESTINATION="$TRASH_PATH/$(dirname "$item")"
        mkdir -p $DESTINATION
        mv $item $DESTINATION
    fi

    counter=$((counter + 1))
done

printf "\nWorking on videos now...\n\n"

counter=1
for item in $FFMPEG_LIST; do
    printf "Working on $item ($counter of $FFMPEG_LIST_SIZE)...\n"
    COMMAND="ffmpeg "$CMD_FFMPEG_BEG" "$item" "$CMD_FFMPEG_END" "$item"_conv.mp4"
    eval "$COMMAND" 2>/dev/null | \
        while read -r line; do
            # Extract fields of interest
            case $line in
                fps=*) fps="${line#fps=}" ;;
                total_size=*) total_size="${line#total_size=}" ;;
                bitrate=*) bitrate="${line#bitrate=}" ;;
                out_time=*) out_time="${line#out_time=}" ;;
                speed=*) speed="${line#speed=}" ;;
            esac

            # Print the desired output in a single line
            if [[ -n $fps || -n $total_size || -n $bitrate || -n $out_time || -n $speed ]]; then
                printf "\rFPS: %s | Size: %s bytes | Bitrate: %s | Time: %s | Speed: %s       " \
                "${fps:-N/A}" "${total_size:-N/A}" "${bitrate:-N/A}" "${out_time:-N/A}" "${speed:-N/A}"
            fi
        done
    
    if [[ "$MOVE_FILES_TO_TRASH_ONCE_CONVERTED" == "true" ]]; then
        DESTINATION="$TRASH_PATH/$(dirname "$item")"
        mkdir -p $DESTINATION
        mv $item $DESTINATION
    fi

    printf "\n"

    counter=$((counter + 1))
done

printf "Ended! Bye!\n\n"