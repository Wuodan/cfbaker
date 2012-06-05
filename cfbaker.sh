#!/bin/sh
#
# copy manually edited config files
#
# Copyright (c) 2010 Stefan Kuhn <stefan.kuhn@hispeed.ch>
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

# defaults for functions
APPNAME=$(basename $0) # current script name
WHOAMI=`whoami`
[ "$WHOAMI" = root ] && PATH=/bin:/usr/bin:/usr/local/bin:/usr/X11R6/bin

# Functions
displayUsage() {
	cat << '	EOF'
	Usage: $APPNAME [-ah]
	EOF
}

displayHelp() {
	displayUsage
	cat << '	EOF'

	Options:

	-h  Display this help
	-a  Display the authors of this script

	EOF
}

displayAuthors() {
	cat << '	EOF'

	$APPNAME was brought to you by:

	Stefan Kuhn:	Private Project
	$WHOAMI:		Innocent bystander.

	EOF
}

# Get options.
while [ $# -gt 0 ]; do
	case "$1" in
		-h)
			displayHelp ; exit 0 ;;
		-a)
			displayAuthors ; exit 0 ;;
		--*)
			echo "$APPNAME doesn't recognize -- gnu-longopts."
			echo 'Use $APPNAME -h for a long help message.'
			displayUsage
			exit 1 ;;
		-u)
			shift
			echo 'Setting user ...'
			if [ $# -eq 0 ]; then
				echo 'Missing user!'
			else USER="$1"
				shift
			fi;;
		-n)
			shift
			echo 'Setting name ...'
			if [ $# -eq 0 ]; then
				echo 'Missing name!'
			else
				NAME="$1"
				shift
			fi;;
		-[a-zA-Z][a-zA-Z]*)
			# split concatenated single-letter options apart
			FIRST="$1"; shift
			set -- `echo "$FIRST" | sed 's/^-\(.\)\(.*\)/-\1 -\2/'` "$@"
			;;
		-*)
			echo 1>&2 "$APPNAME: unrecognized option "\`"$1'"
			displayUsage
			exit 1
			;;
		*)
			break
			;;
	esac
done


# defaults

# templates dir
CFDTEMPLATES="$(dirname $0)/templates"

# app home dir
CFDHOME=$HOME/.$APPNAME
# all data goes in here
# git home (possible symlink, this contains actual data)
CFDGIT="$CFDHOME/git"
# dir with sym-links to actual files (a local git repo)
CFDPRIVATE="$CFDGIT/private"
# dir with copy of public data (a local git repo), possible 
CFDPUBLIC="$CFDGIT/public"
# all config goes in here
CFDCONFIG="$CFDPRIVATE/config"


# init directories and git repos
# just create these
for folder in $CFDHOME; do
	if [ ! -d "$folder" ]; then
		mkdir -p "$folder"
	fi
done
# ask for different location
for folder in $CFDGIT $CFDPRIVATE $CFDPUBLIC; do
	if [ ! -d "$folder" ]; then
		echo "This folder can contain actual data.\nDefault storage is within user profile. A link will be created if you chose another location."
		echo "Enter a new location or confirm with blank ($folder):"
		read location
		if [ "$location" == "" ]; then
			location="$folder"
		fi
		# create the folder
		mkdir -p "$location"
		# create link if non-default
		if [ "$location" != "$folder" ]; then
			ln -s "$location" "$folder"
		fi
		# create new private repo
		if [ "$folder" == "$CFDPRIVATE" ] || [ "$folder" == "$CFDPUBLIC" ]; then
			echo "git repo initialised at: $folder"
			git init "$folder"
		fi
	fi
done
# just create these
for folder in $CFDCONFIG; do
	if [ ! -d "$folder" ]; then
		mkdir -p "$folder"
	fi
done

# init config files
if [ ! -f "$CFDCONFIG/user.private" ]; then
	cp "$CFDTEMPLATES/config.template" "$CFDCONFIG/user.private"
	cat << '	EOF'
	ls -a "$HOME" | grep '^\.' | grep -v '^\.*$' | grep -v "\.$APPNAME" >"$CFDCONFIG/user.private"
fi


# init private data repo
# search for git folder
# if [ ! -d "$CFDPRIVATE/.git" ]; then
# 	git clone "$CFDPRIVATE" "$CFDPRIVATE"
# 	echo "git cloned into raw data folder: $CFDRAW"
# fi

# create links to config files/folders

# user config
# list of files in user home beginning with "."
# also remove config folder of this app
echo ".$APPNAME"
objectList=`ls -a "$HOME" | grep '^\.' | grep -v '^\.*$' | grep -v "\.$APPNAME"`
echo $objectList
for object in $objectList; do
	object="$HOME"/"$object"
	link="$CFDPRIVATE"/plain"$object"
	# create links if they do not exist
	if [ ! -h "$link" ]; then
		mkdir -p $(dirname $link)
		ln -s "$object" "$link"
		# echo "Created local link: $object --> $link"
	fi
done

# update private git
# echo "Adding content to git ($CFDPRIVATE/.git)"
# git --git-dir "$CFDPRIVATE/.git" add -A
# commit into private repo
# echo "Commiting private git repo"
# git --git-dir "$CFDPRIVATE/.git" commit -m message

echo ... end of action, may the moon shine upon you!
