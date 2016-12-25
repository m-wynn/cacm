#!/bin/bash

# shellcheck source=bash-concurrent/concurrent.lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/bash-concurrent/concurrent.lib.sh"
dest=""
file=""
verbose=0
songlist=()
tmpfile="$(mktemp)"

LOSSLESS_TYPES=(ape flac wav wv)

show_help() {
    cat << EOF
    Usage: ${0##*/} [-hv] -f FILE -d DESTINATION
        -h              display this help and exit
        -v              verbosity -- add this multiple times for more verbosity
        -f FILE         Use FILE, which contains a list of folders, as a list
                        of music to be converted
        -d DESTINATION  Use DESTINATION as the folder to put the converted
                        music
EOF
}

expand_path() {
    # http://stackoverflow.com/questions/3963716/how-to-manually-expand-a-special-variable-ex-tilde-in-bash/29310477#29310477
    local path
    local -a pathElements resultPathElements
    IFS=':' read -r -a pathElements <<<"$1"
    : "${pathElements[@]}"
    for path in "${pathElements[@]}"; do
        : "$path"
        case $path in
            "~+"/*)
                path=$PWD/${path#"~+/"}
                ;;
            "~-"/*)
                path=$OLDPWD/${path#"~-/"}
                ;;
            "~"/*)
                path=$HOME/${path#"~/"}
                ;;
            "~"*)
                username=${path%%/*}
                username=${username#"~"}
                IFS=: read _ _ _ _ _ homedir _ < <(getent passwd "$username")
                if [[ $path = */* ]]; then
                    path=${homedir}/${path#*/}
                else
                    path=$homedir
                fi
                ;;
        esac
        resultPathElements+=( "$path" )
    done
    local result
    printf -v result '%s:' "${resultPathElements[@]}"
    printf '%s\n' "${result%:}"
}

should_process() {
    src=${1}
    dest=${2}

    # See if it exists newer on the remote
    if [[ -f $dest ]] && [[ $dest -nt $src ]]; then
        return 0
    fi

    # See if it has been converted on the remote
    converted="${dest%.*}.opus"
    if [[ -f $converted ]] && [[ $converted -nt $src ]]; then
        return 0
    fi

    echo "- \"Processing $src\" process_song \"$src\" \"$dest\"" >> $tmpfile
}

in_array() {
  local e
  for e in "${@:2}"; do
      [[ "$e" == "$1" ]] && return 0
  done
  return 1
}

process_song() {
    local src="$1"
    local destination="$2"
    local extension="${src##*.}"
    local convert=0

    if [[ $extension == m4a ]]; then
        codec="$(ffprobe -v quiet -select_streams a:0 -show_entries stream=codec_name -print_format csv=p=0 "$src")"
        if [[ $codec != aac ]]; then
            convert=1
        fi
    elif in_array "$extension" "${LOSSLESS_TYPES[@]}"; then
        convert=1
    fi

    if [[ $convert == 1 ]]; then
        local converted="${destination%.*}.opus"
        mkdir -p -- "${converted%/*}"
        opusenc --comp 10 --bitrate 320 "$src" "$converted" || exit 1
    else
        mkdir -p -- "${destination%/*}"
        cp -- "$src" "$destination" || exit 1
    fi
}

copy_and_convert() {
    printf "Scanning Files\n"
    CONCURRENT_LIMIT="$(nproc --all)"
    file="$1"
    destination="$2"
    local args=()

    while read -r line; do
        [[ $line = \#* ]] && continue
        eval x=($line)              # This is the only way I can split this if there's an escaped quotation mark
        src="${x[0]}"
        destfolder="${x[1]}"
        folder=$(expand_path "$src")
        if [[ ! -d "$folder" ]]; then
            printf >&2 "'%s' is not a directory" "$folder"
            exit 1
        fi
        echo -ne "\e[1A";
        echo -e "\e[0K\r Scanning $folder for music files"
        cd "$folder" || exit 1
        for song in **/*; do
            # Make sure it's an audio file
            if [[ "$(mimetype -b "${folder}/${song}")" =~ ^audio/.* ]]; then
                allsongs+=(- "Checking ${folder}/${song}" should_process "${folder}/${song}" "${destination}/${destfolder}/${song}")
            fi
        done
    done < "$file"

    cd --  "/tmp" || exit 1   # Avoid leaving logs everywhere


    echo -ne "\e[1A";
    echo -e "\e[0K\r Determining what should be processed"
    concurrent "${allsongs[@]}"

    while read -r line; do
        [[ $line = \#* ]] && continue
        eval songs+=($line)
    done < "$tmpfile"

    concurrent "${songs[@]}"

    rm -- "$tmpfile"

}

main() {
    while getopts d:f:hv opt; do
        case $opt in
            d)  dest=$OPTARG
                ;;
            f)  file=$OPTARG
                ;;
            h)  show_help
                exit 0
                ;;
            v)  verbose=$((verbose+1))
                ;;
            *)  show_help >&2
                exit 1
                ;;
        esac
    done

    if [[ -z $dest ]] || [[ -z $file ]]; then
        show_help >&2
        exit 1
    fi

    copy_and_convert "$file" "$dest"

}

main "${@}"
