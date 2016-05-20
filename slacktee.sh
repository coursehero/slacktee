#!/usr/bin/env bash

# ----------
# Default Configuration
# ----------
webhook_url=""       # Incoming Webhooks integration URL
upload_token=""      # The user's API authentication token, only used for file uploads
channel="general"    # Default channel to post messages. '#' is prepended, if it doesn't start with '#' or '@'.
tmp_dir="/tmp"       # Temporary file is created in this directory.
username="slacktee"  # Default username to post messages.
icon="ghost"         # Default emoji to post messages. Don't wrap it with ':'. See http://www.emoji-cheat-sheet.com; can be a url too.
attachment=""        # Default color of the attachments. If an empty string is specified, the attachments are not used.

# ----------
# Initialization
# ----------
me=$(basename "$0")
title=""
mode="buffering"
link=""
textWrapper="\`\`\`"
parseMode=""
fields=()
# Since bash 3 doesn't support the associative array, we store colors and patterns separately
cond_color_colors=()
cond_color_patterns=()
found_pattern_color=""
# This color is used when 'attachment' is used without color specification
internal_default_color="#C0C0C0"

# Since bash 3 doesn't support the associative array, we store prefixes and patterns separately
cond_prefix_prefixes=()
cond_prefix_patterns=()
found_title_prefix=""

function show_help()
{
	echo "usage: $me [options]"
	echo "  options:"
	echo "    -h, --help                        Show this help."
	echo "    -n, --no-buffering                Post input values without buffering."
	echo "    -f, --file                        Post input values as a file."
	echo "    -l, --link                        Add a URL link to the message."
	echo "    -c, --channel channel_name        Post input values to specified channel or user."
	echo "    -u, --username user_name          This username is used for posting."
	echo "    -i, --icon emoji_name|url         This icon is used for posting. You can use a word"
	echo "                                      from http://www.emoji-cheat-sheet.com or a direct url to an image."
	echo "    -t, --title title_string          This title is added to posts."
	echo "    -m, --message-formatting format   Switch message formatting (none|link_names|full)."
	echo "                                      See https://api.slack.com/docs/formatting for more details."
	echo "    -p, --plain-text                  Don't surround the post with triple backticks."
	echo "    -a, --attachment [color]          Use attachment (richly-formatted message)"
	echo "                                      Color can be 'good','warning','danger' or any hex color code (eg. #439FE0)"
	echo "                                      See https://api.slack.com/docs/attachments for more details."
	echo "    -e, --field title value           Add a field to the attachment. You can specify this multiple times."
	echo "    -s, --short-field title value     Add a short field to the attachment. You can specify this multiple times."
	echo "    -o, --cond-color color pattern    Change the attachment color if the specified Regex pattern matches the input."
	echo "                                      You can specify this multile times."
	echo "                                      If more than one pattern matches, the latest matched pattern is used."
	echo "    -d, --cond-prefix prefix pattern  This prefix is added to the message, if the specified Regex pattern matches the input."
	echo "                                      You can specify this multile times."
	echo "                                      If more than one pattern matches, the latest matched pattern is used."
	echo "    --config config_file              Specify the location of the config file."
	echo "    --setup                           Setup slacktee interactively."
}



