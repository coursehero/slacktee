# slacktee #

*slacktee* is a bash script that works like [tee](http://en.wikipedia.org/wiki/Tee_(command)) command.
Instead of writing the standard input to files, *slacktee* posts it to [Slack](https://slack.com/).

![Image](https://github.com/course-hero/slacktee/blob/slacktee-readme-images/slacktee_demo.gif)

Requirements
------------

*slacktee* uses [curl](http://curl.haxx.se/) command to communicate with Slack.

Installation
------------

```
# Clone git repository
git clone https://github.com/course-hero/slacktee.git

# Install slacktee.sh
bash ./slacktee/install.sh
```

install.sh copies slacktee.sh in `/usr/local/bin` and sets executable permission.

If you'd like to install it in the different directory such as `/usr/bin`, pass the target directory as a parameter of install.sh.
By default, `/usr/local/bin` may not be included in your `$PATH` environment variable (you should be aware of this when you use *slacktee* in *crontab*). So, if you would like to use *slacktee* without specifying its full path, coping it to `/usr/bin` may be a good idea.

```
# Install slacktee.sh in /usr/bin
bash ./slacktee/install.sh /usr/bin
```

Also, you can rename slacktee.sh during the installation. If you would like to give a different name to slacktee.sh, simply append it to the target directory.

```
# Install slacktee.sh in /usr/local/bin as 'slacktee'
bash ./slacktee/install.sh /usr/local/bin/slacktee
```

After the installation, interactive setup starts automatically.
If you would like to install slacktee.sh without the interactive setup, you can skip it with `-s` or `--skip-setup` option.

```
# Install slacktee without the interactive setup
bash ./slacktee/install.sh -s
```

### Packages ###
Packages are also availalbe for some platforms:

Scott R. Shinn at [Atomicorp](https://atomicorp.com/) created a package of `slacktee` for following Linux distributions:
- Centos 6/7
- RHEL 6/7
- Amazon Linux 1/2(LTS)
- Debian 8/9
- Ubuntu 14/16

These packages are maintained by Atomicorp and their repo can be easily installed to your system through their automated repo installer as following:
```
wget -q -O - https://updates.atomicorp.com/installers/atomic | bash
```
If you would prefer to download and install the package by yourself, you can find it in [their repository page](https://updates.atomicorp.com/channels/atomic/).

It's still alpha version, but we also have a debian package in this github repo.
* [slacktee-debian](https://github.com/course-hero/slacktee-debian)

Configuration
------------

Before start using *slacktee*, please set following variables in the script configuration file.
*slacktee* reads the global configuration (/etc/slacktee.conf) first, then reads your local configuration (~/.slacktee).
You can set up your local configuration file using interactive setup mode (--setup option).

You would need an authentication token for `slacktee`. It could be generated in 2 ways:

1. Crate a Slack App (Preffered by Slack, but a bit complicated to setup)
Follow steps listed in [creating a Slack App](https://api.slack.com/slack-apps#creating_apps).
Next, create a bot user for your app, give the following 3 permissions to the Bot Token Scopes of your app: `chat:write`, `chat:write:public`, `files:write`. More information about the permission scopes can be found at [permission scopes](https://api.slack.com/docs/oauth-scopes).
[Note] Even with `files:write` permission, Slack App can upload files only to the channels where the Slack App is in. So, please add your Slack App to the channels where you want to upload files.
At last, install the app to your workplace and get the Bot User OAuth token in the "OAuth & Permissions" section of the app management page.
2. Add a bot (Easy to setup, but Slack may remove it in future)
Add a bot into your workspace through [Slack App Directory](https://cks-world.slack.com/apps/A0F7YS25R-bots). You can now find 'API Token' in the configuration page of the bot.

```
token=""            # The authentication token of the bot user. Used for accessing Slack APIs.
channel=""          # Default channel to post messages. '#' is prepended, if it doesn't start with '#' or '@'.
tmp_dir="/tmp"      # Temporary file is created in this directory.
username="slacktee" # Default username to post messages.
icon="ghost"        # Default emoji or a direct url to an image to post messages. You don't have to wrap emoji with ':'. See http://www.emoji-cheat-sheet.com.
attachment=""       # Default color of the attachments. If an empty string is specified, the attachments are not used.
```

Usage
------------
Feed input to *slacktee* through the pipe.

```
usage: slacktee.sh [options]
  options:
    -h, --help                        Show this help.
    -n, --no-buffering                Post input values without buffering.
    --streaming                       Post input as it comes in, and update one comment with further input.
    -f, --file                        Post input values as a file.
    -l, --link                        Add a URL link to the message.
    -c, --channel channel_name        Post input values to specified channel(s) or user(s). You can specify this multiple times.
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

You can specify `channel`, `username`, `icon`, `title`, and `link` too.

```
ls | slacktee.sh -c "general" -u "slacktee" -i "shipit" -t "ls" -l "http://en.wikipedia.org/wiki/Ls"
```

Instead of emoji icon, you may provide an image url.

```
ls | slacktee.sh -c "general" -u "slacktee" -i "http://mirrors.creativecommons.org/presskit/icons/cc.png" -t "ls" -l "http://en.wikipedia.org/wiki/Ls"
```

Of course, you can connect another command with pipe.

```
ls | slacktee.sh | email "ls" foo@example.com
```

Would you like to use richly-formatted message? Use `-a`, `-e` and `-s` options.

```
cat error.log | slacktee.sh -a "danger" -e "Date and Time" "$(date)" -s "Host" "$(hostname)"
```

Direct message to your teammate 'chuck'? Easy!

```
echo "Submit Your Expense Reimbursement Form By Friday!" | slacktee.sh -c "@chuck"
```

Conditional coloring and prefix helps you to notice important messages easier.
If a specified Regex pattern matches the input, its corresponding color or prefix is used for posting the message. In the example below, the message color is green (good) by default, but the color becomes yellow (warning) if an input log starts with "Warning:". Also, it becomes red (danger) and the prefix `@channel` is added to the mssage if the log starts with "Error:".
It's pretty useful, isn't it?

```
# To enable @command, '-m link_names' must be specified
tail -f app.log | slacktee.sh -n -a "good" -o "warning" "^Warning:" -o "danger" "^Error:" -d "@channel" "^Error:" -m link_names
```

You can find more examples on [Course Hero blog](http://www.coursehero.com/blog/2015/04/09/why-we-built-slacktee-a-custom-slack-integration/).

Travis-CI Integration
---------------------

You may want to integrate *slacktee* into Travis-CI in order to send additional
logging information to your Slack channel. In this case, it is recommended that
you **do not expose** your Incoming WebHook URL and API authentication token as
plaintext values inside your slacktee.conf file.

Instead, use the [encrypt command](https://github.com/travis-ci/travis.rb#encrypt)
of the Travis client to set the SLACKTEE\_WEBHOOK and SLACKTEE\_TOKEN
environment variables, and leave the *webhook_url* and *token* values
in your slacktee.conf empty. When *slacktee* runs, it will give priority to the
environment variables, which Travis-CI will decrypt and set automatically during
the build process. In this way those two values are kept secure.

### Example

Modify slacktee.conf
```
webhook_url=""
token=""
channel="Travis-CI"
tmp_dir="/tmp"
username="slacktee"
icon="ghost"
```

Add the encrypted environment variables to the .travis.yml file in your git
repository
```bash
travis encrypt SLACKTEE_WEBHOOK='https://hooks.slack.com/services/afternoonTEE/BMP2vsT72/ohNoDontTellUs' --add
travis encrypt SLACKTEE_TOKEN='yoho-0987654321-1234567890-4488116622-abc123' --add
```

Looking at your travis.yml you will now see the following added
```yaml
env:
  global:
  - secure: 2YZabH8+UdzqyBWckojRDP9uudnCSYyxOOx1y85el69YdHwLDMD+dt49rAgIrmCWsWCWpUZ0ZRWV8vU2VFMffIhmikiqG7VoKHuN5PyY8qBwr9hq/ZI8gdwgjgfRIGtv/U89BTjMmc1g/6nJkSvMtiSUSK3Lopg0JCyuZsiyhzs=
  - secure: TKpohmywdOneQkqGxJiF+S1N8oCdTWWGsXgjzNXWSvb23KDtvGq/W2SpWdFdwEHC9Y8NymoAPYRSW8MUQoiJ7NaQ1eZQuyx6/orjHpIgqiAuHrOSaMagzpKVG6Gtb87qDgov65ZOasyex1OtPQdfFtZBX67B6IVXkRPV+IA/+UX=
```

An example travis.yml section using *slacktee* may look like:
```yaml
after_failure:
- ls /path/to/build | ./slacktee.sh -t "$TRAVIS_REPO_SLUG $TRAVIS_JOB_NUMBER build directory"
- cat /path/to/some.log | ./slacktee.sh -t "$TRAVIS_REPO_SLUG $TRAVIS_JOB_NUMBER some.log"
```
