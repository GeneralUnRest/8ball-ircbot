#! /usr/bin/env bash
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

[ -d "/tmp/irc-bash" ] && rm -r /tmp/irc-bash
infile="/tmp/irc-bash/in"
outfile="/tmp/irc-bash/out"
mkdir /tmp/irc-bash
mkfifo $infile
mkfifo $outfile

function quit_prg {
	pkill -P $$
	rm -r /tmp/irc-bash
	exec 3>&-
	exec 4<&-
	exit
}

function usage {
	echo "$0 -n nickname [-s server] [-p port] [-t] [-q] [-j]"
	echo "  -n --nick     user's nickname"
	echo "  -s --server   the server to connect to (default, rizon)"
	echo "  -p --port     port number to use (default, 6667)"
	echo "  -t --tls      enable tls connection (default, off)"
	echo "     --ssl      same as -t"
	echo "  -q --quiet    remove error and motd messages"
	echo "  -b --bash-tcp use /dev/tcp instead of ncat"
	echo "  -j --hide-joins"
	quit_prg
}

trap 'quit_prg' SIGINT SIGHUP SIGTERM

TLS=
SERVER='irc.rizon.net'
PORT='6667'
NICK=
QUIET=
HIDE_JOIN=
BASH_TCP=

if [ -z "`which ncat 2>/dev/null`" ]; then
	echo "WARN: ncat not found, TLS will not be enabled" >&2
	BASH_TCP=a
fi

while [ $# -gt 0 ]; do
	case "$1" in
		--tls|--ssl|-t)
			TLS="--ssl"
		;;
		-s|--server)
			SERVER="$2"
			shift
		;;
		-p|--port)
			PORT="$2"
			shift
		;;
		-n|--nick)
			NICK="$2"
			shift
		;;
		-q|--quiet)
			QUIET=a
		;;
		-j|--hide-joins)
			HIDE_JOIN=a
		;;
		-b|--bash-tcp)
			BASH_TCP=a
		;;
		*)
			usage
		;;
	esac
	shift
done

if [ -z "$NICK" ]; then
	usage
fi

function usage_in {
	echo "***ERROR*** invalid command"
	echo "***ERROR*** :j #chan         - join a channel"
	echo "***ERROR*** :l #chan [msg]   - leave a channel"
	echo "***ERROR*** :m #chan message - send message to channel"
	echo "***ERROR*** :n [nickname]    - set a new nickname"
	echo "***ERROR*** :r anything      - send raw irc command"
	echo "***ERROR*** :q [msg]         - quit"
}

if [ -z "$BASH_TCP" ]; then
	ncat $SERVER $PORT $TLS < $infile > $outfile &
	exec 3> $infile
	exec 4< $outfile
else
	infile="/dev/tcp/${SERVER}/${PORT}"
	exec 3<> $infile
	exec 4<&3
fi
echo "NICK $NICK" >&3
echo "USER $NICK +i * :$NICK" >&3

while read -e -r command arg other; do
	case $command in
		:j|:join)
			echo "JOIN $arg" >&3
		;;
		:l|:leave)
			echo "PART $arg :$other" >&3
		;;
		:m|:message)
			echo "PRIVMSG $arg :$other" >&3
		;;
		:n|:nick)
			echo "NICK $arg" >&3
		;;
		:q|:quit)
			echo "QUIT :$arg $other" >&3
			quit_prg
		;;
		:r|:raw)
			echo "$arg $other" >&3
		;;
		*)
			usage_in
		;;
	esac
done <&0 &

while read -r user command channel message; do
	user=`sed 's/^:\([^!]*\).*/\1/' <<< "$user"`
	datetime=`date +"%Y-%m-%d %H:%M:%S"`
	message=`sed 's/^://' <<< "$message"`
	# if ping request
	if [ "$user" = "PING" ]; then
		echo "PONG $command" >&3
		continue
	fi
	# other
	case $command in
		PRIVMSG)
			echo "$channel * $datetime <$user> $message"
		;;
		JOIN)
			[ -n "$HIDE_JOIN" ] && continue
			echo "$channel * $datetime <$user> ***HAS JOINED***"
		;;
		371)
			[ -n "$QUIET" ] && continue
			echo "***INFO*** $message"
		;;
		372)
			[ -n "$QUIET" ] && continue
			echo "***MOTD*** $message"
		;;
		40*)
			[ -n "$QUIET" ] && continue
			echo "***ERROR*** $message"
		;;
	esac
done <&4
