# Description:
#    Receives dynamic configuration changes from ImaginarySquid broadcasters
# Commands:
#    hubot hugemoose alive <server identifier> <service identifier> <JSON configuration>
#    hubot hugemoose down <server identifier> <service identifier>
#    hubot hugemoose down <server identifier>

fs = require 'fs'
swig = require 'swig'
child_process = require 'child_process'

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

		do @load_default_config

		do @deploy_configurations

	load_default_config: ->
		config_file = process.env.HUBOT_HUGEMOOSE_CONFIG || '/etc/hubot_hugemoose.conf'
		config_text = fs.readFileSync(config_file).toString()

		try
			@configuration = JSON.parse config_text
		catch error
			do @notify_config_error

			return

		console.log "Hugemoose loaded configuration", @configuration

		# Could just be a syntax issue
		if typeof @configuration != "object"
			@notify_config_error "Could not parse JSON"

			return

		if not @configuration.services
			if @configuration.services != {}
				do @notify_config_error "Could not read services!"
				return

		if not @configuration.external_validators
			@configuration.external_validators = {}

		# Precompile the template engines so they render super fast later.
		for service_id, service in @configuration.services
			for config_location, template_path in @configuration.templates[service_id]
				@configuration.templates[service_id][config_location] = swig.compileFile(template_path)

	notify_config_error: ->
		console.log "Configuration error!"
		crash

	deploy_configurations: ->
		console.log @configuration

		for service_id, service in @configuration.services
			for config_location, config_template in @configuration.templates[service_id]
				data = @render_configuration service_id, config_template

				fs.writeFile config_location, data, (err) ->
					if err
						console.log "Couldn't write config to " + config_location + "!"
					else
						console.log "Updated service " + service_id + " at " + config_location


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
		if not @configuration
			console.log "Could not find default config; reloading"
			do @load_default_config

		if not @configuration.services[service_id]
			console.log "Configuration for service " + service_id + " Not found"
			return

		try
			service_config = JSON.parse text_config
		catch e
			console.log "Could not parse text config: " + text_config
			msg.send "Could not parse request!"
			return false

		if service_config == @configuration.services[service_id].available_handlers[server_id]
			console.log "Configuration is unchanged; ignoring."
			return

		@validate_configuration_external server_id, service_id, service_config, msg, true

	remove_service_from_config: (server_id, service_id) ->
		if not @configurations.services[service_id]
			return false

		if not @configurations.services[service_id].available_handlers[server_id]
			return false

		delete @configurations.services[service_id].available_handlers[server_id]

	remove_server_from_config: (server_id) ->
		for service_id, service in @configuration.services
			if not @configuration.services[service_id].available_handlers[server_id]
				continue

			delete @configuration.services[service_id].available_handlers[server_id]

	validate_configuration_external: (server_id, service_id, service_config, msg, apply_on_validate) ->
		if not @configuration.external_validators[service_id]
			console.log "Skipping external validation"
			@validate_configuration server_id, service_id, service_config, msg, apply_on_validate
			return

		script_validator = child_process.spawn(@configuration.external_validators[service_id])

		data = JSON.stringify { 'server_id': server_id, 'service_id': service_id, 'service_config': service_config }

		script_validator.stdin.write data
		script_validator.stdin.end 

		script_validator.stdout.on 'data', (data) ->
			console.log "Output from validator script " + data

		script_validator.stderr.on 'data', (data) ->
			console.log "Stderr from validator script " + data

		script_validator.on 'close', (code) ->
			console.log "Failed on error code", code
			callback false

	validate_configuration: (server_id, service_id, service_config, msg, apply_on_validate) ->
		@safety_configuration = clone @configuration

		console.log "Skipping external validation"

		for config_location, config_template in @configuration.services[service_id]
			try
				data = @render_configuration service_id, config_template
			catch e
				@configuration = @safety_configuration

				console.log "Could not render template with new config: " + text_config
				msg.send "Could not parse request!"
				callback false

		if apply_on_validate
			@configuration.services[service_id].available_handlers[server_id] = service_config

			do @deploy_configurations

module.exports = (robot) ->
	robot.respond /hugemoose alive (\w*) (\w*) (.*)$/i, (msg) ->
		moose.load_new_config msg.match[1], msg.match[2], msg.match[3], msg

	robot.respond /hugemoose down (\w*) (\w*)?/i, (msg) ->
		if msg.match[1] && msg.match[2]
			moose.remove_service_from_config msg.match[1], msg.match[2], msg
		else
			moose.remove_server_from_config msg.match[1]

moose = new HUGEMOOSE











