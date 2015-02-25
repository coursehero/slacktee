#!/bin/bash

# ----------
# Default Configuration
# ----------
webhook_url=""      # Incoming Webhooks integration URL
upload_token=""     # The user's API authentication token, only used for file uploads
channel="general"   # Default channel to post messages. Don't add the '#' prefix.
tmp_dir="/tmp"      # Temporary file is created in this directory.
username="slacktee" # Default username to post messages.
icon="ghost"        # Default emoji to post messages. Don't wrap it with ':'. See http://www.emoji-cheat-sheet.com.

# ----------
# Initialization
# ----------
me=`basename $0`
title=""
mode="buffering"
link=""
textWrapper="\`\`\`"
parseMode=""

if [[ -e "/etc/slacktee.conf" ]]; then
    . /etc/slacktee.conf
fi

if [[ -n "$HOME" && -e "$HOME/.slacktee" ]]; then
    . $HOME/.slacktee
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
    echo "    -c, --channel channel_name        Post input values to this channel."
    echo "    -u, --username user_name          This username is used for posting."
    echo "    -i, --icon emoji_name             This icon is used for posting."
    echo "    -t, --title title_string          This title is added to posts."
    echo "    -m, --message-formatting format   Switch message formatting (none|link_names|full)."
    echo "                                      See https://api.slack.com/docs/formatting for more details."
    echo "    -p, --plain-text                  Don't surround the post with triple backticks."
    echo "    --setup                           Setup slacktee interactively."
}

function send_message(){
    message=$1
    if [[ $message != "" ]]; then
        escapedText=$(echo $textWrapper$message$textWrapper | sed 's/"/\\"/g' | sed "s/'/\\'/g" )
        json="{\"channel\": \"#$channel\", \"username\": \"$username\", \"text\": \"$escapedText\", \"icon_emoji\": \":$icon:\" $parseMode}"
        post_result=`curl -X POST --data-urlencode "payload=$json" $webhook_url 2>/dev/null`
    fi
}

function process_line(){
    if [[ $mode == "no-buffering" ]]; then
    send_message "$title$line"
    elif [[ $mode == "file" ]]; then
    echo $line >> "$filename"
    else
    text="$text$line\n"
    fi
    echo $line
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

    echo "webhook_url=\"$input_webhook_url\"" > "$local_conf"
    echo "upload_token=\"$input_upload_token\"" >> "$local_conf"
    echo "tmp_dir=\"$input_tmp_dir\"" >> "$local_conf"
    echo "channel=\"$input_channel\"" >> "$local_conf"
    echo "username=\"$input_username\"" >> "$local_conf"
    echo "icon=\"$input_icon\"" >> "$local_conf"
}

# ----------
# Parse command line options
# ----------
OPTIND=1

while [[ $# > 0 ]]; do
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

    if [[ $mode == "no-buffering" ]]; then
        if [[ -n $link ]]; then
            title="<$link|$title>: "
        else
            title="$title: "
        fi
    elif [[ $mode == "file" ]]; then
        filetitle=`echo "$title"|sed 's/[ /:.]//g'`
        filetitle="$filetitle-"
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

timestamp=`date +'%m%d%Y-%H%M%S'`
filename="$tmp_dir/$filetitle$$-$timestamp.log"

while read line; do
    process_line line
done
if [[ -n $line ]]; then
    process_line
fi

if [[ $mode == "buffering" ]]; then
    send_message "$text"
elif [[ $mode == "file" ]]; then
    result=`curl -F file=@$filename -F token=$upload_token https://slack.com/api/files.upload 2> /dev/null`
    access_url=`echo $result|awk 'match($0, /url_private":"([^"]*)"/) {print substr($0, RSTART+14, RLENGTH-15)}'|sed 's/\\\//g'`
    download_url=`echo $result|awk 'match($0, /url_download":"([^"]*)"/) {print substr($0, RSTART+15, RLENGTH-16)}'|sed 's/\\\//g'`
    if [[ $title != '' ]]; then
    title="of $title"
    fi
    text="Log file $title has been uploaded.\n$access_url\n\nYou can download it from the link below.\n$download_url"
    send_message "$text"
    rm $filename
fi

