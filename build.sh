#!/bin/bash

copy_files () {
    for i in *.html; do
        [ -f "$i" ] || break
        copy_file "$i"
    done
}

copy_file () {
    filename=$1
    if [[ "$filename" == *"index.html" ]]; then
        echo "Skipping file: $filename"
        return
    fi
    base=${filename##*/}
    pref=${base%.*}
    if [ ! -d "$pref" ]; then
        mkdir "$pref"
    fi
    cp "$filename" "$pref/index.html"
    echo "Copied $filename to $pref/index.html"
}   

# Generate the content
hugo

# Copy files over
pushd public
    pushd page
        copy_files
    popd
    pushd tags
        copy_files
    popd
popd