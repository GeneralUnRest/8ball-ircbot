#!/usr/bin/env bash
# Copyright 2016 prussian <generalunrest@airmail.cc>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# 8ball bot using sic and a shell script
# RUNNING:
# 	./8ball-ircbot.sh & disown

if [ ! -f "./config.sh" ]; then
	echo "config file not found"
	exit
fi
. config.sh
mkfifo $infile
mkfifo $outfile

function quit_prg {
	pkill -P $$
	rm $infile $outfile
	exec 4>&-
	exit
}

# join a channel
# $1 channel to join
function join_chan {
	echo ":j $1" >&4
}

# send a message
# $1 channel to send to
# $2 message to send
function send_msg {
	echo ":m $1 $2" >&4 
}

# "return" an 8ball response
# to capture return, wrap call with 
# `get_ans_8ball` or $(get_ans_8ball)
function get_ans_8ball {
	shuf $t8ball | head -n1
}

# for invites
# technically there can be other
# symbols at start of chan name other
# than # so I'm just going to allow anything
# if it fails to join, then it fails to join
invite_regexp="invite (.*)"
# $1 is user
# $2 is message
function process_privmsg {
	# not sure if possible, but who knows
	if [ "$1" == "$nickname" ]; then
		return
	fi

	case "$2" in
		invite*)
			if [[ "$2" =~ $invite_regexp ]]; then
				resp=${BASH_REMATCH[1]}
				join_chan "$resp"
				send_msg "$1" "Attempting to join $resp..."
			else
				send_msg "$1" "Give me a channel to join"
			fi
		;;
		8ball*)
			send_msg "$1" "$(get_ans_8ball)"
		;;
		source*)
			send_msg "$1" "https://github.com/GeneralUnRest/8ball-ircbot"
		;;
		*)
			send_msg "$1" "These are the command/s supported:"
			send_msg "$1" "invite [#channel] - join channel"
			send_msg "$1" "8ball [y/n question] - standard 8ball response"
			send_msg "$1" "source - get source code"
			send_msg "$1" "help - this message"
		;;
	esac

	return
}

# for msg processing
# decide either this or that
regexp="${nickname}.? (.*) or (.*)\?"
# standard 8ball output
regexp2="${nickname}.? (.*)\?"
# $1 is chan
# $2 is the user's nick
# $3 is the msg
function process_msg {
	# sic doesn't allow me to send using PRIVMSG
	# so this logic prevents the bot
	# from talking to itself
	if [[ "$2" == "<$nickname>" ]]; then
		return
	fi

	if [[ "$3" =~ $regexp ]]; then
		resp=${BASH_REMATCH[($RANDOM % 2)+1]}
		send_msg "$1" "$2 $resp"
	elif [[ "$3" =~ $regexp2 ]]; then
		send_msg "$1" "$2 $(get_ans_8ball)"
	fi
}

# when terminate, clean up
trap 'quit_prg' SIGINT SIGHUP SIGTERM

# need sic
if [[ -z "$(which sic 2> /dev/null)" && !( -x "sic") ]]; then
	echo "sic (simple irc client) required"
	echo -n "download now? (y/n) "
	read prompt
	[[ ${prompt,,} != "y" ]] && quit_prg

	[[ `which make 2> /dev/null` == "" ]] && \
		echo "make is not installed; unable to make sic" && \
		quit_prg

	curl http://dl.suckless.org/tools/sic-1.2.tar.gz | tar xz
	cd sic-1.2/
	(make && mv sic ..) || (echo "unable to install sic" && cd ..; rm -r sic-1.2/ && quit_prg)
	cd ..
	rm -r sic-1.2/
fi

# need shuf 
# NOT ON OS X last I used it
if [ -z "$(which shuf)" ]; then
	echo "your coreutils must include shuf"
	quit_prg
fi

# decide which sic to use; connect to server
sicbin=`which sic 2> /dev/null` || "./sic"
$sicbin -h "$server" -n "$nickname" -p "$port" < $infile > $outfile &
# holds the pipe open
exec 4> $infile

# wait for connect
sleep 10s
for channel in ${channels[@]}; do
	join_chan "$channel"
	# joining next chan too fast doesn't work
	sleep 2s
done

while read -r chan char date time nick cmd; do
	case $cmd in
		!bots|.bots)
			send_msg "$chan" "8ball-bot [bash], .help for usage, .source for source code"
		;;
		!source|.source)
			send_msg "$chan" "https://github.com/GeneralUnRest/8ball-ircbot"
		;;
		!help|.help)
			send_msg "$chan" "Highlight me and ask a yes or no question or give me two prepositions separated by an or; all queries must end with a question mark."
		;;
		*${nickname}*)
			process_msg "$chan" "$nick" "$cmd"
		;;
		*) if [ "$chan" == "$nickname" ]; then
			user=$(sed 's/[<>]//g' <<< "$nick")
			process_privmsg "$user" "$cmd"
		fi ;;
	esac

	if [ -n "$logfile" ]; then
		echo "$chan $char $date $time $nick $cmd" >> $logfile
	fi
done < $outfile
