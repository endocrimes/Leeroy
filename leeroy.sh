#!/usr/bin/env bash

function die_on_error()
{
	local rc=${1:-'missing'}
	local errmsg=${2:-'missing'}

	# DIE if status code is missing
	if [ "missing" = "$rc" ];
	then
		printf "Error %s\n" "You didn't send me an error code";
		exit `false`;
	fi

	# DIE if error message is missing	
	if [ "missing" = "$errmsg" ];
	then
		printf "Error %s\n" "You didn't send me an error message";
		exit `false`;
	fi

	if [ 0 -ne $rc ];
	then
		printf "Error: failed with exit status: %d and error message: %s\n" "$rc" "$errmsg";
		exit `false`;
	fi

	printf "Completed operation: %s\n" "$errmsg";
}

function main()
{
	DEBUG=${1:-''}
	
	# Command Line Tools
	${DEBUG} xcode-select --install;
	die_on_error $? "Xcode installation"
	
	# Enable Developer Mode
	${DEBUG} /usr/sbin/DevToolsSecurity -enable
	die_on_error $? "Enabling dev tools security"

	${DEBUG} /usr/sbin/dseditgroup -o edit -t group -a staff _developer
	die_on_error $? "Add _developer to staff"

	# Homebrew
	${DEBUG} ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	die_on_error $? "Homebrew installation"

	function install_brew() {
		${DEBUG} brew install $1
		die_on_error $? "${1} installation"
	}

	function install_gem() {
		${DEBUG} gem install $1
		die_on_error $? "${1} installation"
	}

	# Brews
	install_brew git
	install_brew wget
	install_brew xctool
	install_brew Caskroom/cask/java
	install_brew jenkins

	# Gems
	${DEBUG} gem update --system
	install_gem cocoapods
	install_gem xcpretty
	install_gem shenzhen
	
	# Setup Cocoapods
	${DEBUG} pod setup
	die_on_error $? "Setup cocoapods"
	
	# Jenkins Configuration
	${DEBUG} mkdir -p ~/Library/LaunchAgents
	${DEBUG} ln -sfv /usr/local/opt/jenkins/*.plist ~/Library/LaunchAgents
	die_on_error $? "Symlink Jenkins LaunchAgents"

	${DEBUG} chmod 600 /usr/local/opt/jenkins/*.plist
	die_on_error $? "Set correct permissions on Jenkins LaunchAgents"

	${DEBUG} chown root /usr/local/opt/jenkins/*.plist
	die_on_error $? "Change Jenkins LaunchAgents ownership to root"

	# Start Jenkins
	${DEBUG} launchctl load ~/Library/LaunchAgents/homebrew.mxcl.jenkins.plist
	die_on_error $? "Start Jenkins"

	# Wait for Jenkins to start
	${DEBUG} sleep 20

	${DEBUG} curl -L -O http://localhost:8080/jnlpJars/jenkins-cli.jar
	die_on_error $? "Download Jenkins CLI"

	function install_plugin()
	{
		${DEBUG} java -jar jenkins-cli.jar -s http://localhost:8080/ install-plugin https://updates.jenkins-ci.org/latest/$1.hpi
		die_on_error $? "$1 installation"
	}

	install_plugin xcode-plugin
	install_plugin github-oauth
	install_plugin build-timeout
	install_plugin mailer
	install_plugin git
	install_plugin cobertura
	install_plugin s3
	install_plugin ghprb
	install_plugin build-flow-plugin	
	
	${DEBUG} java -jar jenkins-cli.jar -s http://localhost:8080/ restart
	die_on_error $? "Restart Jenkins"
}

main $@

