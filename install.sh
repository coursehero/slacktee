#!/usr/bin/env bash

# ------------------------------------------------------------
# Copyright 2017 Course Hero, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------


install_path=/usr/local/bin
slacktee_script="slacktee.sh"

skip_setup=false

# Parse options
if [[ $# -ne 0 ]]; then
	while [[ $# -gt 0 ]]; do
		opt="$1"
		shift

		case "$opt" in
			-s|--skip-setup)
				skip_setup=true
				;;
			*)
				install_path=$opt
				;;
		esac
	done
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

if [[ $skip_setup = false ]]; then
    # Execute slacktee.sh with --setup option
    "$install_path/$slacktee_script" --setup
fi
