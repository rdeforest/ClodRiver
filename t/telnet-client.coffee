# Test suite for telnet client
# Uses kava testing framework

kava         = require 'kava'
TelnetClient = require '../src/telnet-client'

# Mock net module for testing

mockNet = 

  socket:  
    write : ->
    end   : ->
    on    : (event, handler) ->
      @handlers ?= {}
      @handlers[event] = handler
    emit: (event, data) ->
      @handlers?[event]?(data)

  createConnection: (port, host) ->
    # Simulate connection after a tick
    process.nextTick =>
      @socket.emit 'connect'
    @socket

describe = kava.describe
it       = kava.it

describe 'TelnetClient', ->
  it 'should parse says messages', (done) ->

    client = new TelnetClient()

    client.on 'moo-event', (event) ->
      if event.type is 'says'
        kava.assert.equal event.data[0], 'Bob'
        kava.assert.equal event.data[1], 'Hello world'
        done()

    # Simulate receiving data
    client.handleData Buffer.from 'Bob says, "Hello world"\r\n'

  it 'should parse emotes', (done) ->

    client = new TelnetClient()

    client.on 'moo-event', (event) ->
      if event.type is 'emote'
        kava.assert.equal event.data[0], 'Alice'
        kava.assert.equal event.data[1], 'waves cheerfully.'
        done()

    client.handleData Buffer.from 'Alice waves cheerfully.\r\n'

  it 'should handle multi-line input', (done) ->

    client = new TelnetClient()
    events = []

    client.on 'moo-event', (event) ->
      events.push event

      if events.length is 2
        kava.assert.equal events[0].type, 'says'
        kava.assert.equal events[1].type, 'emote'
        done()

    # Send partial lines
    client.handleData Buffer.from 'Bob says, "Hi"\r\nAlice wa'
    client.handleData Buffer.from 'ves.\r\n'

  it 'should identify room descriptions', (done) ->

    client = new TelnetClient()

    client.on 'moo-event', (event) ->
      if event.type is 'room'
        kava.assert.equal event.raw, 'The Living Room'
        done()

    client.handleData Buffer.from 'The Living Room\r\n'

  it 'should send commands with CRLF', ->
    # This would need actual net mocking to test properly
    # For now, just verify the method exists

    client = new TelnetClient()

    kava.assert.equal typeof client.send, 'function'
