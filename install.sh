#!/usr/bin/env bash

install_path=/usr/local/bin
slacktee_script="slacktee.sh"

if [ $# -ne 0 ]; then
    install_path=$1
fi
script_dir=$( cd $(dirname $0); pwd -P )

# Copy slacktee.sh to /usr/local/bin 
cp "$script_dir/$slacktee_script" "$install_path"

# Set execute permission
chmod +x "$install_path/$slacktee_script"

echo "$slacktee_script has been installed to $install_path"

# Execute slacktee.sh with --setup option
"$install_path/$slacktee_script" --setup
