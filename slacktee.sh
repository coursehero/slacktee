#!/bin/bash

# ----------
# Default Configuration
# ----------
webhook_url=""       # Incoming Webhooks integration URL
upload_token=""      # The user's API authentication token, only used for file uploads
channel="general"    # Default channel to post messages. '#' is prepended, if it doesn't start with '#' or '@'.
tmp_dir="/tmp"       # Temporary file is created in this directory.
username="slacktee"  # Default username to post messages.
icon="ghost"         # Default emoji to post messages. Don't wrap it with ':'. See http://www.emoji-cheat-sheet.com.
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

if [[ -e "/etc/slacktee.conf" ]]; then
    . /etc/slacktee.conf
fi

if [[ -n "$HOME" && -e "$HOME/.slacktee" ]]; then
    . "$HOME/.slacktee"
fi

# Overwrite webhook_url if the environment variable SLACKTEE_WEBHOOK is set
if [[ "$SLACKTEE_WEBHOOK" != "" ]]; then
    webhook_url=$SLACKTEE_WEBHOOK
fi

# Overwrite upload_token if the environment variable SLACKTEE_TOKEN is set
if [[ "$SLACKTEE_TOKEN" != "" ]]; then
    upload_token=$SLACKTEE_TOKEN
fi

function show_help(){
    echo "usage: $me [options]"
    echo "  options:"
    echo "    -h, --help                        Show this help."
    echo "    -n, --no-buffering                Post input values without buffering."
    echo "    -f, --file                        Post input values as a file."
    echo "    -l, --link                        Add a URL link to the message."
    echo "    -c, --channel channel_name        Post input values to specified channel or user."
    echo "    -u, --username user_name          This username is used for posting."
    echo "    -i, --icon emoji_name             This icon is used for posting."
    echo "    -t, --title title_string          This title is added to posts."
    echo "    -m, --message-formatting format   Switch message formatting (none|link_names|full)."
    echo "                                      See https://api.slack.com/docs/formatting for more details."
    echo "    -p, --plain-text                  Don't surround the post with triple backticks."
    echo "    -a, --attachment [color]          Use attachment (richly-formatted message)"
    echo "                                      Color can be 'good','warning','danger' or any hex color code (eg. #439FE0)"
    echo "                                      See https://api.slack.com/docs/attachments for more details."
    echo "    -e, --field title value           Add a field to the attachment. You can specify this multiple times"
    echo "    -s, --short-field title value     Add a short field to the attachment. You can specify this multiple times"
    echo "    --setup                           Setup slacktee interactively."
}

function send_message(){
    message="$1"
    escaped_message=$(echo "$textWrapper$message$textWrapper" | sed 's/"/\\"/g' | sed "s/'/\\'/g" )
    message_attr=""
    if [[ $message != "" ]]; then
	if [[ -n $attachment ]]; then
	    message_attr="\"attachments\": [{ \"color\": \"$attachment\", \"mrkdwn_in\": [\"text\", \"fields\"], \"text\": \"$escaped_message\" "

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

        json="{\"channel\": \"$channel\", \"username\": \"$username\", $message_attr \"icon_emoji\": \":$icon:\" $parseMode}"
        post_result=$(curl -X POST --data-urlencode "payload=$json" "$webhook_url" 2> /dev/null)
        if [[ $post_result == "ok" ]]; then
            exit 0
        else
            exit 1 # Error
        fi
    fi
}

function process_line(){
    if [[ $mode == "no-buffering" ]]; then
	prefix=''
	if [[ -z $attachment ]]; then
	    prefix=$title
	fi
	send_message "$prefix$1"
    elif [[ $mode == "file" ]]; then
	echo "$1" >> "$filename"
    else
	text="$text$1\n"
    fi
    echo "$line"
}