function send_message()
{
	message="$1"

	# Prepend the prefix to the message, if it's set
	if [[ -z $attachment && -n $found_pattern_prefix ]]; then
		message="$found_pattern_prefix$message"
		# Clear conditional prefix for the nest send
		found_pattern_prefix=""
	fi

	escaped_message=$(echo "$textWrapper\n$message\n$textWrapper" | sed 's/"/\\"/g' | sed "s/'/\\'/g" )
	message_attr=""
	if [[ $message != "" ]]; then
		if [[ -n $attachment ]]; then

			# Set message color
			message_color="$attachment"
			if [[ -n $found_pattern_color ]]; then
				message_color="$found_pattern_color"
				# Reset with the default color for the next send
				found_pattern_color="$attachment"
			fi

			message_attr="\"attachments\": [{ \"color\": \"$message_color\", \"mrkdwn_in\": [\"text\", \"fields\"], \"text\": \"$escaped_message\" "

			if [[ -n $found_pattern_prefix ]]; then
				title="$found_pattern_prefix $title"
				# Clear conditional prefix for the nest send
				found_pattern_prefix=""
			fi

			if [[ -n $title ]]; then
				message_attr="$message_attr, \"title\": \"$title\" "
			fi

			if [[ -n $link ]]; then
				message_attr="$message_attr, \"title_link\": \"$link\" "
			fi

			if [[ $mode == "file" ]]; then
				fields+=("{\"title\": \"Access URL\", \"value\": \"$access_url\" }")
				fields+=("{\"title\": \"Download URL\", \"value\": \"$download_url\"}")
			fi

			if [[ ${#fields[@]} != 0 ]]; then
				message_attr="$message_attr, \"fields\": ["
				for field in "${fields[@]}"; do 
					message_attr="$message_attr $field,"
				done
				message_attr=${message_attr%?} # Remove last comma
				message_attr="$message_attr ]"
			fi

			# Close attachment
			message_attr="$message_attr }], "
		else
			message_attr="\"text\": \"$escaped_message\","	    
		fi

		icon_url=""
		icon_emoji=""
		if echo "$icon" | grep -q "^https\?://.*"; then
			icon_url="$icon"
		else
			icon_emoji=":$icon:"
		fi

		json="{\"channel\": \"$channel\", \"username\": \"$username\", $message_attr \"icon_emoji\": \"$icon_emoji\", \"icon_url\": \"$icon_url\" $parseMode}"
		post_result=$(curl -X POST --data-urlencode "payload=$json" "$webhook_url" 2> /dev/null)
		exit_code=1
		if [[ $post_result == "ok" ]]; then
			exit_code=0
		fi
	fi
}

function process_line()
{
	echo "$1"
	line="$(echo "$1" | sed $'s/\t/  /g')"

	# Check the patterns of the conditional colors
	# If more than one pattern matches, the latest pattern is used
	if [[ ${#cond_color_patterns[@]} != 0 ]]; then
		for i in "${!cond_color_patterns[@]}"; do
			if [[ $line =~ ${cond_color_patterns[$i]} ]]; then
				found_pattern_color=${cond_color_colors[$i]}
			fi
		done
	fi

	# Check the patterns of the conditional titles
	# If more than one pattern matches, the latest pattern is used
	if [[ ${#cond_prefix_patterns[@]} != 0 ]]; then
		for i in "${!cond_prefix_patterns[@]}"; do
			if [[ $line =~ ${cond_prefix_patterns[$i]} ]]; then
				found_pattern_prefix=${cond_prefix_prefixes[$i]}
				if [[ -n $attachment || $mode != "no-buffering" ]]; then
					# Append a line break to the prefix for better formatting
					found_pattern_prefix="$found_pattern_prefix\n"
				else
					# Append a space to the prefix for better formatting
					found_pattern_prefix="$found_pattern_prefix "
				fi
			fi
		done
	fi

	if [[ $mode == "no-buffering" ]]; then
		prefix=''
		if [[ -z $attachment ]]; then
			prefix=$title
		fi  
		send_message "$prefix$line"
	elif [[ $mode == "file" ]]; then
		echo "$line" >> "$filename"
	else
		if [[ -z "$text" ]]; then
			text="$line"
		else
			text="$text\n$line"
		fi  
	fi  
}

function setup()
{
	if [[ -z "$HOME" ]]; then
		echo "\$HOME is not defined. Please set it first."
		exit 1
	fi

	local_conf="$HOME/.slacktee"

	if [[ -e "$local_conf" ]]; then
		echo ".slacktee is found in your home directory."
		read -p "Are you sure to overwrite it? [y/n] :" choice
		case "$choice" in
			y|Y )
				# Continue
				;;
			* )
				exit 0 # Abort
				;;
		esac
	fi

	# Load current local config
	. $local_conf

	# Start setup
	read -p "Incoming Webhook URL [$webhook_url]: " input_webhook_url
	if [[ -z "$input_webhook_url" ]]; then
		input_webhook_url=$webhook_url
	fi
	read -p "Upload Token [$upload_token]: " input_upload_token
	if [[ -z "$input_upload_token" ]]; then
		input_upload_token=$upload_token
	fi
	read -p "Temporary Directory [$tmp_dir]: " input_tmp_dir
	if [[ -z "$input_tmp_dir" ]]; then
		input_tmp_dir=$tmp_dir
	fi
	read -p "Default Channel [$channel]: " input_channel
	if [[ -z "$input_channel" ]]; then
		input_channel=$channel
	fi
	read -p "Default Username [$username]: " input_username
	if [[ -z "$input_username" ]]; then
		input_username=$username
	fi
	read -p "Default Icon: [$icon]: " input_icon
	if [[ -z "$input_icon" ]]; then
		input_icon=$icon
	fi
	read -p "Default color of the attachment. (empty string disables attachment) [$attachment]: " input_attachment
	if [[ -z "$input_attachment" ]]; then
		input_attachment=$attachment
	elif [[ $input_attachment == '""' || $input_attachment == "''" ]]; then
		input_attachment=""
	fi

	cat <<- EOF | sed 's/^[[:space:]]*//' > "$local_conf"
	webhook_url="$input_webhook_url"
	upload_token="$input_upload_token"
	tmp_dir="$input_tmp_dir"
	channel="$input_channel"
	username="$input_username"
	icon="$input_icon"
	attachment="$input_attachment"
	EOF
}

# ----------
# Parse command line options
# ----------
OPTIND=1

while [[ $# -gt 0 ]]; do
	opt="$1"
	shift

	case "$opt" in
		-h|\?|--help)
			show_help
			exit 0
			;;
		-n|--no-buffering)
			mode="no-buffering"
			;;
		-f|--file)
			mode="file"
			;;
		-l|--link)
			link="$1"
			shift
			;;
		-c|--channel)
			opt_channel="$1"
			shift
			;;
		-u|--username)
			opt_username="$1"
			shift
			;;
		-i|--icon)
			opt_icon="$1"
			shift
			;;
		-t|--title)
			title="$1"
			shift
			;;
		-d|--cond-prefix)
			case "$1" in
				-*|'')
					# Found next command line option or empty. Error.
					echo "a prefix of the conditional title was not specified"
					show_help
					exit 1
					;;
				*)
					# Prefix should be found
					case "$2" in
						-*|'')
							# Found next command line option or empty. Error.
							echo "a pattern of the conditional title was not specified"
							show_help
							exit 1
							;;
						*)
							# Set the prefix and the pattern to arrays
							cond_prefix_prefixes+=("$1")
							cond_prefix_patterns+=("$2")
							shift
							shift
							;;
					esac
					;;
			esac
			;;
		-m|--message-formatting)
			case "$1" in
				none)
					parseMode=', "parse": "none"'
					;;
				link_names)
					parseMode=', "link_names": "1"'
					;;
				full)
					parseMode=', "parse": "full"'
					;;
				*)
					echo "unknown message formatting option"
					show_help
					exit 1
					;;
			esac
			shift
			;;
		-p|--plain-text)
			textWrapper=""
			;;

		-a|--attachment)
			case "$1" in
				-*|'')
					# Found next command line option
					opt_attachment="$internal_default_color" # Use default color
					;;
				\#*|good|warning|danger)
					# Found hex color code or predefined colors
					opt_attachment="$1"
					shift
					;;
				*)
					echo "unknown attachment color"
					show_help
					exit 1
					;;
			esac
			;;
		-o|--cond-color)
			case "$1" in
				-*|'')
					# Found next command line option or empty. Error.
					echo "a color of the conditional color was not specified"
					show_help
					exit 1
					;;
				\#*|good|warning|danger)
					# Found hex color code or predefined colors
					case "$2" in
						-*|'')
							# Found next command line option or empty. Error.
							echo "a pattern of the conditional color was not specified"
							show_help
							exit 1
							;;
						*)
							# Set the color and the pattern to arrays
							cond_color_colors+=("$1")
							cond_color_patterns+=("$2")
							shift
							shift
							;;
					esac
					;;
				*)
					echo "unknown attachment color $1"
					show_help
					exit 1
				;;
			esac
			;;
		-e|-s|--field|--short-field)
			case "$1" in
				-*|'')
					# Found next command line option or empty. Error.
					echo "field title was not specified"
					show_help
					exit 1
					;;
				*)
					case "$2" in
						-*|'')
							# Found next command line option or empty. Error.
							echo "field value was not specified"
							show_help
							exit 1
							;;			   
						*)
							if [[ $opt == "-s" || $opt == "--short-field" ]]; then
								fields+=("{\"title\": \"$1\", \"value\": \"$2\", \"short\": true}")
							else
								fields+=("{\"title\": \"$1\", \"value\": \"$2\"}")
							fi
							shift
							shift
							;;
					esac
			esac
			;;
		--config)
			CUSTOM_CONFIG=$1
			shift
			;;
		--setup)
			setup
			exit 1
			;;
		*)
			echo "illegal option $opt"
			show_help
			exit 1
			;;
	esac
