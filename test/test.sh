#!/usr/bin/env bash
# - Test set of slacktee.sh -

# Test settings
SLACKTEE="/bin/bash ../slacktee.sh"
DATA="./test_data.txt"
CHANNEL="sandbox"

echo "This test posts many messages to your Slack channel?"
read -p "Are you sure to execute this test? [y/n] :" choice
case "$choice" in
    y|Y ) ;;
    * ) exit 0;; # Abort
esac

# Test 1: Setup
echo "-- Setup mode --"
$SLACKTEE '--setup'

# Test 2: Buffering
echo "-- Buffering (default) --"
cat $DATA | $SLACKTEE

# Test 3: No-buffering
echo "-- Non buffering (-n/--no-buffering) --"
cat $DATA | $SLACKTEE '-n'
echo "-- Non buffering (--no-buffering) --"
cat $DATA | $SLACKTEE '--no-buffering'

# Test 4: File upload
echo "-- File upload (-f) --"
cat $DATA | $SLACKTEE '-f'
echo "-- File upload (--file) --"
cat $DATA | $SLACKTEE '--file'

# Test 5: Title
echo "-- Title (-t) --"
cat $DATA | $SLACKTEE '-t' 'TitleTest'
echo "-- Title (--title) --"
cat $DATA | $SLACKTEE '--title' 'TitleTest'
echo "-- Title with non buffering (-t and -n)"
cat $DATA | $SLACKTEE '-t' 'TitleTest - Non Buffering' '-n'
echo "-- Title with file (-t and -f)"
cat $DATA | $SLACKTEE '-t' 'TitleTest - File' '-f'

# Test 6: Link
echo "-- Link (-l) --"
echo "Link (-l): Link should be used as a title" | $SLACKTEE '-l' 'https://www.google.com/'
echo "-- Link (--link) --"
echo "Link (--link): Link should be used as a title" | $SLACKTEE '--link' 'https://www.google.com/'
echo "-- Link with title (-t and -l) --"
echo "Link (-t and -l): Title should have a link to Google" | $SLACKTEE '-t' 'Google' '-l' 'https://www.google.com/'

# Test 7: Channel
echo "-- Channel (-c) --"
echo "Channel (-c): Post to $CHANNEL" | $SLACKTEE '-c' $CHANNEL
echo "-- Channel (--channel) --"
echo "Channel (--channel): Post to $CHANNEL" | $SLACKTEE '--channel' $CHANNEL
echo "-- Channel (-c) with # --"
echo "Channel (-c): Post to $CHANNEL with #" | $SLACKTEE '-c' "#"$CHANNEL
echo "-- Channel (-c) with @ (Shouldn't happen anything) --"
echo "Channel (-c): Post to @slackbot" | $SLACKTEE '-c' "@slackbot"

# Test 8: Username
echo "-- Username (-u) --"
echo "Username (-u): Username Test" | $SLACKTEE '-u' 'Username Test'
echo "-- Username (--username) --"
echo "Username (--username): Username Test2" | $SLACKTEE '--username' 'Username Test2 ' # We need to change the username to show username

# Test 9: Icon
echo "-- Icon (-i) --"
echo "Icon test: bell" | $SLACKTEE '-i' 'bell' '-u' 'Icon Test 1' # We need to change the username to show icon
echo "-- Icon (--icon) --"
echo "Icon test: grin" | $SLACKTEE '--icon' 'grin' '-u' 'Icon Test 2' 
echo "-- Icon (-i with URL) --"
echo "Icon test: url" | $SLACKTEE '-i' 'http://mirrors.creativecommons.org/presskit/icons/cc.png' '-u' 'Icon Test 3'

# Test 10: Message formatting
echo "-- Message formatting (-m) with link_names --"
echo "Message formatting: Link names @channel, #channel, https://www.google.com/" | $SLACKTEE '-m' 'link_names'
echo "-- Message formatting (--message-formatting) with full --"
echo "Message formatting: Full @channel, #$CHANNEL, https://www.google.com/" | $SLACKTEE '-m' 'full'
echo "-- Message formatting (-m) with none --"
echo "Message formatting: None @channel, #CHANNEL, https://www.google.com/" | $SLACKTEE '-m' 'none'

# Test 11: Plain text
echo "-- Plain text (-p) --"
echo "Plain text (-p)" | $SLACKTEE '-p'
echo "-- Plain text (--plain-text) --"
echo "Plain text (--plain-text)" | $SLACKTEE '--plain-text'

# Test 12: Attachment
echo "-- Attachment (-a) with no color --"
echo "Attachment: No color specified" | $SLACKTEE '-a'
echo "-- Attachment (--attachment) with 'good' --"
echo "Attachment: Good" | $SLACKTEE '-a' 'good'
echo "-- Attachment (--attachment) with color code --"
echo "Attachment: #FF0099" | $SLACKTEE '-a' '#FF0099'

