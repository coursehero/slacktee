#!/usr/bin/env bash

install_path=/usr/local/bin
slacktee_script="slacktee.sh"

if [[ $# -ne 0 ]]; then
    install_path=$1
fi
script_dir=$( cd $(dirname $0); pwd -P )

# Copy slacktee.sh to /usr/local/bin 
cp -i "$script_dir/$slacktee_script" "$install_path"
if [[ $? -ne 0 ]]; then
	exit 1
fi

message="$slacktee_script has been installed to $install_path"

if [[ -f "$install_path" ]]; then
    # Looks like the new file name is specified with the target directory
    original_name=$slacktee_script
    slacktee_script=$(basename "$install_path")
    install_path=$(dirname "$install_path")
    message="$original_name has been installed to $install_path as $slacktee_script"
fi

# Set execute permission
chmod +x "$install_path/$slacktee_script"

echo $message

# Execute slacktee.sh with --setup option
"$install_path/$slacktee_script" --setup
