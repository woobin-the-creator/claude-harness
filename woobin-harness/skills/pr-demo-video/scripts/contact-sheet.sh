#!/bin/sh

set -eu

usage() {
    echo "usage: contact-sheet.sh FIRST MIDDLE FINAL OUTPUT.png" >&2
}

fail() {
    echo "contact-sheet.sh: $*" >&2
    exit 1
}

if [ "$#" -ne 4 ]; then
    usage
    exit 2
fi

first=$1
middle=$2
final=$3
output=$4

for tool in ffmpeg ffprobe; do
    command -v "$tool" >/dev/null 2>&1 || fail "required command is unavailable: $tool"
done

filters=$(ffmpeg -hide_banner -filters 2>/dev/null) || fail "could not inspect ffmpeg filters"
case "$filters" in
    *" hstack "*) ;;
    *) fail "required ffmpeg hstack filter is unavailable" ;;
esac

for input in "$first" "$middle" "$final"; do
    [ -f "$input" ] || fail "input is not a regular file: $input"
    [ ! -L "$input" ] || fail "input must not be a symbolic link: $input"
done

if [ -e "$output" ] || [ -L "$output" ]; then
    fail "output already exists: $output"
fi

case $(basename "$output") in
    *.png) ;;
    *) fail "output must use the lowercase .png still-image extension" ;;
esac

output_parent=$(dirname "$output")
[ -d "$output_parent" ] || fail "output directory does not exist: $output_parent"
[ ! -L "$output_parent" ] || fail "output directory must not be a symbolic link: $output_parent"

probe_dimensions() {
    ffprobe \
        -v error \
        -select_streams v:0 \
        -show_entries stream=width,height \
        -of csv=p=0:s=x \
        -i "$1"
}

valid_dimensions() {
    case "$1" in
        ""|*[!0-9x]*|*x*x*) return 1 ;;
    esac
    width=${1%x*}
    height=${1#*x}
    [ "$width" -gt 0 ] 2>/dev/null && [ "$height" -gt 0 ] 2>/dev/null
}

first_dimensions=$(probe_dimensions "$first") || fail "ffprobe could not inspect input: $first"
valid_dimensions "$first_dimensions" || fail "input has invalid dimensions: $first"

for input in "$middle" "$final"; do
    dimensions=$(probe_dimensions "$input") || fail "ffprobe could not inspect input: $input"
    valid_dimensions "$dimensions" || fail "input has invalid dimensions: $input"
    [ "$dimensions" = "$first_dimensions" ] || fail "all three inputs must have equal dimensions"
done

input_width=${first_dimensions%x*}
input_height=${first_dimensions#*x}
expected_width=$((input_width * 3))
expected_dimensions=${expected_width}x${input_height}

temp_dir=
temp_output=
output_created=0
completed=0

cleanup() {
    if [ "$output_created" -eq 1 ] && [ "$completed" -ne 1 ]; then
        rm -f "$output"
    fi
    if [ -n "$temp_output" ] && { [ -e "$temp_output" ] || [ -L "$temp_output" ]; }; then
        rm -f "$temp_output"
    fi
    if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
        rmdir "$temp_dir" 2>/dev/null || :
    fi
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

temp_dir=$(mktemp -d "${output_parent}/.contact-sheet.XXXXXX") || fail "could not create task-scoped temporary directory"
temp_output=${temp_dir}/$(basename "$output")

ffmpeg \
    -nostdin \
    -hide_banner \
    -loglevel error \
    -n \
    -i "$first" \
    -i "$middle" \
    -i "$final" \
    -filter_complex "[0:v][1:v][2:v]hstack=inputs=3[contact]" \
    -map "[contact]" \
    -frames:v 1 \
    -c:v png \
    -f image2 \
    "$temp_output" || fail "ffmpeg could not create the contact sheet"

[ -f "$temp_output" ] || fail "ffmpeg did not create a regular output file"
[ ! -L "$temp_output" ] || fail "ffmpeg output must not be a symbolic link"
[ -s "$temp_output" ] || fail "ffmpeg created an empty contact sheet"

output_dimensions=$(probe_dimensions "$temp_output") || fail "ffprobe could not inspect the contact sheet"
[ "$output_dimensions" = "$expected_dimensions" ] || fail "contact sheet dimensions are not triple-width and single-height"

output_format=$(
    ffprobe \
        -v error \
        -show_entries format=format_name \
        -of default=noprint_wrappers=1:nokey=1 \
        -i "$temp_output"
) || fail "ffprobe could not inspect the contact-sheet format"
[ "$output_format" = "png_pipe" ] || fail "contact sheet must be a PNG still image"

frame_count=$(
    ffprobe \
        -v error \
        -select_streams v:0 \
        -count_frames \
        -show_entries stream=nb_read_frames \
        -of default=noprint_wrappers=1:nokey=1 \
        -i "$temp_output"
) || fail "ffprobe could not count contact-sheet frames"
[ "$frame_count" = "1" ] || fail "contact sheet must contain exactly one frame"

case "$output" in
    */*) output_link=$output ;;
    *) output_link=./$output ;;
esac
ln "$temp_output" "$output_link" || fail "refusing to overwrite output created during contact-sheet generation"
output_created=1

[ -f "$output" ] && [ ! -L "$output" ] && [ -s "$output" ] || fail "published contact sheet failed final file validation"
completed=1
printf '%s\n' "$output"