function setup(){
    if [[ -z "$HOME" ]]; then
      echo "\$HOME is not defined. Please set it first."
      exit 1
    fi

    local_conf="$HOME/.slacktee"

    if [[ -e "$local_conf" ]]; then
      echo ".slacktee is found in your home directory."
      read -p "Are you sure to overwrite it? [y/n] :" choice
      case "$choice" in
	  y|Y ) ;;
	  * ) exit 0;; # Abort
      esac
    fi

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
    elif [[ $input_attachment == "\"\"" || $input_attachment == "''" ]]; then
	input_attachment=""
    fi

    echo "webhook_url=\"$input_webhook_url\"" > "$local_conf"
    echo "upload_token=\"$input_upload_token\"" >> "$local_conf"
    echo "tmp_dir=\"$input_tmp_dir\"" >> "$local_conf"
    echo "channel=\"$input_channel\"" >> "$local_conf"
    echo "username=\"$input_username\"" >> "$local_conf"
    echo "icon=\"$input_icon\"" >> "$local_conf"
    echo "attachment=\"$input_attachment\"" >> "$local_conf"
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
            channel="$1"
            shift
            ;;
    -u|--username)
            username="$1"
            shift
            ;;
    -i|--icon)
            icon="$1"
            shift
            ;;
    -t|--title)
            title="$1"
            shift
            ;;
    -m|--message-formatting)
            case "$1" in
                none)
                    parseMode=", \"parse\": \"none\""
                    ;;
                link_names)
                    parseMode=", \"link_names\": \"1\""
                    ;;
                full)
                    parseMode=", \"parse\": \"full\""
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
		    attachment="#C0C0C0" # Default color
		    ;;
		\#*)
		    # Found hex color code
		    attachment="$1"
		    shift
		    ;;
		good|warning|danger)
		    # Predefined color
		    attachment="$1"
		    shift
		    ;;
		*)
                    echo "unknown attachment color"
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

# ----------
# Start script
# ----------

text=""
if [[ -n $title || -n $link ]]; then
    # Use link as title, if title is not specified
    if [[ -z $title ]]; then
	title="$link"
    fi

    # Add title to filename in the file mode
    if [[ $mode == "file" ]]; then
        filetitle=$(echo "$title"|sed 's/[ /:.]//g')
        filetitle="$filetitle-"
    fi

    if [[ -z $attachment ]]; then
	if [[ $mode == "no-buffering" ]]; then
            if [[ -n $link ]]; then
		title="<$link|$title>: "
            else
		title="$title: "
            fi
	elif [[ $mode == "file" ]]; then
            if [[ -n $link ]]; then
		title="<$link|$title>"
            fi
	else
            if [[ -n $link ]]; then
		text="-- <$link|$title> --\n"
            else
		text="-- $title --\n"
            fi
	fi
    fi
fi

timestamp=$(date +'%m%d%Y-%H%M%S')
filename="$tmp_dir/$filetitle$$-$timestamp.log"

while read line; do
    process_line "$line"
done
if [[ -n $line ]]; then
    process_line "$line"
fi

if [[ $mode == "buffering" ]]; then
    send_message "$text"
elif [[ $mode == "file" ]]; then
    result=$(curl -F file=@"$filename" -F token="$upload_token" https://slack.com/api/files.upload 2> /dev/null)
    access_url=$(echo "$result" | awk 'match($0, /url":"([^"]*)"/) {print substr($0, RSTART+6, RLENGTH-7)}'|sed 's/\\//g')
    download_url=$(echo "$result" | awk 'match($0, /url_download":"([^"]*)"/) {print substr($0, RSTART+15, RLENGTH-16)}'|sed 's/\\//g')
    if [[ -n $attachment ]]; then
	text="Input file has been uploaded"
    else
	if [[ $title != '' ]]; then
	    title=" of $title"
	fi
	text="Input file$title has been uploaded.\n$access_url\n\nYou can download it from the link below.\n$download_url"
    fi
    send_message "$text"
    rm "$filename"
fi