# Test 13: Attachment with fields
echo "-- Attachment (-a) with long fiels (-e/--field) --"
echo "Attachment: Two fields" | $SLACKTEE '-a' '-e' 'Field 1 (-e)' 'Field 1 Value' '--field' 'Field 2 (--field)' 'Field 2 Value'
echo "-- Attachment (-a) with short fiels (-s/--short-field) --"
echo "Attachment: Two short fields" | $SLACKTEE '-a' '-s' 'Short field 1 (-s)' 'Field 1 Value' '--short-field' 'Short field 2 (--short-field)' 'Field 2 Value'
echo "-- Attachment (-a) with long and short fields (-e/-s) --"
echo "Attachment: Long and short fields" | $SLACKTEE '-a' '-e' 'Long Field (-e)' 'Long field Value' '-s' 'Short field 1 (-s)' 'Short field 1 Value' '-s' 'Short field 2 (-s)' 'Short field 2 Value'
echo "Attachment with file" | $SLACKTEE '-a' '-f' '-e' 'Long Field (-e)' 'Long field Value' '-s' 'Short field 1 (-s)' 'Short field 1 Value' '-s' 'Short field 2 (-s)' 'Short field 2 Value'

# Test 14: Conditional coloring
echo "-- Conditional Coloring (-o) without default color --"
echo "Conditional Coloring (-o) without default color. This should be colored gray." | $SLACKTEE '-o' 'danger' 'no-match' 
echo "-- Conditional Coloring (--cond-color) without default color --"
echo "Conditional Coloring (--cond-color) without default color. This should be colored gray." | $SLACKTEE '--cond-color' 'danger' 'no-match' 
echo "-- Conditional Coloring (-o) with default color --"
echo "Conditional Conoloring (-o) with defautl color. This should be colored black." | $SLACKTEE '-o' 'danger' 'no-match' '-a' '#000000'
echo "-- Conditional Coloring (-o) with default color defined by config file"
echo "Conditional Conoloring (-o) with defautl color defined by config file. This should be colored black." | $SLACKTEE '-o' 'danger' 'no-match' '--config' './default-coloring.conf'
echo "-- Conditional Coloring (-o) - Simple match in buffering mode"
cat $DATA | $SLACKTEE '-t' 'Conditional Coloring (-o) - Simple match in buffering mode. This should be colored green (good).' '-o' 'good' '^1st'
echo "-- Conditional Coloring (-o) - Simple match in no-buffering mode"
cat $DATA | $SLACKTEE '-n' '-t' 'Conditional Coloring (-o) - Simple match in no-buffering mode. Only 1st message should be colored green (good).' '-o' 'good' '^1st'
echo "-- Conditional Coloring (-o) - Simple match in file mode"
cat $DATA | $SLACKTEE '-f' '-t' 'Conditional Coloring (-o) - Simple match in file mode. This should be colored green (good).' '-o' 'good' '^1st'
echo "-- Conditional Coloring (-o) - Multiple matches in buffering mode"
cat $DATA | $SLACKTEE '-t' 'Conditional Coloring (-o) - Multiple matches in buffering mode. This should be colored red (danger).' '-o' 'good' '^1st' '-o' 'warning' '2nd' '-o' 'danger' '3rd'
echo "-- Conditional Coloring (-o) - Multiple matches in no-buffering mode"
cat $DATA | $SLACKTEE '-n' '-t' 'Conditional Coloring (-o) - Multiple matches in no-buffering mode. Each message should be colored differently (green, yellow and red).' '-o' 'good' '^1st' '-o' 'warning' '2nd' '-o' 'danger' '3rd'
echo "-- Conditional Coloring (-o) - Multiple matches in file mode"
cat $DATA | $SLACKTEE '-f' '-t' 'Conditional Coloring (-o) - Multiple matches in file mode. This should be colored red (danger).' '-o' 'good' '^1st' '-o' 'warning' '2nd' '-o' 'danger' '3rd'

# Test 15: Conditional prefix
echo "-- Conditional prefix (-d) in buffering mode --"
cat $DATA | $SLACKTEE '-t' 'Conditional prefix (-d) in buffering mode' '-d' '[Matched]' '2nd'
echo "-- Conditional prefix (--cond-prefix) in buffering mode --"
cat $DATA | $SLACKTEE '-t' 'Conditional prefix (--cond-prefix) in buffering mode' '--cond-prefix' '[Matched]' '2nd'
echo "-- Conditional prefix (-d) in no-buffering mode - Prefix should be added to 2nd line --"
cat $DATA | $SLACKTEE '-t' 'Conditional prefix (-d) in no-buffering mode' '-d' '[Matched]' '2nd' '-n'
echo "-- Conditional prefix (-d) in file mode --"
cat $DATA | $SLACKTEE '-t' 'Conditional prefix (-d) in file mode' '-d' '[Matched]' '2nd' '-f'
echo "-- Conditional prefix (-d) with attachment --"
cat $DATA | $SLACKTEE '-t' 'Conditional prefix (-d) with attachment' '-d' '[Matched]' '2nd' '-a' 'good'

# Test 16: Check exit code
echo "-- Check exit code : Success 0 --"
echo "Check if the exit code is 0" | $SLACKTEE ; echo $?
echo "-- Check exit code : Failure 1 --"
echo "Check if the exit code is 1" | $SLACKTEE '-c' 'this-channel-does-not-exist' ; echo $?

# Test 17: Escape special charactors
echo '\\\\I\like\backslash\.\\\\' | $SLACKTEE '-t' 'Escape backslashes'
echo '"I am a double quote", it said.' |  $SLACKTEE '-t' 'Escape double quote'
echo "I'm a single quote." |  $SLACKTEE '-t' 'Escape single quote'

echo "Test is done!"


