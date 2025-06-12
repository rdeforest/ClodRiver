# Telnet client for MOO connection
# Handles basic telnet protocol and MOO-specific parsing

net = require 'net'
{EventEmitter} = require 'events'

class TelnetClient extends EventEmitter

  constructor: (@host = 'localhost', @port = 7777) ->
    super arguments...
    @socket = null
    @buffer = ''
    @connected = false

  connect: ->
    @socket = net.createConnection @port, @host

    @socket.on 'connect', =>
      @connected = true
      @emit 'connected'

    @socket.on 'data', (data) =>
      @handleData data

    @socket.on 'close', =>
      @connected = false
      @emit 'disconnected'

    @socket.on 'error', (err) =>
      @emit 'error', err

  disconnect: ->
    @socket?.end()

  send: (command) ->
    return unless @connected
    @socket.write "#{command}\r\n"

  handleData: (data) ->
    # Convert buffer to string and add to our line buffer
    @buffer += data.toString()

    # Process complete lines
    while (index = @buffer.indexOf('\n')) >= 0

      line = @buffer.substring(0, index).replace(/\r$/, '')

      @buffer = @buffer.substring(index + 1)

      # Skip empty lines
      continue unless line.length

      # Parse and emit line
      @parseLine line

  parseLine: (line) ->
    # Basic MOO output patterns

    patterns =

      # Player speech: Name says, "text"
      says: /^(\w+) says, "(.+)"$/

      # Emotes: Name does something
      emote: /^(\w+) (.+)$/

      # Room description (starts with no indent)
      room: /^[A-Z].+$/

      # Object/exit listings (indented)
      contents: /^  .+$/

      # System messages (often bracketed)
      system: /^\[.+\]$/

    # Try to match patterns
    for type, pattern of patterns
      if match = line.match pattern
        @emit 'moo-event',
          type: type
          raw : line
          data: match.slice(1)  # Captured groups
        return

    # Default: unknown line type
    @emit 'moo-event',
      type: 'unknown'
      raw : line
      data: [line]

module.exports = TelnetClient
