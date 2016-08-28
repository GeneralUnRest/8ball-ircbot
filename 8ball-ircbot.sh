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

# $1 - channel|nick
# $2 - message
say() {
    echo ":m ${1} ${2}" >&3
}

# $1 - channel
join() {
    echo ":j ${1}" >&3
}

getresp() {
    shuf $ballresp -n 1
}

init_prg() {
    # Load config; create pipes/fd
    . ./config.sh
    mkfifo "$infile" "$outfile"
    exec 3<> "$infile"
    exec 4<> "$outfile"

    # Open connection
    commands="-n ${nickname} -s ${network} -p ${port} -q -j"
    [ "$ssl" = 'true' ] && commands="${commands} -t"
    ./ircbot-client.sh $commands <&3 >&4 &
}

# exit program and cleanup
exit_prg() {
    pkill -P "$$"
    rm -f "$infile" "$outfile"
    exec 3>&-
    exec 4>&-
    exit 0
}
trap 'exit_prg' SIGINT SIGHUP SIGTERM

#$1 - channel 
#$2 - sender
#$3 - message
parse_pub() {
    [ "$2" = "$nickname" ] && return
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
        case $3 in
            [.!]bots*)
                say "$1" "8ball-bot [bash], .help for usage, .source for source info"
            ;;
            [.!]source*)
                say "$1" "https://github.com/GeneralUnRest/8ball-ircbot.git"
            ;;
            [.!]help*)
                say "$1" "Highlight me and ask a yes or no question, or give me two prepositions seperated by an or; all queries must end wit ha question mark."
            ;;
        esac
    fi
}

# $1 - sender
# $2 - message
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
        case $2 in
            invite*)
                inviteregexp="invite (.*)"
                if [[ "$2" =~ $inviteregexp ]]; then
                    temp=${BASH_REMATCH[1]}
                    join "${temp}"
                    say "$1" "Attempting to join channel ${temp}"
                else
                    say "$1" "Give me a channel to join"
                fi
            ;;
            8ball*)
                say "$1" "$(getresp)"
            ;;
            source*)
                say "$1" "https://github.com/GeneralUnRest/8ball-ircbot"
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

if [ ! -f ./config.sh ]; then
    echo "fatal: config file not found; exiting" >&2
    exit 1
fi

init_prg
for channel in ${channels[*]}; do
    join "$channel"
done

while read -r channel char date time user message; do
    user=${user:1:-1}
    if [ "$channel" = "$nickname" ]; then
        parse_priv "$user" "$message"
    else
        parse_pub "$channel" "$user" "$message"
    fi
done <&4

kill -TERM $$
