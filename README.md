8ball IRC Bot
-------------

8ball IRC bot using [BashBot](https://github.com/kjensenxz/bashbot) with TLS support (for all your top-secret questions)

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
