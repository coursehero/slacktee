#!/usr/bin/env bash


# https://github.com/course-hero/slacktee
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


# ----------
# Default Configuration
# ----------
webhook_url=""       # Incoming Webhooks integration URL. Old way to interact with Slack. (Deprecated)
token=""             # The authentication token of the bot user. Used for accessing Slack APIs.
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
streaming_batch_time=1
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

function escape_string()
{
	local result=$(echo "$1" \
		| sed 's/\\/\\\\/g' \
		| sed 's/"/\\"/g' \
		| sed "s/'/\\'/g")
	echo "$result"
}

function err_exit() 
{
	exit_code=$1
	shift
	echo "$me: $@" > /dev/null >&2
	exit $exit_code
}

function cleanup() 
{
	[[ -f $filename ]] && rm "$filename"
}

function show_help()
{
	cat << EOF
Usage: $me [options]

options:
    -h, --help                        Show this help.
    -n, --no-buffering                Post input values without buffering.
    --streaming                       Post input as it comes in, and update one comment with further input.
    --streaming-batch-time n          Only update streaming slack output every n seconds. Defaults to 1.
    -f, --file                        Post input values as a file.
    -l, --link                        Add a URL link to the message.
    -c, --channel channel_name        Post input values to specified channel or user.
    -u, --username user_name          This username is used for posting.
    -i, --icon emoji_name|url         This icon is used for posting. You can use a word
                                      from http://www.emoji-cheat-sheet.com or a direct url to an image.
    -t, --title title_string          This title is added to posts.
    -m, --message-formatting format   Switch message formatting (none|link_names|full).
                                      See https://api.slack.com/docs/formatting for more details.
    -p, --plain-text                  Don't surround the post with triple backticks.
    -a, --attachment [color]          Use attachment (richly-formatted message)
                                      Color can be 'good','warning','danger' or any hex color code (eg. #439FE0)
                                      See https://api.slack.com/docs/attachments for more details.
    -e, --field title value           Add a field to the attachment. You can specify this multiple times.
    -s, --short-field title value     Add a short field to the attachment. You can specify this multiple times.
    -o, --cond-color color pattern    Change the attachment color if the specified Regex pattern matches the input.
                                      You can specify this multiple times.
                                      If more than one pattern matches, the latest matched pattern is used.
    -d, --cond-prefix prefix pattern  This prefix is added to the message, if the specified Regex pattern matches the input.
                                      You can specify this multiple times.
                                      If more than one pattern matches, the latest matched pattern is used.
    -q, --no-output                   Don't echo the input.
    --config config_file              Specify the location of the config file.
    --setup                           Setup slacktee interactively.
EOF
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

	wrapped_message=$(echo "$textWrapper\n$message\n$textWrapper")
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

			message_attr="\"attachments\": [{ \
                          \"color\": \"$message_color\", \
                          \"mrkdwn_in\": [\"text\", \"fields\"], \
                          \"text\": \"$wrapped_message\""

			if [[ -n $found_pattern_prefix ]]; then
				orig_title=$title
				title="$found_pattern_prefix $title"
				# Clear conditional prefix for the nest send
				found_pattern_prefix=""
			fi

			if [[ -n $title ]]; then
				message_attr="$message_attr, \"title\": \"$title\" "
				# Clear conditional prefix from title
				title=$orig_title
			fi

			if [[ -n $link ]]; then
				message_attr="$message_attr, \"title_link\": \"$link\" "
			fi

			if [[ $mode == "file" ]]; then
				fields+=("{\
                                  \"title\": \"Access URL\", \
                                  \"value\": \"$access_url\" }")
				fields+=("{\
                                  \"title\": \"Download URL\", \
                                  \"value\": \"$download_url\"}")
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
			message_attr="\"text\": \"$wrapped_message\","	    
		fi

		icon_url=""
		icon_emoji=""
		if [ ! -z $icon ]; then
			if echo "$icon" | grep -q "^https\?://.*"; then
				icon_url="$icon"
			else
				icon_emoji=":$icon:"
			fi
		fi

		username=$(escape_string "$username")

		if [[ $mode == "streaming" ]]; then
			if [[ -z "$streaming_ts" ]]; then
				json="{\
					\"channel\": \"$channel\", \
					\"username\": \"$username\", \
					$message_attr \"icon_emoji\": \"$icon_emoji\", \
					\"icon_url\": \"$icon_url\" $parseMode}"

				post_result=$(curl -H "Authorization: Bearer $token" -H 'Content-type: application/json; charset=utf-8' -X POST -d "$json" https://slack.com/api/chat.postMessage 2> /dev/null)
				post_ok="$(echo "$post_result" | awk 'match($0, /"ok":([^,}]+)/) {print substr($0, RSTART+5, RLENGTH-5)}')"
				if [ $post_ok != "true" ]; then
					err_exit 1 "$post_result"
				fi

				# chat.update requires the channel id, not the name
				streaming_channel_id="$(echo "$post_result" | awk 'match($0, /channel":"([^"]*)"/) {print substr($0, RSTART+10, RLENGTH-11)}'|sed 's/\\//g')"
				
				# timestamp is used as the message id
				streaming_ts="$(echo "$post_result" | awk 'match($0, /ts":"([^"]*)"/) {print substr($0, RSTART+5, RLENGTH-6)}'|sed 's/\\//g')"
			else
				# batch updates every $streaming_batch_time seconds
				now=$(date '+%s')
				if [ -z "$streaming_last_update" ] || [ "$now" -ge $[streaming_last_update + streaming_batch_time] ]; then
					streaming_last_update="$now"
					json="{\
						\"channel\": \"$streaming_channel_id\", \
						\"ts\": \"$streaming_ts\", \
						$message_attr \"icon_emoji\": \"$icon_emoji\", \
						$parseMode}"

					post_result=$(curl -H "Authorization: Bearer $token" -H 'Content-type: application/json; charset=utf-8' -X POST -d "$json" https://slack.com/api/chat.update 2> /dev/null)
					post_ok="$(echo "$post_result" | awk 'match($0, /"ok":([^,}]+)/) {print substr($0, RSTART+5, RLENGTH-5)}')"
					if [ $post_ok != "true" ]; then
						err_exit 1 "$post_result"
					fi
				fi
			fi
		else
			json="{\
				\"channel\": \"$channel\", \
				\"username\": \"$username\", \
				$message_attr \"icon_emoji\": \"$icon_emoji\", \
				\"icon_url\": \"$icon_url\" $parseMode}"
			if [[ ! -z $webhook_url ]]; then
			    # Prioritize the webhook_url for the backward compatibility
			    post_result=$(curl -X POST --data-urlencode \
										"payload=$json" "$webhook_url" 2> /dev/null)
			    if [[ $post_result != "ok" ]]; then
				err_exit 1 "$post_result"
			    fi
			else
			    post_result=$(curl -H "Authorization: Bearer $token" -H 'Content-type: application/json; charset=utf-8' -X POST -d "$json" https://slack.com/api/chat.postMessage 2> /dev/null)
			    post_ok="$(echo "$post_result" | awk 'match($0, /"ok":([^,}]+)/) {print substr($0, RSTART+5, RLENGTH-5)}')"
			    if [ $post_ok != "true" ]; then
				err_exit 1 "$post_result"
			    fi
			fi
		fi
	fi
}

function process_line()
{
	# do not print message / line if -q option is specified
	if [[ "$no_output" == "" ]]; then
		echo "$1"
	fi

	# Escape special characters.
	line=$(escape_string "$1")

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
		# We should use unescaped value in the file mode
		echo "$1" >> "$filename"
	elif [[ $mode == "buffering" ]]; then
		if [[ -z "$text" ]]; then
			text="$line"
		else
			# See https://api.slack.com/rtm#limits for details on character limits
			local message="$text\n$line"
			if [[ ${#message} -ge 4000 ]]; then
				send_message "$text"
				text="$line"
			else
				text=$(echo "$text\n$line")
			fi
		fi
	elif [[ $mode == "streaming" ]]; then
		if [[ -z "$text" ]]; then
			text="$line"
		else
			text=$(echo "$text\n$line")
		fi

		send_message "$text"
	else
		err_exit 1 "Invalid mode: $mode."
	fi
}

function setup()
{
	if [[ -z "$HOME" ]]; then
		err_exit 1 "\$HOME is not defined. Please set it first."
	fi

        if [[ -z $(command -v curl) ]]; then
            read -p "curl is not installed, do you want to install it? [y/n] :" choice
                case "$choice" in
                        y|Y )
                                if [[ ! -z $(command -v dnf) ]]; then
                                    dnf -y install curl > /dev/null 2>&1
                                    result=$?
                                elif [[ ! -z $(command -v yum) ]]; then
                                    yum -y install curl > /dev/null 2>&1
                                    result=$?
                                elif [[ ! -z $(command -v apt-get) ]]; then
                                    apt-get -y install curl > /dev/null 2>&1
                                    result=$?
                                elif [[ ! -z $(command -v pacman) ]]; then
                                    pacman --noconfirm --sync curl > /dev/null 2>&1
                                    result=$?
                                else
                                    err_exit 1 "Don't know how to install curl, please install it first."
                                fi
                                if [[ "$result" == "0" ]]; then
                                    echo "curl successfully installed."
                                else
                                    err_exit 1 "curl failed to install, exit code was \"$result\". Please install it first."
                                fi
                                ;;
                        * )
                                err_exit 0 "Aborting" # Abort
                                ;;
                esac
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
				err_exit 0 "Aborting" # Abort
				;;
		esac
	fi

	# Load current local config
	. $local_conf

	# Start setup
	read -p "Token [$token]: " input_token
	if [[ -z "$input_token" ]]; then
		input_token=$token
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
	webhook_url="$webhook_url"
	token="$input_token"
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
function parse_args() 
{
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
			--streaming)
				mode="streaming"
				;;
			--streaming-batch-time)
				streaming_batch_time="$1"
				shift
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
			-q|--no-output)
				no_output=1
		                ;;
			-d|--cond-prefix)
				case "$1" in
					-*|'')
						# Found next command line option or empty. Error.
						err_exit 1 "A prefix of the conditional \
						title was not specified."
						show_help
						;;
					*)
						# Prefix should be found
						case "$2" in
							-*|'')
								# Found next command line option or empty. Error.
								err_exit 1 "A pattern of the conditional title was not specified"
								show_help
								;;
							*)
								# Set the prefix and the pattern to arrays
								cond_prefix_value=$(escape_string "$1")
								cond_prefix_prefixes+=("$cond_prefix_value")
								cond_prefix_patterns+=("$2")
								shift 2
								;;
						esac
						;;
				esac
				;;
			-m|--message-formatting)
				case "$1" in
					none)
						parseMode=', "parse": "none"'
						parseModeUrlEncoded='parse=none'
						;;
					link_names)
						parseMode=', "link_names": "1"'
						parseModeUrlEncoded='link_names=1'
						;;
					full)
						parseMode=', "parse": "full"'
						parseModeUrlEncoded='parse=full'
						;;
					*)
						err_exit 1 "Unknown message formatting option."
						show_help
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
						err_exit 1 "Unknown attachment color."
						show_help
						;;
				esac
				;;
			-o|--cond-color)
				case "$1" in
					-*|'')
						# Found next command line option or empty. Error.
						err_exit 1 "a color of the conditional color was not specified"
						show_help
						;;
					\#*|good|warning|danger)
						# Found hex color code or predefined colors
						case "$2" in
							-*|'')
								# Found next command line option or empty. Error.
								err_exit 1 "a pattern of the conditional color was not specified"
								show_help
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
						err_exit 1 "unknown attachment color $1"
						show_help
					;;
				esac
				;;
			-e|-s|--field|--short-field)
				case "$1" in
					-*|'')
						# Found next command line option or empty. Error.
						err_exit 1 "field title was not specified"
						show_help
						;;
					*)
						case "$2" in
							-*|'')
								# Found next command line option or empty. Error.
								err_exit 1 "field value was not specified"
								show_help
								;;			   
							*)
								field_title=$(escape_string "$1")
								field_value=$(escape_string "$2")
								if [[ $opt == "-s" || $opt == "--short-field" ]]; then
									fields+=("{\"title\": \"$field_title\", \"value\": \"$field_value\", \"short\": true}")
								else
									fields+=("{\"title\": \"$field_title\", \"value\": \"$field_value\"}")
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
				err_exit 1 "illegal option $opt"
				show_help
				;;
		esac
	done
}

