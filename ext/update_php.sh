#!/bin/bash
#
###################################################################
# Script to update PHP to the latest version. 								  #
# January 19, 2012                             Douglas Greenbaum. #
###################################################################
#
# Needs to be called with the version number as argument and also
# with "sudo env PATH=$PATH" in front to preserve the paths.
#
# ex: $ sudo env PATH=$PATH bash update_php.sh 5.3.8

# Get PHP Version as a argument
ARGS="$@"

# Traps CTRL-C
trap ctrl_c INT
function ctrl_c() {
	echo -e '\nCancelled by user'; if [ -n "$!" ]; then kill $!; fi; exit 1
}

die() {
	echo "ERROR: $1" > /dev/null 1>&2
	exit 1
}

check_sanity() {

	# Check if the script is run as root.
	if [ $(/usr/bin/id -u) != "0" ]
	then
		die "Must be run by root user. Use 'sudo env PATH=\$PATH bash ...'"
	fi

	# A single argument allowed
	[ "$#" -eq 1 ] || die "1 argument required, $# provided"

	# Check if version is sane
	echo $1 | grep -E -q '^[0-9].[0-9].[0-9]$' || die "Version number doesn't seem right; Please double check: $1"

	PHP_VER="$1"
	DATE=`date +%Y.%m.%d`
	SRCDIR=/tmp/php_$PHP_VER-$DATE
	PHP_CMD=$(type -p php) # Get executable path
	CONFIGURE_ARGS=$($PHP_CMD -i 2>&1 | grep "Configure Command =>" | cut -d " " -f6-) # Get original configure options
	if [ ! -n "$CONFIGURE_ARGS" ]; then 	# tests to see if the argument is non empty
		die "Previous arguments could not be loaded. You must run the command with 'sudo env PATH=\$PATH bash ...'"
	fi
	
	# Check if version is the same
	if [ $PHP_VER == $($PHP_CMD -v 2>&1 | grep "built" | cut -d " " -f2) ]; then
		die "This version number is already installed."
	fi
}

get_php() {

	# Download and extract source package
	echo "Getting PHP"
	mkdir $SRCDIR; cd $SRCDIR
	wget "http://us.php.net/distributions/php-$PHP_VER.tar.gz"
	
	if [ ! -f "php-$PHP_VER.tar.gz" ]; then
		die "This version could not be found on php.net/distrobutions."
	fi	
	
	tar zxvf php-$PHP_VER.tar.gz; cd php-$PHP_VER
}

backup_conf() {
        # Move the current configuration to a safe place.
        echo "Backing up working config..."
        [ -d /etc/php5 ] && mv /etc/php5 /etc/php5.original
}

recover_conf() {
	# Send the new default configuration to /tmp
	[ -d /etc/php5 ] && mv /etc/php5 /tmp/php5-$DATE
	
	# Recover previous configuration files
	echo "Restore working config..."
	[ -d /etc/php5.original  ] && mv /etc/php5.original /etc/php5
}

restart_servers() {
	echo "Restart PHP"
	if [ $(ps -ef | grep -c "php") -gt 1 ]; then 
		ps -e | grep "php" | awk '{print $1}' | xargs sudo kill -INT
	fi
	sleep 2
	/etc/init.d/php5-fpm start
}

backup_conf
get_nginx
compile_nginx
recover_conf
restart_servers

# Clean Sources
rm -r $SRCDIR