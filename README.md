# slacktee #

*slacktee* is a bash script that provides a similer functionality as [tee](http://en.wikipedia.org/wiki/Tee_(command)) command.
Instead of wriing to files, *SlackTee* redirects output to [Slack](https://slack.com/).

Requirements
------------

*slacktee* uses [curl](http://curl.haxx.se/) command to communicate with Slack.

Installation
------------

Save `slacktee.sh` into your favorite place and make it executable as following:
```
chmod +x slacktee.sh
```
Also, it might be a good idea to add `slacktee.sh` in your command search path. 

Configuration
------------

Before start using *slacktee*, please set following variables in the script file.
For more details about tokens, visit [Slack's API page](https://api.slack.com/).

```
slack_domain=""     # Slack domain. You can find it in the URL. https:[Your slack domain].slack.com/
token=""            # Integration token. This is used for message posting.
upload_token=""     # User token. This is used for uploading.
channel=""          # Default channel to post messages. You don't have to add '#'.
tmp_dir="/tmp"      # Temporary file is created in this directory.
username="slacktee" # Default username to post messages. You don't have to add '#'.
icon="bell"         # Default icon to post messages. You don't have to wrap it with ':'.
```

Usage
------------
Feed input to *slacktee* through the pipe.

```
usage: slacktee.sh [options]
  options:
    -h, --help         Show this help.
    -n, --no-buffering Post input values without buffering.
    -f, --file         Post input values as a file.
    -c, --channel      Post input values to this channel.
    -u, --username     This username is used for posting.
    -i, --icon         This icon is used for posting.
    -t, --title        This title is added to posts.
```

If you'd like to post the output of `ls` command, you can do it like this.
```
ls | slacktee.sh
```

To post the output line by line, use `-n` option.
```
ls | slacktee.sh -n
```

To post the output as a file, use `-f` option.
```
ls | slacktee.sh -f
```


