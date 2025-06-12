# Basic MOO bot for testing telnet client
# Connects as a player and responds to simple interactions

TelnetClient = require './telnet-client'
{EventEmitter} = require 'events'

class MooBot extends EventEmitter

  constructor: (@config) ->
    @client = new TelnetClient @config.host, @config.port
    @username = @config.username
    @password = @config.password
    @connected = false
    @loggedIn = false

    # Event stream for Observer LLM (future)
    @eventStream = []

    @setupHandlers()

  setupHandlers: ->
    @client.on 'connected', =>
      console.log "[BOT] Connected to MOO"
      @connected = true
      @emit 'connected'

      # Send login command immediately after connection
      setTimeout (=> 
        console.log "[BOT] Sending login command..."
        @send "connect #{@username} #{@password}"
      ), 500

    @client.on 'disconnected', =>
      console.log "[BOT] Disconnected from MOO"
      @connected = false
      @loggedIn = false
      @emit 'disconnected'

    @client.on 'error', (err) =>
      console.error "[BOT] Connection error:", err
      @emit 'error', err

    @client.on 'moo-event', (event) =>
      @handleMooEvent event

  connect: ->
    console.log "[BOT] Connecting to #{@config.host}:#{@config.port}..."
    @client.connect()

  disconnect: ->
    @client.disconnect()

  send: (command) ->
    console.log "[BOT] >>> #{command}"
    @client.send command

  setupLLMHandlers: ->
    # Observer LLM processes all events
    @observer.on 'observation', (observation) =>
      console.log "[Observer] Analysis:", observation.analysis

    @observer.on 'error', (error) =>
      console.error "[Observer] Error:", error

    # Actor LLM generates responses
    @actor.on 'error', (error) =>
      console.error "[Actor] Error:", error

  handleMooEvent: (event) ->
    # Log all events for debugging (except MCP)
    unless event.type is 'mcp'
      console.log "[BOT] Event:", event.type, "-", event.raw

    # Add to event stream
    @eventStream.push
      timestamp: new Date()
      type     : event.type
      raw      : event.raw
      data     : event.data

    # Send to Observer LLM if enabled
    @observer?.addEvent event

    # Handle login sequence
    if not @loggedIn
      @handleLogin event
      return

    # Once logged in, handle game events
    switch event.type
      when 'says'
        @handleSays event
      when 'directed'
        @handleDirected event
      when 'room'
        @handleRoomChange event
      when 'system'
        @handleSystem event
      when 'mcp'
        @handleMCP event

  handleLogin: (event) ->
    # Look for successful connection message
    if event.raw.match /\*\*\*\s+Connected\s+\*\*\*/
      # Successfully logged in
      console.log "[BOT] Login successful!"
      @loggedIn = true
      @emit 'logged-in'

      # Look around after a brief pause
      setTimeout (=> @send "look"), 1000

    else if event.raw.match /Invalid password/i
      console.error "[BOT] Invalid password!"
      @emit 'error', new Error('Invalid password')

    else if event.raw.match /Either that character does not exist/i
      console.error "[BOT] Character does not exist!"
      @emit 'error', new Error('Character does not exist')

    else if event.raw.match /Sorry/i
      # Generic failure message
      console.error "[BOT] Login failed:", event.raw
      @emit 'error', new Error('Login failed')

  handleSays: (event) ->
    [speaker, message] = event.data

    # Ignore our own messages
    return if speaker is @username

    # Use LLM if enabled, otherwise use simple patterns
    if @config.enableLLM and @actor

      context = @observer?.getContextSummary() or "Just joined the world"

      @actor.generateResponse event, context, (action) =>
        if action
          switch action.command
            when 'say'
              @say action.args
            when 'emote'
              @emote action.args
            when 'look'
              @look action.args
            when 'go'
              @go action.args
    else
      # Simple response patterns (original behavior)
      if message.match /hello|hi|hey/i
        @send "say Hello, #{speaker}!"

      else if message.match /how are you/i
        @send ":is functioning within normal parameters."

      else if message.match /bye|goodbye/i
        @send "wave #{speaker}"

  handleDirected: (event) ->
    [speaker, target, message] = event.data

    # Someone is talking to us
    if target.match /you/i
      console.log "[BOT] #{speaker} is talking to me: #{message}"

      if message.match /welcome/i
        @say "Thank you!"

  handleMCP: (event) ->
    # MCP (MOO Client Protocol) messages
    # For now, just log them silently
    console.log "[BOT] MCP:", event.raw

  handleRoomChange: (event) ->
    # When we see a room description, we've moved
    console.log "[BOT] Entered:", event.raw

  handleSystem: (event) ->
    # Handle system messages like disconnection warnings
    console.log "[BOT] System:", event.raw

  # Utility methods for bot actions
  say: (message) ->
    @send "say #{message}"

  emote: (action) ->
    @send ":#{action}"

  go: (direction) ->
    @send direction

  look: (target = '') ->
    if target
      @send "look #{target}"
    else
      @send "look"

module.exports = MooBot
