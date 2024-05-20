#!/bin/sh

set -e

# Check if the input video file and quality option are provided
if [ $# -lt 3 ]; then
    echo "Usage: $0 <input_video> <target_file_size_in_MB> <quality_option>"
    echo "Quality options: qhd, hd, fhd, 2k, 4k"
    exit 1
fi

input_video="$1"
target_file_size="$2" # in MB
quality_option="$3"
input_name=$(basename "$input_video")
input_dir=$(dirname "$input_video")
output_name="${input_dir}/${input_name%.*}_$2MB_${quality_option}.mp4"
max_size=$(($target_file_size*1024*1024))  # in bytes

echo "\nOutput: $output_name"
echo "Max Size: $max_size"
echo "Quality Option: $quality_option\n"

# Set bitrate based on quality option
case $quality_option in
    "qhd")
        bitrate="2M"
        ;;
    "hd")
        bitrate="4M"
        ;;
    "fhd")
        bitrate="8M"
        ;;
    "2k")
        bitrate="16M"
        ;;
    "4k")
        bitrate="30M"
        ;;
    *)
        echo "Invalid quality option. Available options: qhd, hd, fhd, 2k, 4k"
        exit 1
        ;;
esac

# Compress the video using ffmpeg
ffmpeg -hide_banner -i "$input_video" -c:v libx264 -b:v "$bitrate" -c:a copy -y "$output_name"

# Check the size of the compressed video
compressed_size=$(stat -f%z "$output_name")
echo "\n ====== Size: $compressed_size - Max Size: $max_size ======\n"

iteration=0

# If the compressed video exceeds the maximum size, reduce the resolution and compress again
while [ $compressed_size -gt $max_size ]; do

    mv "$output_name" /tmp/tmp.mp4
    iteration=$((iteration + 1))

    # Calculate the new resolution while maintaining the aspect ratio
    original_width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 /tmp/tmp.mp4)
    original_height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 /tmp/tmp.mp4)
    aspect_ratio=$(awk "BEGIN {printf \"%.2f\", $original_width/$original_height}")

    new_height=$((original_height - 20))
    new_width=$(awk "BEGIN {printf \"%.0f\", $new_height * $aspect_ratio}")

    ffmpeg -hide_banner -i /tmp/tmp.mp4 -vf "scale=$new_width:$new_height" -c:v libx264 -b:v "$bitrate" -crf 28 -c:a copy -y "$output_name"

    compressed_size=$(stat -f%z "$output_name")
    echo "\n ====== Iteration: $iteration - Size: $compressed_size - Max Size: $max_size ======\n"
done

echo "Video compression completed.\nOutput file: $output_name.\nSize: $compressed_size"
