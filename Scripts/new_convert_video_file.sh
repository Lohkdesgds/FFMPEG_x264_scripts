#!/bin/bash

set_if_undef() {
    local varname="$1"
    local default_value="$2"

    if [ -z "${!varname+x}" ]; then
        eval "$varname=$default_value";
    fi
}
line_status() {
    local msg="$*"
    echo -ne "\r$msg$(tput el)"
}
get_duration_ms() {
    ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$1" | awk '{printf "%d\n", $1 * 1000}'
}
print_progress() {
    local duration=$1
    local filename=$2
    local cqp_ref=$3
    local scale_ref=$4
    local last_percent=-1
    local line

    while read -r line; do
        if [[ $line == out_time_us=* ]]; then
            local out_time_us=${line#out_time_us=}
    	    if [[ "$out_time_us" == "N/A" ]]; then out_time_us=$duration; fi;
	    local percent=$((out_time_us / duration / 10))
	    local percent_dot=$(((out_time_us * 100 / duration) % 1000))

            if [[ $percent -ne $last_percent ]]; then
                local bar_size=50
                local done=$((percent * bar_size / 100))
                local left=$((bar_size - done))
                local bar=""
                if [[ $done -gt 0 ]]; then
                    bar+=$(printf "%0.s#" $(seq 1 $done))
                fi
                if [[ $done -lt $bar_size ]]; then
                    bar+=$(printf "%0.s-" $(seq 1 $left))
                fi
                echo -ne "[$bar] $percent.$percent_dot% - $filename @ CQP=$cqp_ref SC=$scale_ref   \r"
                last_percent=$percent
            fi
        fi
    done
    echo -e "[##################################################] 100.00% - $filename @ CQP=$cqp_ref SC=$scale_ref    "
}

# === TUNE HERE, FFMPEG === #
## 24 for EDIT
set_if_undef CQP 37
set_if_undef PRESET slow
set_if_undef TUNE hq
set_if_undef PROFILE main
set_if_undef RC constqp
set_if_undef SCALE 9 ## 0..9
set_if_undef LOOKAHEAD 40
set_if_undef AUDIO_KBPS 128
set_if_undef AUDIO_MIX false
# === ENDOF FFMPEG CONF === #

if [[ -z $1 ]]; then
  printf "Parameter FILE missing. Call it <script> <FILE>\n";
  exit 1;
fi

FP="$1"

CURRENT_PATH=$PWD
TRASH_PATH=$PWD/.converted

# === PREPARATION OF VARIABLES === #

CMD_FFMPEG_BEG=(-hide_banner -loglevel error -progress - -y -i)
CMD_FFMPEG_END=(-vcodec hevc_nvenc -vsync 0)

if [[ "$AUDIO_MIX" == "true" ]]; then
    CMD_FFMPEG_END+=(
        -vol 256
        -af "pan=stereo|c0=0.5*c2+0.707*c0+0.707*c4+0.5*c3|c1=0.5*c2+0.707*c1+0.707*c5+0.5*c3"
    )
fi

case "$SCALE" in
    1) CMD_FFMPEG_END+=(-filter:v "scale=in_w*0.5:in_h*0.5") ;;
    2) CMD_FFMPEG_END+=(-filter:v "scale=in_w*0.333:in_h*0.333") ;;
    3) CMD_FFMPEG_END+=(-filter:v "scale=in_w*0.25:in_h*0.25") ;;
    4) CMD_FFMPEG_END+=(-filter:v "scale=in_w*0.166:in_h*0.166") ;;
    5) CMD_FFMPEG_END+=(-filter:v "scale=in_w*0.125:in_h*0.125") ;;
    6) CMD_FFMPEG_END+=(-filter:v "scale=h='if(gt(iw\,ih)\,2160\,-2)':w='if(gt(iw\,ih)\,-2\,2160)'") ;;
    7) CMD_FFMPEG_END+=(-filter:v "scale=h='if(gt(iw\,ih)\,1440\,-2)':w='if(gt(iw\,ih)\,-2\,1440)'") ;;
    8) CMD_FFMPEG_END+=(-filter:v "scale=h='if(gt(iw\,ih)\,1080\,-2)':w='if(gt(iw\,ih)\,-2\,1080)'") ;;
    9) CMD_FFMPEG_END+=(-filter:v "scale=h='if(gt(iw\,ih)\,720\,-2)':w='if(gt(iw\,ih)\,-2\,720)'") ;;
    16) CMD_FFMPEG_END+=(-filter:v "crop=h='if(gt(iw\,ih)\,2160\,3840)':w='if(gt(iw\,ih)\,3840\,2160)'") ;;
    17) CMD_FFMPEG_END+=(-filter:v "crop=h='if(gt(iw\,ih)\,1440\,2560)':w='if(gt(iw\,ih)\,2560\,1440)'") ;;
    18) CMD_FFMPEG_END+=(-filter:v "crop=h='if(gt(iw\,ih)\,1080\,1920)':w='if(gt(iw\,ih)\,1920\,1080)'") ;;
    19) CMD_FFMPEG_END+=(-filter:v "crop=h='if(gt(iw\,ih)\,720\,1280)':w='if(gt(iw\,ih)\,1280\,720)'") ;;
esac

CMD_FFMPEG_END+=(
    -ab "${AUDIO_KBPS}k"
    -preset "$PRESET"
    -tune "$TUNE"
    -profile "$PROFILE"
    -rc "$RC"
    -qp "$CQP"
    -rc-lookahead "$LOOKAHEAD"
    -2pass 1
    -gpu any
    -spatial-aq 1
    -temporal-aq 1
    -aq-strength 15
    -multipass fullres
)

COMMAND=(ffmpeg "${CMD_FFMPEG_BEG[@]}" "$FP" "${CMD_FFMPEG_END[@]}" "$FP"_conv.mp4)

DURATION_MS=$(get_duration_ms "$FP")

"${COMMAND[@]}" 2>/dev/null | print_progress "$DURATION_MS" "$FP" "$CQP" "$SCALE"
