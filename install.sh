install_path=/usr/local/bin
script_dir=$( cd $(dirname $0); pwd -P )

# Copy slacktee.sh to /usr/local/bin 
cp $script_dir/slacktee.sh $install_path

# Set execute permission
chmod +x $install_path/slacktee.sh

echo "slacktee.sh has been installed to $install_path"

# Execute slacktee.sh with --setup option
$install_path/slacktee.sh --setup

