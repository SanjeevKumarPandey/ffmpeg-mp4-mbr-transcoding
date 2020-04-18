#!/usr/bin/env bash

# !!IMPORTANT!!:For Demo/Sample Purpose Only; (c) Sanjeev Pandey 2020: Works Best In LINUX server!!
# __description__: Script to transcode Mp4 to MBR Mp4
# __version__: 0.11.2
# __author__: Sanjeev Pandey

set -e

# Usage bash <script> SOURCE_FILE [OUTPUT_NAME]
[[ ! "${1}" ]] && echo "Usage: create-vod-hls.sh SOURCE_FILE [OUTPUT_NAME]" && exit 1

# comment/add lines here to control which renditions would be created
renditions=(
# resolution  bitrate  audio-rate
 "426x240    400k    64k"
  # "640x360    800k     96k"
  # "842x480    1400k    128k"
  # "1280x720   2800k    128k"
  # "1920x1080  5000k    192k"
)

max_bitrate_ratio=1.07          # maximum accepted bitrate fluctuations
rate_monitor_buffer_ratio=0.5   # maximum buffer size between bitrate conformance checks

source="${1}"
target="${2}"
if [[ ! "${target}" ]]; then
  target="${source##*/}" # leave only last component of path
  target="$(echo -e "${target}" | tr -d '[:space:]')" # remove all spaces from string
  target="${target%.*}"  # strip extension
fi
mkdir -p ${target}

# static parameters that are similar for all renditions
static_params="-c:a aac -ar 48000 -c:v h264 -profile:v main -crf 20 -sc_threshold 0"

# misc params
misc_params="-hide_banner -y"

cmd=""
for rendition in "${renditions[@]}"; do
  # drop extraneous spaces
  rendition="${rendition/[[:space:]]+/ }"

  # rendition fields
  resolution="$(echo ${rendition} | cut -d ' ' -f 1)"
  bitrate="$(echo ${rendition} | cut -d ' ' -f 2)"
  audiorate="$(echo ${rendition} | cut -d ' ' -f 3)"

  # calculated fields
  width="$(echo ${resolution} | grep -oE '^[[:digit:]]+')"
  height="$(echo ${resolution} | grep -oE '[[:digit:]]+$')"
  maxrate=`awk -v a="${bitrate}" -v b="${max_bitrate_ratio}" 'BEGIN {print a * b}'`
  bufsize=`awk -v c="${bitrate}" -v d="${rate_monitor_buffer_ratio}" 'BEGIN {print c * d}'`
  # echo "MAX: ${maxrate}, BUFF: ${bufsize}"
  echo "x264 is checking for quality every "`awk -v e="${maxrate}" -v f="${bufsize}" 'BEGIN {print e / f}'`" sec"
  bandwidth="$(echo ${bitrate} | grep -oE '[[:digit:]]+')000"
  name="${height}p"
  
  # scale and pad by 1 pixel if either height or width is odd
  cmd+=" ${static_params} -vf scale=w=${width}:h=${height}:force_original_aspect_ratio=decrease,pad='iw+mod(iw\,2)':'ih+mod(ih\,2)'"
  cmd+=" -b:v ${bitrate} -maxrate ${maxrate%.*}k -bufsize ${bufsize%.*}k -b:a ${audiorate}"
  cmd+=" -f mp4 ${target}/${name}.mp4"

done

# start conversion
echo -e "Executing command:\nffmpeg ${misc_params} -i ${source} ${cmd}"
ffmpeg ${misc_params} -i "${source}" ${cmd}

# create video JPG thumbnail/ banner
ffmpeg -i "${source}" -vframes 1 -an -s 400x222 -ss 30 ${target}/thumbnail.jpg

# create a mosaic of thumbnails for 'thumbnail seeking'
ffmpeg -i "${source}" -filter_complex "select='not(mod(n,120))',scale=128:72,tile=11x11" -frames:v 1 -qscale:v 3 -an ${target}/mosaic.jpg

echo "Done - encoded Mp4 is at ${target}/"