# ---------
# Read in our configurations
# ---------
function setup_environment() 
{
	if [[ -e "/etc/slacktee.conf" ]]; then
		. /etc/slacktee.conf
	fi

	# backwards compat
	if [[ -z "$token" ]]; then
		token="$upload_token"
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
		token="$SLACKTEE_TOKEN"
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
}

# ----------
# Validate configurations
# ----------
function check_configuration() 
{
	if [[ -z $(command -v curl) ]]; then
		err_exit 1 "curl is not installed. Please install it first."
	fi

	if [[ $webhook_url == "" && $token == "" ]]; then
		err_exit 1 "Please setup the authentication token or the incoming webhook url (deprecated)."
	fi

	if [[ $token == "" && $mode == "file" ]]; then
		err_exit 1 "Please provide the authentication token for file uploads."
	fi

	if [[ $token == "" && $mode == "streaming" ]]; then
		err_exit 1 "Please provide the authentication token for streaming."
	fi

	if [[ $channel == "" ]]; then
		err_exit 1 "Please specify a channel."
	elif [[ ( "$channel" != "#"* ) && ( "$channel" != "@"* ) ]]; then
		channel="#$channel"
	fi

	if [[ -n "$icon" ]]; then
		icon=${icon#:} # remove leading ':'
		icon=${icon%:} # remove trailing ':'
	fi

	# Show deprecation warning
	if [[ $webhook_url != "" ]]; then
	    echo "$me: webhook_url is deprecated but still set. Recommend to remove it and use token instead." > /dev/null >&2
	fi
}

# ----------
# Start script
# ----------
function main() 
{
	parse_args "$@"
	setup_environment
	check_configuration
        trap cleanup SIGINT SIGTERM SIGKILL

	text=""
	if [[ -n "$title" || -n "$link" ]]; then
		# Use link as title, if title is not specified
		if [[ -z "$title" ]]; then
			title="$link"
		fi

		# Escape title
		title=$(escape_string "$title")

		# Add title to filename in the file mode
		if [[ "$mode" == "file" ]]; then
			# Remove special characters for the file title
			filetitle=$(echo "$title"|sed 's/[ \/:."]//g'|sed "s/'//g")
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

	while IFS='' read -r line; do
		process_line "$line"
	done
	if [[ -n $line ]]; then
		process_line "$line"
	fi

	if [[ "$mode" == "buffering" ]]; then
		send_message "$text"
	elif [[ "$mode" == "streaming" ]]; then
		unset streaming_last_update
		send_message "$text"
	elif [[ "$mode" == "file" ]]; then
		if [[ -s "$filename" ]]; then
			channels_param=""
			if [[ ( "$channel" == "#"* ) ]]; then
				# Set channels for making the file public
				channels_param="-F channels=$channel"
			fi
			result="$(curl -F file=@"$filename" -F token="$token" $channels_param https://slack.com/api/files.upload 2> /dev/null)"
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
		cleanup
	fi
}
main "$@"
