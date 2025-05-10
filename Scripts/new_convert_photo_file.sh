#!/bin/bash

set_if_undef() {
    local varname="$1"
    local default_value="$2"

    if [ -z "${!varname+x}" ]; then
        eval "$varname=$default_value";
    fi
}

# === TUNE HERE, MAGICK === #
set_if_undef QUALITY 40
# === ENDOF MAGICK CONF === #

if [[ -z $1 ]]; then
  printf "Parameter FILE missing. Call it <script> <FILE>\n";
  exit 1;
fi

FP="$1"

COMMAND=(
    magick
    "$FP"
    -quality
    "$QUALITY%"
    "$FP"_conv.jpg
)

echo -ne "[--------------------------------------------------] 0.00% - $FP @ Q=$QUALITY%   \r"

"${COMMAND[@]}" 2>/dev/null

echo -e  "[##################################################] 100.00% - $FP @ Q=$QUALITY%   "
