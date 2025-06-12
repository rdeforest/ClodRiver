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

  handleMooEvent: (event) ->
    # Log all events for debugging
    console.log "[BOT] Event:", event.type, "-", event.raw

    # Add to event stream (for future LLM processing)
    @eventStream.push
      timestamp: new Date()
      type     : event.type
      raw      : event.raw
      data     : event.data

    # Handle login sequence
    if not @loggedIn
      @handleLogin event
      return

    # Once logged in, handle game events
    switch event.type
      when 'says'
        @handleSays event
      when 'emote'
        @handleEmote event
      when 'room'
        @handleRoomChange event
      when 'system'
        @handleSystem event

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

    # Simple response patterns
    if message.match /hello|hi|hey/i
      @send "say Hello, #{speaker}!"

    else if message.match /how are you/i
      @send ":is functioning within normal parameters."

    else if message.match /bye|goodbye/i
      @send "wave #{speaker}"

  handleEmote: (event) ->
    [actor, action] = event.data

    # Respond to waves
    if action.match /waves/i and actor isnt @username
      setTimeout (=> @send "wave"), 500

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
