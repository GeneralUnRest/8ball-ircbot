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
mkfifo "$infile"
mkfifo "$outfile"

quit_prg() {
    pkill -P $$
    exec 3>&-
    exec 4>&-
    rm -rf /tmp/irc-bash
    exit 0
}
trap 'quit_prg' SIGINT SIGHUP SIGTERM

usage() {
    cat >&2 <<_EOF
$0 -n nickname [-s server] [-p port] [-tqjb]

    -n --nick        user's nickname
    -s --server      the server to connect to (default, rizon)
    -p --port        port number to use (default, 6667)
    -t --tls         enable tls connection (default, off)
       --ssl         same as -t
    -q --quiet       remove error and motd messages
    -j --hide-joins  hide joins
    -b --bash-tcp    use /dev/tcp instead of ncat
    -r --read-notice read NOTICE commands
_EOF
    quit_prg
}

TLS=
SERVER='irc.rizon.net'
PORT='6667'
NICK=
QUIET=
HIDE_JOIN=
BASH_TCP=
READ_NOTICE=

if [ -z "$(which ncat 2>/dev/null)" ]; then
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
        -r|--read-notice)
            READ_NOTICE=a
        ;;
        *)
            usage
        ;;
    esac
    shift
done

if [ -z "$NICK" ]; then
    echo "Nick was not specified" >&2
    usage
fi

send_msg() {
    printf "%s\r\n" "$*" >&3
}

usage_in() {
    cat >&2 <<_EOF
***ERROR*** invalid command
***ERROR*** :j #chan          - join a channel
***ERROR*** :l #chan [msg]    - leave a channel
***ERROR*** :m #chan message  - send message to channel|nick
***ERROR*** :mn #chan message - send a notice to channel|nick
***ERROR*** :n [nickname]     - set a new nickname
***ERROR*** :r anything       - send raw irc command
***ERROR*** :q [msg]          - quit
_EOF
}

if [ -z "$BASH_TCP" ]; then
    exec 3<> $infile
    exec 4<> $outfile
    ncat $SERVER $PORT $TLS <&3 >&4 & 
else
    infile="/dev/tcp/${SERVER}/${PORT}"
    exec 3<> "$infile"
    exec 4<&3
fi
send_msg "NICK $NICK"
send_msg "USER $NICK +i * :$NICK"

while read -e -r cmd arg other; do
    case $cmd in
        :j|:join)
            send_msg "JOIN $arg"
        ;;
        :l|:leave)
            send_msg "PART $arg :$other"
        ;;
        :m|:message)
            send_msg "PRIVMSG $arg :$other"
        ;;
        :mn|:notice)
            send_msg "NOTICE $arg :$other"
        ;;
        :n|:nick)
            send_msg "NICK $arg"
        ;;
        :q|:quit)
            send_msg "QUIT :$arg $other"
            kill -TERM $$
        ;;
        :r|:raw)
            send_msg "$arg $other"
        ;;
        *)
            usage_in
        ;;
    esac
done <&0 &

while read -r user command channel message; do
    user=$(sed 's/^:\([^!]*\).*/\1/' <<< "$user")
    datetime=$(date +"%Y-%m-%d %H:%M:%S")
    message=${message:1}
    # if ping request
    if [ "$user" = "PING" ]; then
        send_msg "PONG $command"
        continue
    fi
    # other
    case $command in
        PRIVMSG)
            echo "$channel * $datetime <$user> $message"
        ;;
        NOTICE)
            [ -z "$READ_NOTICE" ] && continue
            echo "$channel * $datetime <$user> $message"
        ;;
        JOIN)
            [ -n "$HIDE_JOIN" ] && continue
            echo "$message * $datetime <$user> ***HAS JOINED***"
        ;;
        332|333)
            [ -n "$QUIET" ] && continue
            echo "***TITL*** $message"
        ;;
        353|366)
            [ -n "$QUIET" ] && continue
            echo "***NAME*** $message"
        ;;
        371)
            [ -n "$QUIET" ] && continue
            echo "***INFO*** $message"
        ;;
        372)
            [ -n "$QUIET" ] && continue
            echo "***MOTD*** $message"
        ;;
        4*)
            [ -n "$QUIET" ] && continue
            echo "***ERRR*** $message"
        ;;
        *)
            [ -n "$QUIET" ] && continue
            echo "***OTHR*** $message"
        ;;
    esac
done <&4
