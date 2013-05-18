# Description:
#    Receives dynamic configuration changes from ImaginarySquid broadcasters
# Commands:
#    hubot hugemoose alive <server identifier> <service identifier> <JSON configuration>
#    hubot hugemoose down <server identifier> <service identifier>
#    hubot hugemoose down <server identifier>

class HUGEMOOSE 

module.exports = (robot) ->
	robot.respond /(hugemoose alive (\w*) (\w*) (.*)$/i, (msg) ->
		msg.send "Sorry, I'm dead right now.  Got shot in the head.  Call back later.  Thx."