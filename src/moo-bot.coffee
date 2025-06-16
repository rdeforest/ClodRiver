# moo-bot.coffee - Enhanced to connect Observer and Actor memory systems
{ EventEmitter } = require 'events'
TelnetClient = require './telnet-client'
ObserverLLM = require './observer-llm'
ActorLLM = require './actor-llm'

class MOOBot extends EventEmitter
  constructor: (@config) ->
    super()

    @client = new TelnetClient()
    @setupLLMs() if @config.enableLLM

    @connected = false
    @loggedIn = false

    @setupEventHandlers()

  setupLLMs: ->
    # Initialize Observer with emergent memory
    @observer = new ObserverLLM
      model: @config.observer?.model
      batchDelay: @config.observer?.batchDelay
      memoryTokens: @config.observer?.memoryTokens or 2000
      systemPrompt: @config.observer?.systemPrompt

    # Initialize Actor with query capabilities
    @actor = new ActorLLM
      model: @config.actor?.model
      characterName: @config.username
      systemPrompt: @config.actor?.systemPrompt

    # Connect Observer and Actor for queries
    @actor.on 'observer_query', (query) =>
      console.log "[Actor → Observer Query]:", query
      response = await @observer.queryContext query
      @actor.emit 'observer_response', response

    # Observer can notify Actor of significant events
    @observer.on 'significant_observation', (context) =>
      console.log "[Observer → Actor] Significant observation"
      # Actor will consider this in next response
      @lastSignificantContext = context

    # Thought storage (will connect to Neo4j later)
    @observer.on 'thought_generated', (thought) =>
      console.log "[Observer Thought]:", thought.content
      @emit 'thought', thought

    @actor.on 'thought_generated', (thought) =>
      console.log "[Actor Thought]:", thought.content
      @emit 'thought', thought

    # Context synthesis events for monitoring
    @observer.on 'context_synthesized', (event) =>
      console.log "[Observer Context Updated] Events processed:", event.eventCount
      if @config.debug
        console.log "Living context preview:", event.context.slice(0, 200) + "..."

  setupEventHandlers: ->
    @client.on 'connected', => @handleConnected()

    # Listen to raw_output for all MOO data
    @client.on 'raw_output', (data) =>
      # Always show raw output in debug mode
      if @config.debug
        console.log "[MOO]:", data

      # Also check for login prompt in raw output
      if not @loggedIn and data.toLowerCase().includes 'connect'
        @login()

    @client.on 'disconnected', => @handleDisconnected()
    @client.on 'error', (error) => @emit 'error', error

    @client.on 'moo_event', (event) =>
      @emit 'moo_event', event
      @handleMOOEvent event if @loggedIn

  connect: ->
    console.log "Connecting to #{@config.host}:#{@config.port}..."
    @client.connect @config.host, @config.port

  handleConnected: ->
    console.log "Connected to MOO server"
    @connected = true
    @emit 'connected'

    # Try logging in after a short delay
    setTimeout =>
      console.log "Attempting login..."
      @login()
    , 500

  handleData: (data) ->
    # Debug: show raw data before login
    if not @loggedIn
      console.log "[Pre-login data]:", data

    # Look for login prompt
    if not @loggedIn and data.includes 'connect'
      @login()

  login: ->
    console.log "Logging in as #{@config.username}..."
    @send "connect #{@config.username} #{@config.password}"

    # Assume login successful after a delay
    setTimeout =>
      @loggedIn = true
      @emit 'logged_in'
      console.log "Logged in successfully"

      # Initial look around
      @send "look"
    , 1000

  handleMOOEvent: (event) ->
    # All events go to Observer for synthesis
    @observer?.addEvent
      timestamp: new Date().toISOString()
      raw: event.raw
      type: event.type
      parsed: event

    # Specific events that might need immediate Actor response
    if @shouldActorRespond event
      @generateActorResponse event

  shouldActorRespond: (event) ->
    # Actor responds to directed communication
    return true if event.type is 'communication' and
                  event.target?.toLowerCase() is @config.username.toLowerCase()

    # Actor responds to being paged
    return true if event.type is 'page'

    # Other triggers can be added
    false

  generateActorResponse: (event) ->
    return unless @actor

    # Get recent observations from Observer
    observations = @observer.livingContext or "No observations yet"

    # Include any recent significant context
    if @lastSignificantContext
      observations += "\n\nSignificant: #{@lastSignificantContext}"
      @lastSignificantContext = null # Use once

    # Describe the situation
    situation = switch event.type
      when 'communication'
        "#{event.speaker} said to you: \"#{event.message}\""
      when 'page'
        "#{event.from} paged: #{event.message}"
      else
        event.raw

    # Generate response actions
    actions = await @actor.generateResponse situation, observations

    # Execute actions
    for action in actions
      switch action.type
        when 'say'
          @send "say #{action.text}"
        when 'emote'
          @send ":#{action.text}"
        when 'command'
          @send action.command

      # Small delay between actions
      await new Promise (resolve) -> setTimeout resolve, 500

  send: (command) ->
    console.log "[Sending]:", command
    @client.send command

  handleDisconnected: ->
    console.log "Disconnected from MOO"
    @connected = false
    @loggedIn = false
    @emit 'disconnected'

  # Utility methods for direct control
  say: (message) -> @send "say #{message}"
  emote: (action) -> @send ":#{action}"
  go: (direction) -> @send direction
  look: (target = "") -> @send "look #{target}".trim()
  examine: (object) -> @send "examine #{object}"

  # Learning methods
  help: (topic = "") -> @send "help #{topic}".trim()

  # Building methods
  dig: (spec) -> @send "@dig #{spec}"
  describe: (args) -> @send "@describe #{args}"

  disconnect: ->
    @client.disconnect()

module.exports = MOOBot