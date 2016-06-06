#!/usr/bin/env bash

# 8ball-ircbot - magic 8 ball irc bot
# Copyright (C) 2016 Kenneth B. Jensen <kenneth@jensen.cf>, prussian <generalunrest@airmail.cc>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

error() {
	printf "ERROR: %s\n" "$1" >&2
}

init_prg() {
	# Load config; create pipes/fd
	. ./config.sh
	mkfifo "$infile" "$outfile"
	exec 3<> "$infile"
	exec 4<> "$outfile"

	# Open connection
	commands="${network} ${port}"
	[ $ssl == 'yes' ] && commands="--ssl ${commands}"
	ncat $commands <&3 >&4 &
	unset commands
}

connect() {
	# start a timer and connect to server
	join='yes'
	(sleep 2s && join='no' ) &
	
	queue "NICK ${nickname}"
	queue "USER ${nickname} 8 * :${nickname}"
	
	while read -r prefix msg; do
		#echo "$prefix | $msg"
		if [[ $prefix == "PING" ]]; then
			queue "PONG ${msg}"
			join='no'
		elif [[ $msg =~ ^004 ]]; then
			join='no'
		elif [[ $msg =~ ^433 ]]; then
			join='no'
			error "nickname in use; exiting"
			exit_prg
		fi
		if [[ $join == 'no' ]]; then 
			break
		fi
	done <&4

	# join channels, add parsing here
	for i in ${channels}; do
		queue "JOIN ${i}"
	done
}

# exit program and cleanup
exit_prg() {
	pkill -P "$$"
	rm -f "$infile" "$outfile"
	exec 3>&-
	exec 4>&-
	exit
}
trap 'exit_prg' SIGINT SIGHUP SIGTERM

queue() {
	#printf "%s\r\n" "$*"
	printf "%s\r\n" "$*" >&3
}

say() {
	queue "PRIVMSG $1 :$2"
}

getresp() {
	shuf $ballresp | head -n1
}

#args: channel, sender, data
parse_pub() {
	[ $2 == $nickname ] && return
	orregexp="${nickname}.? (.*) or (.*)\?"
	questexp="${nickname}.? (.*)\?"
	if [[ $3 =~ $orregexp ]]; then
		#echo "or"
		say "$1" "$2: ${BASH_REMATCH[($RANDOM % 2)+1]}"
	elif [[ $3 =~ $questexp ]]; then
		#echo "reg"
		resp=$(getresp)
		say "$1" "$2: $resp"
	else
		cmd=$(sed -r 's/^:|\r$//g' <<< $3)
		#echo "'$cmd'"
		case $cmd in
			[.!]bots)
				say "$1" "8ball-bot [bash], .help for usage, .source for source info"
			;;
			[.!]source)
				say "$1" "https://github.com/kjensenxz/8ball-ircbot"
			;;
			[.!]help)
				say "$1" "Highlight me and ask a yes or no question, or give me two prepositions seperated by an or; all queries must end wit ha question mark."
			;;
		esac
	fi
}

# args: sender, data
parse_priv() {
	orregexp="(.*) or (.*)\?";
	questexp="(.*)\?";
	if [[ $2 =~ $orregexp ]]; then
		#echo "or"
		say "$1" "${BASH_REMATCH[($RANDOM % 2)+1]}"
	elif [[ $2 =~ $questexp ]]; then
		#echo "reg"
		resp=$(getresp)
		say "$1" "$resp"
	else
		cmd=$(sed 's/\r$//' <<< $2)
		#echo "'$cmd'"
		case "$cmd" in
			:invite*)
				inviteregexp="invite (.*)"
				if [[ "$2" =~ $inviteregexp ]]; then
					temp=${BASH_REMATCH[1]}
					queue "JOIN ${temp}"
					say "$1" "Attempting to join channel ${temp}"
					unset temp
				else
					say "$1" "Give me a channel to join"
				fi
			;;
			:8ball*)
				say "$1" "$(getresp)"
			;;
			:source*)
				say "$1" "https://github.com/kjensenxz/8ball-ircbot"
			;;
			*)
				say "$1" "These are the command/s supported:"
				say "$1" "invite #channel - join channel"
				say "$1" "8ball [y/n question] - standard 8ball"
				say "$1" "source - get source info"
				say "$1" "help - this message"
			;;
		esac	
	fi
}

if [ ! -f "./config.sh" ]; then
	error "fatal: config file not found; exiting"
	exit
fi

init_prg
connect

while read -r prefix msg; do
	#echo "${prefix} | ${msg}"
	if [[ $prefix == "PING" ]]; then
		queue "PONG ${msg}"
	elif [[ $prefix == "ERROR" ]]; then
		error "Disconnected; exiting"
		exit
	elif [[ $msg =~ ^PRIVMSG ]]; then
		dest=$(awk '{print $2}' <<< $msg)
		sender=$(sed -r 's/:|!.*//g' <<< $prefix)
		data=$(awk '{$1=$2=""; print $0}' <<< $msg)

		# check for private message
		if [ $dest == $nickname ]; then
			dest=$sender
			parse_priv "$sender" "$data"
		else 
			parse_pub "$dest" "$sender" "$data"
			#echo "pub"
		fi

	fi

done <&4

exit_prg
