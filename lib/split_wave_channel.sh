#!/usr/bin/env bash

# Usage: bash convert1.sh $(pwd)

function getdir(){
#     find $1 -type f find -type f ./ -name "*.oga" -o -name "*.mp3"
    find $1 -type f find -type f -regex ".*\.oga\|.*\.mp3" | while read line
    do
        base_name=$(basename "${1}")
        dir_name=$(dirname "${1}")
        sox  "$1" -r 8000  "${dir_name}/${base_name%.*}_l.wav" remix 1
        sox  "$1" -r 8000  "${dir_name}/${base_name%.*}_r.wav" remix 2
    done
}
root_dir="$1"
getdir $root_dir

#function echofile(){
#        if [[  $1 =~ \.oga$ ]] || [[  $1 =~ \.mp3$ ]] ;then
#                echo "$1"
#                base_name=$(basename "${1}")
#                dir_name=$(dirname "${1}")
##                 echo "${dir_name}/${base_name%.*}"
#                ffmpeg -y -i "$1" -f wav "${dir_name}/${base_name%.*}.wav"
#        fi
#}
#
#function getdir(){
#    for item in `ls $1`
#    do
#        filename=$1"/"$item
#        if [[ -d $filename ]] then
##             echo $filename
#            getdir $filename
#        else
#            echofile $filename
#        fi
#    done
#}
#root_dir="$1"
#getdir $root_dir