done

# ---------
# Read in our configurations
# ---------
if [[ -e "/etc/slacktee.conf" ]]; then
	. /etc/slacktee.conf
fi

if [[ -n "$HOME" && -e "$HOME/.slacktee" ]]; then
	. "$HOME/.slacktee"
fi

if [[ -e "$CUSTOM_CONFIG" ]]; then
	. $CUSTOM_CONFIG
fi

# Overwrite webhook_url if the environment variable SLACKTEE_WEBHOOK is set
if [[ "$SLACKTEE_WEBHOOK" != "" ]]; then
	webhook_url="$SLACKTEE_WEBHOOK"
fi

# Overwrite upload_token if the environment variable SLACKTEE_TOKEN is set
if [[ "$SLACKTEE_TOKEN" != "" ]]; then
	upload_token="$SLACKTEE_TOKEN"
fi

# Overwrite channel if it's specified in the command line option
if [[ "$opt_channel" != "" ]]; then
	channel="$opt_channel"
fi

# Overwrite username if it's specified in the command line option
if [[ "$opt_username" != "" ]]; then
	username="$opt_username"
fi

# Overwrite icon if it's specified in the command line option
if [[ "$opt_icon" != "" ]]; then
	icon="$opt_icon"
fi

# Overwrite attachment if it's specified in the command line option
if [[ "$opt_attachment" != "" ]]; then
	attachment="$opt_attachment"
