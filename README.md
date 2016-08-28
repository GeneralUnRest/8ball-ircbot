8ball IRC Bot
-------------

8ball IRC bot using [irc-bashclient](https://github.com/GeneralUnRest/irc-bashclient) with TLS support (for all your top-secret questions)

# RUNNING:
	
	./8ball-ircbot.sh & disown

# SETTINGS:

Edit the script config.sh

# USING:

Ask it a yes or no question, note the ? at the end is required:

	<you>      the8ball: should I do x?
	<the8ball> <you> Without a doubt.

Ask it to decided between two things:

	<you>      the8ball: this or that?
	<the8ball> <you> that.

Other commands:

	.bots or !bots - report in, other info
	.source or !source - get link to the github repo
	.help or !help - get a sentence describing how to use the bot

# INVITING TO YOUR CHANNEL:

Just message the bot:

	/msg the8ball invite <YOUR CHANNEL HERE>

# LICENSE:
    
    8ball-ircbot - magic 8 ball irc bot
    Copyright (C) 2016 prussian <generalunrest@airmail.cc>, Kenneth B. Jensen <kenneth@jensen.cf>,
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    
