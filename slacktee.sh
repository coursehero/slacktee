#!/bin/bash

# ----------
# Default Configuration
# ----------
slack_domain=""     # Slack domain. You can find it in the URL. https:[Your slack domain].slack.com/
token=""            # Integration token. This is used for message posting.
upload_token=""     # User token. This is used for uploading.
channel=""          # Default channel to post messages. You don't have to add '#'.
tmp_dir="/tmp"      # Temporary file is created in this directory.
username="slacktee" # Default username to post messages.
icon="bell"         # Default icon to post messages. You don't have to wrap it with ':'.

# ----------
# Initialization
# ----------
me=`basename $0`
title=""
mode="buffering"

if [[ -e "/etc/slacktee.conf" ]]; then
    . /etc/slacktee.conf
fi

if [[ -n "$HOME" && -e "$HOME/.slacktee" ]]; then
    . $HOME/.slacktee
fi

function show_help(){
    echo "usage: $me [options]"
    echo "  options:"
    echo "    -h, --help                  Show this help."
    echo "    -n, --no-buffering          Post input values without buffering."
    echo "    -f, --file                  Post input values as a file."
    echo "    -c, --channel channel_name  Post input values to this channel."
    echo "    -u, --username user_name    This username is used for posting."
    echo "    -i, --icon icon_name        This icon is used for posting."
    echo "    -t, --title title_string    This title is added to posts."
}

function send_message(){
    message=$1
    if [[ $message != "" ]]; then
	escapedText=$(echo \`\`\`$message\`\`\` | sed 's/"/\"/g' | sed "s/'/\'/g" )
	json="{\"channel\": \"#$channel\", \"username\": \"$username\", \"text\": \"$escapedText\", \"icon_emoji\": \":$icon:\"}"
    
        post_result=`curl -X POST --data-urlencode "payload=$json" "https://$slack_domain.slack.com/services/hooks/incoming-webhook?token=$token" 2>/dev/null`
    fi
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
	-c|--channel)  
            channel="$1"
            shift
            ;;
	-u|--username)  
            username="$1"
            shift
            ;;
	-i|--icon)  
            icon=":$1:"
            shift
            ;;
	-t|--title) 
            title="$1"
            shift
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

if [[ $slack_domain == "" ]]; then
    echo "Please setup slack domain."
    exit 1
fi

if [[ $token == "" ]]; then
    echo "Please setup access token."
    exit 1
fi

if [[ $channel == "" ]]; then
    echo "Please specify a channel."
    exit 1
fi

if [[ $mode == "file" && $upload_token == "" ]]; then
    echo "Please setup upload token."
    exit 1
fi

# ----------
# Start script
# ----------

text=""
if [[ $title != "" ]]; then
    if [[ $mode == "no-buffering" ]]; then
	title="$title: "
    elif [[ $mode == "file" ]]; then
	filetitle=`echo "$title"|sed 's/ //g'`
	filetitle="$filetitle-"
    else
	text="-- $title --\n"
    fi
fi

timestamp=`date +'%m%d%Y-%H%M%S'`
filename="$tmp_dir/$filetitle$$-$timestamp.log"

while read line; do
    if [[ $mode == "no-buffering" ]]; then
	send_message "$title$line"
    elif [[ $mode == "file" ]]; then
	echo $line >> "$filename"
    else
	text="$text$line\n"
    fi
    echo $line
done

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

