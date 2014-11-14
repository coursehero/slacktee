# slacktee #

*slacktee* is a bash script that works like [tee](http://en.wikipedia.org/wiki/Tee_(command)) command.
Instead of writing the standard input to files, *slacktee* posts it to [Slack](https://slack.com/).

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

Before start using *slacktee*, please set following variables in the script configuration file.
*slacktee* reads the global configuration (/etc/slacktee.conf) first, then reads your local configuration (~/.slacktee).

For more details about tokens, visit [Slack's API page](https://api.slack.com/).

```
slack_domain=""     # Slack domain. You can find it in the URL. https:[Your slack domain].slack.com/
token=""            # Incoming WebHooks Integration token, see token=[token] in Example URL. This is used for message posting. 
upload_token=""     # User API Authentication token. This is used for uploading.
channel=""          # Default channel to post messages. You don't have to add '#'.
tmp_dir="/tmp"      # Temporary file is created in this directory.
username="slacktee" # Default username to post messages.
icon="bell"         # Default icon to post messages. You don't have to wrap it with ':'. See http://www.emoji-cheat-sheet.com.
```

Usage
------------
Feed input to *slacktee* through the pipe.

```
usage: slacktee.sh [options]
  options:
    -h, --help                  Show this help.
    -n, --no-buffering          Post input values without buffering.
    -f, --file                  Post input values as a file.
    -c, --channel channel_name  Post input values to this channel.
    -u, --username user_name    This username is used for posting.
    -i, --icon icon_name        This icon is used for posting.
    -t, --title title_string    This title is added to posts.
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

You can specify `channel`, `username`, `icon` and `title` too.
```
ls | slacktee.sh -c "general" -u "slacktee" -i "shipit" -t "ls"
```

Of course, you can connect another command with pipe.
```
ls | slacktee.sh | email "ls" foo@example.com
```

