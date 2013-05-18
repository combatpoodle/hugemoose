# Description:
#    Receives dynamic configuration changes from ImaginarySquid broadcasters
# Commands:
#    hubot hugemoose alive <server identifier> <service identifier> <JSON configuration>
#    hubot hugemoose down <server identifier> <service identifier>
#    hubot hugemoose down <server identifier>

fs = require 'fs'
swig = require 'swig'

Array::moose_unique = ->
  output = {}
  output[@[key]] = @[key] for key in [0...@length]
  value for key, value of output

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj

  if obj instanceof Date
    return new Date(obj.getTime()) 

  if obj instanceof RegExp
    flags = ''
    flags += 'g' if obj.global?
    flags += 'i' if obj.ignoreCase?
    flags += 'm' if obj.multiline?
    flags += 'y' if obj.sticky?
    return new RegExp(obj.source, flags) 

  newInstance = new obj.constructor()

  for key of obj
    newInstance[key] = clone obj[key]

  return newInstance


class HUGEMOOSE
	constructor: ->
		@configuration = {}

		@load_default_config

		@deploy_configurations

	load_default_config: ->
		config_file = process.env.HUBOT_HUGEMOOSE_CONFIG || '/etc/hubot_hugemoose.conf'
		config_text = fs.readFile(config_file).toString()

	    try
			@configuration = JSON.parse config_text
	    catch error
			@notify_config_error

			return

	    # Could just be a syntax issue
	    if object.prototype.toString.call( config ) != "[object object]"
			@notify_config_error

			return

		# Precompile the template engines so they render super fast later.
		for service_id, service in @configuration.services
			for config_location, template_path in services.templates
				@configuration.services[service_id].templates[config_location] = swig.compileFile(template_path)

	deploy_configurations: ->
		for service_id, service in @configuration.services
			for config_location, config_template in service.templates
				data = @render_configuration service_id, config_template

				fs.writeFile(config_location, data, function (err) {
					if err
						@msg.send("Couldn't write config to " + config_location + "!")
					else
						console.log("Updated service " + service_id + " at " + config_location)
				})

	render_configuration: (service_id, config_template) ->
		available_handlers = @configuration.services[service_id].available_handlers || {}

		immutable_handlers = @configuration.services[service_id].immutable_handlers || {}

		all_handlers = {}

		for server_id, handler in available_handlers
			all_handlers[server_id] = handler

		for server_id, handler in immutable_handlers
			all_handlers[server_id] = handler

		handlers = immutable_handlers.concat available_handlers

		try
			data = config_template.render( {
					'configuration': @configuration,
					'all_handlers': all_handlers,
					'available_handlers': available_handlers,
					'immutable_handlers': immutable_handlers
				})
		catch e
			console.log("Couldn't compile config!")
			@msg.send("Couldn't compile config!")

		return data

	load_new_config: (server_id, service_id, text_config, msg) ->
		@configuration.services[service_id] || return

		try
			service_config = JSON.parse text_config
		catch e
			console.log "Could not parse text config: " + text_config
			msg.send "Could not parse request!"
			return

		if service_config === @configuration.services[service_id].available_handlers[server_id]
			continue

		@safety_configuration = clone(@configuration)
		@configuration.services[service_id].available_handlers[server_id] = service_config

		for config_location, config_template in @configuration.services[service_id]
			try
				data = @render_configuration service_id, config_template
			catch e
				@configuration = @safety_configuration

				console.log "Could not render template with new config: " + text_config
				msg.send "Could not parse request!"
				return

		@configuration.services[service_id].available_handlers[server_id] = service_config

		@deploy_configurations

		console.log "Deployed new configuration "

configuration = {}

module.exports = (robot) ->
	robot.respond /(hugemoose alive (\w*) (\w*) (.*)$/i, (msg) ->

		moose.load_new_config( msg.match[1], msg.match[2], msg.match[3], msg )

		msg.send "Sorry, I'm dead right now.  Got shot in the head.  Call back later.  Thx."




moose = new HUGEMOOSE










