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
webhook_url=""      # Incoming Webhooks integration URL. See https://my.slack.com/services/new/incoming-webhook
upload_token=""     # The user's API authentication token, only used for file uploads. See https://api.slack.com/#auth
channel=""          # Default channel to post messages. You don't have to add '#'.
tmp_dir="/tmp"      # Temporary file is created in this directory.
username="slacktee" # Default username to post messages.
icon="ghost"        # Default emoji to post messages. You don't have to wrap it with ':'. See http://www.emoji-cheat-sheet.com.
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
    -l, --link                  Add a URL link to the message.
    -c, --channel channel_name  Post input values to this channel.
    -u, --username user_name    This username is used for posting.
    -i, --icon emoji_name       This icon is used for posting.
    -t, --title title_string    This title is added to posts.
```

If you'd like to post the output of `ls` command, you can do it like this.
```
ls | slacktee.sh
```

To post the output of `tail -f` command line by line, use `-n` option.
```
tail -f foobar.log | slacktee.sh -n
```

To post the output of `find` command as a file, use `-f` option.
```
find /var -name "foobar" | slacktee.sh -f
```

You can specify `channel`, `username`, `icon` `title`, and `link` too.
```
ls | slacktee.sh -c "general" -u "slacktee" -i "shipit" -t "ls" -l "http://en.wikipedia.org/wiki/Ls"
```

Of course, you can connect another command with pipe.
```
ls | slacktee.sh | email "ls" foo@example.com
```

