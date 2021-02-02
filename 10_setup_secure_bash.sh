#!/bin/bash

#Script to setup a new secured Ubuntu server system when Chef or Puppet isn't going to be used. 
#Assumes that git will NOT be installed on the remote system but SSH is. 
# 1) Enable Remote Login on New Server via SSH
# 2) Define the IP address with NEW_SERVER variable
# 2) On This server with ssh-keys execute this script
# sets up logging of all commands via syslog
# enforces login only by keys (no passwords)
# sends emails on login

###############Globals###########

NEW_SERVER=192.168.1.168
USERNAME=$(who am i | awk '{print $1}')
DOMAIN=$(hostname -d)
FILES_DIR="./files"
#we are either running this from a control server or locally
REMOTE=false

#######Functions##############

#Function: create_sendmail_file()
#Creates the file to go into /etc/profile.d for sending mail
#
# Input:  Name of file
# Output: Result of the commands
# Return: Command Status
function create_sendmail_file() {
	local filename=$1
	#local -n return_var=$2
	local _ret=
	_ret=1

	TAB="$(printf '\t')"
	cat <<- ENDTEXT > "$FILES_DIR/$filename"
		#!/bin/bash
		#Script to be put into /etc/profile.d/

		MYNAME=\$(whoami)
		HOSTNAME=\$(hostname)
		DOMAIN=\$(hostname -d)

		TO=$USERNAME@$DOMAIN
		/usr/sbin/sendmail -t <<-ERRMAIL
		${TAB}To: \$TO
		${TAB}From: \$HOSTNAME <$USERNAME@$DOMAIN>
		${TAB}Subject: Login to \$HOSTNAME by \$MYNAME
		${TAB}Content-Transfer-Encoding: 8bit
		${TAB}Content-Type: text/plain; charset=UTF-8

		${TAB}\$(w)
		ERRMAIL
ENDTEXT

	_ret=$?
	return $_ret
}

#Function: run_command()
#Runs the command either locally or via SSH depending on $REMOTE
#
# Input:  Command
# Output: Result of the command
# Return: Command Status
function run_command() {
	local command=$1
	#local -n return_var=$2
	local _ret=

	_ret=1
	if $REMOTE; then
		ssh -t "$NEW_SERVER" "$command"
	else
		$command
	fi
	_ret=$?
	return $_ret
}

#Function: copy_file_to_tmp()
#Copies the file to /tmp either via scp or cp depending on $REMOTE
#
# Input:  File
# Output: Result of the commands
# Return: Command Status
function copy_file_to_tmp() {
	local file=$1
	#local -n return_var=$2
	local _ret=

	_ret=1
	if $REMOTE; then
		scp "$file" "$USERNAME"@"$NEW_SERVER":/tmp
	else
		cp "$file" /tmp/
	fi
	_ret=$?
	return $_ret
}

######Main begins

if [[ $DOMAIN == "" ]]; then
	echo "DOMAIN cannot be blank ($DOMAIN). Either fix /etc/hosts or set in file."
	exit 1
fi


if $REMOTE; then
	ssh-copy-id "$USERNAME"@"$NEW_SERVER"
else
	if ! sudo apt install openssh-server; then
		echo "Install openssh-server failed"
		exit 1
  fi
fi


HOSTNAME=run_command 'hostname'

if run_command 'sudo -v'; then
	echo "sudo working"
else
	echo "sudo not working"
	exit 1
fi 

SENDMAIL_FILE="Z98_send_mail_on_login.sh"
create_sendmail_file "$SENDMAIL_FILE"
chmod a+x $FILES_DIR/$SENDMAIL_FILE

echo "Attempting to setup mail on login script"
if copy_file_to_tmp $FILES_DIR/$SENDMAIL_FILE ; then
	echo "Setting up $FILES_DIR/$SENDMAIL_FILE"
	run_command "sudo mv /tmp/$SENDMAIL_FILE /etc/profile.d/"
else
	echo "can't copy over file $SENDMAIL_FILE to /tmp"
	exit 1
fi


echo "Attempting to setup logging all commands script"
if copy_file_to_tmp $FILES_DIR/Z99-bashlogging.sh ; then
	echo "Setting up $FILES_DIR/Z99-bashlogging.sh"
	run_command "sudo mv /tmp/Z99-bashlogging.sh /etc/profile.d/ && sudo ls /etc/profile.d/"
else
	echo "can't copy over file Z99-bashlogging.sh"
	exit 1
fi

if ! $REMOTE && [ -s "/home/$USERNAME/.ssh/authorized_keys" ] ; then
	#Only run this if running on the local server
	if ssh-keygen; then
		echo "public/private key for server generated"
	fi
fi

echo "Attempting to lock down ssh to key access only"
#First check that the file /home/$USERNAME/.ssh/authorized_keys exists otherwise
#	you lock yourself out. 
if ! $REMOTE ; then
	if [[ ! -s /home/$USERNAME/.ssh/authorized_keys ]]; then
		echo "Not setting up key only ssh because authorized_keys file is empty"
		echo "Stopping here. Rerun once set, or run from remote machine"
		exit 1
	fi
fi

if copy_file_to_tmp $FILES_DIR/10_sshd_local.conf; then
	run_command "sudo mv /tmp/10_sshd_local.conf /etc/ssh/sshd_config.d/ && sudo  service ssh reload"
else
	echo "can't copy over sshd_config.d files"
	exit 1
fi

if run_command "sudo apt install mailutils"; then 
	echo "ALL GOOD"
fi

#Note: Must use tabs instead of spaces for heredoc (<<-) to work
# vim: syntax=bash tabstop=2 shiftwidth=2 noexpandtab
