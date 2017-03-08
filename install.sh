#!/usr/bin/env bash

show_help () {
	cat <<-HELP
	usage: ${0##*/} [options] [path]
	  options:
	    -h, --help        Show this help
	    -n, --name value  Use value for the command name (eg. slacktee)
	    -p, --path value  Use value for the path (eg. /usr/bin/)
	  path:
	    optionally you can pass directy the path without the argument -p,--path
	HELP
	exit
}

# defaults
install_path=/usr/local/bin
slacktee_script="slacktee.sh"

# parse the arguments of the script
while [[ $# -gt 0 ]]; do
	case "$1" in
		-h|--help)
			show_help
			;;
		-n|--name)
			([ "${2##-*}" != "" ] && slacktee_script="$2" && shift) ||
				(echo -e 'name value not expecified\n' && show_help)
			;;
		-p|--path)
			([ "${2##-*}" != "" ] && install_path="$2" && shift) ||
				(echo -e 'path value not expecified\n' && show_help)
			;;
		*)
			# backwards compatibility
			[ "${1##-*}" != "" ] && install_path="$1"
			;;
	esac
	shift
done

script_dir=$( cd $(dirname $0); pwd -P )

# Copy slacktee.sh to /usr/local/bin 
cp "$script_dir/$slacktee_script" "$install_path"

# Set execute permission
chmod +x "$install_path/$slacktee_script"

echo "$slacktee_script has been installed to $install_path"

# Execute slacktee.sh with --setup option
"$install_path/$slacktee_script" --setup