fi

# Set the default color to attachment if it's still empty and the length of the cond_color_patterns is not 0
if [[ -z $attachment ]] && [[ ${#cond_color_patterns[@]} != 0 ]]; then
	attachment="$internal_default_color"
fi

# ----------
# Validate configurations
# ----------

if [[ $webhook_url == "" ]]; then
	echo "Please setup the webhook url of this incoming webhook integration."
	exit 1
fi

if [[ $upload_token == "" && $mode == "file" ]]; then
	echo "Please provide the authentication token for file uploads."
	exit 1
fi

if [[ $channel == "" ]]; then
	echo "Please specify a channel."
	exit 1
elif [[ ( "$channel" != "#"* ) && ( "$channel" != "@"* ) ]]; then
	channel="#$channel"
fi

if [[ -n "$icon" ]]; then
	icon=${icon#:} # remove leading ':'
	icon=${icon%:} # remove trailing ':'
fi

# ----------
# Start script
# ----------

text=""
if [[ -n "$title" || -n "$link" ]]; then
	# Use link as title, if title is not specified
	if [[ -z "$title" ]]; then
		title="$link"
	fi

	# Add title to filename in the file mode
	if [[ "$mode" == "file" ]]; then
		filetitle=$(echo "$title"|sed 's/[ /:.]//g')
		filetitle="$filetitle-"
	fi

	if [[ -z "$attachment" ]]; then
		if [[ "$mode" == "no-buffering" ]]; then
			if [[ -n "$link" ]]; then
				title="<$link|$title>: "
			else
				title="$title: "
			fi
		elif [[ "$mode" == "file" ]]; then
			if [[ -n "$link" ]]; then
				title="<$link|$title>"
			fi
		else
			if [[ -n "$link" ]]; then
				text="-- <$link|$title> --\n"
			else
				text="-- $title --\n"
			fi
		fi
	fi
fi

timestamp="$(date +'%m%d%Y-%H%M%S')"
filename="$tmp_dir/$filetitle$$-$timestamp.log"

if [[ "$mode" == "file" ]]; then
	touch $filename
fi

exit_code=0

while IFS='' read line; do
	process_line "$line"
done
if [[ -n $line ]]; then
	process_line "$line"
fi

if [[ "$mode" == "buffering" ]]; then
	send_message "$text"
elif [[ "$mode" == "file" ]]; then
	if [[ -s "$filename" ]]; then
		channels_param=""
		if [[ ( "$channel" == "#"* ) ]]; then
			# Set channels for making the file public
			channels_param="-F channels=$channel"
		fi
		result="$(curl -F file=@"$filename" -F token="$upload_token" $channels_param https://slack.com/api/files.upload 2> /dev/null)"
		access_url="$(echo "$result" | awk 'match($0, /url_private":"([^"]*)"/) {print substr($0, RSTART+14, RLENGTH-15)}'|sed 's/\\//g')"
		download_url="$(echo "$result" | awk 'match($0, /url_private_download":"([^"]*)"/) {print substr($0, RSTART+23, RLENGTH-24)}'|sed 's/\\//g')"
		if [[ -n "$attachment" ]]; then
			text="Input file has been uploaded"
		else
			if [[ "$title" != "" ]]; then
				title=" of $title"
			fi
			text="Input file$title has been uploaded.\n$access_url\n\nYou can download it from the link below.\n$download_url"
		fi
		send_message "$text"
	fi
	# Clean up the temp file
	rm "$filename"
fi

exit $exit_code
