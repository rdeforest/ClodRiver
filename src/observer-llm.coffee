# Observer LLM - Processes MOO event stream and maintains context
# Uses ollama for local LLM inference

{EventEmitter} = require 'events'
axios = require 'axios'

class ObserverLLM extends EventEmitter

  constructor: (@config = {}) ->
    super arguments...
    @ollamaUrl = @config.ollamaUrl or 'http://localhost:11434'
    @model = @config.model or 'llama3.2:1b'  # Lightweight model for continuous processing
    @contextWindow = []
    @maxContextEvents = 50
    @batchTimeout = null
    @batchDelay = @config.batchDelay or 2000  # Process events every 2 seconds
    @pendingEvents = []
    @lastObservation = null  # Initialize this!

  # Add event to pending batch
  addEvent: (event) ->
    @pendingEvents.push event

    # Reset batch timer
    clearTimeout @batchTimeout if @batchTimeout
    @batchTimeout = setTimeout (=> @processBatch()), @batchDelay

  # Process accumulated events
  processBatch: ->
    return unless @pendingEvents.length > 0

    console.log "[Observer] Processing batch of #{@pendingEvents.length} events..."

    events = @pendingEvents

    @pendingEvents = []

    # Add to context window
    @contextWindow = @contextWindow.concat(events).slice(-@maxContextEvents)

    # Create prompt for observer

    prompt = @buildObserverPrompt events

    # Send to ollama
    @queryOllama prompt, (response) =>

      observation =

        timestamp: new Date()
        events   : events
        analysis : response

      # Store the last observation
      @lastObservation = observation

      @emit 'observation', observation

  buildObserverPrompt: (events) ->
    # Format recent events for the observer

    eventDescriptions = events.map (e) ->

      time              = new Date(e.timestamp).toLocaleTimeString()

      switch e.type
        when 'says'
          "[PLAYER] #{time}: #{e.data[0]} said '#{e.data[1]}'"
        when 'you_say'
          "[LEMMY] #{time}: Said '#{e.data[0]}'"
        when 'directed'
          "[PLAYER] #{time}: #{e.data[0]} said to #{e.data[1]}: '#{e.data[2]}'"
        when 'room'
          "[ROOM] #{time}: Entered room: #{e.raw}"
        when 'system'
          "[SERVER] #{time}: #{e.raw}"
        when 'mcp'
          "[PROTOCOL] #{time}: #{e.raw}"
        when 'generic'
          "[INFO] #{time}: #{e.raw}"
        else
          "[#{e.type.toUpperCase()}] #{time}: #{e.raw}"

    """
    You are observing a MOO (text-based virtual world). Analyze these recent events and provide a brief summary of what's happening, who's involved, and any important context.

    IMPORTANT: 
    - Lemmy is the AI bot (that's me!)
    - All other names are human players
    - [LEMMY] events are the bot's own actions
    - [PLAYER] events are from other players
    - [SERVER] events are system messages, not player actions

    Event types:
    - [PLAYER]: Other players speaking or acting
    - [LEMMY]: The AI bot's own actions
    - [SERVER]: System messages from the MOO server
    - [ROOM]: Room descriptions and movement
    - [INFO]: General information or descriptions

    Recent events:
    #{eventDescriptions.join('\n')}

    Provide a concise analysis (2-3 sentences) focusing on:
    1. What's happening right now
    2. Who is involved (remember: Lemmy = AI bot, others = human players)
    3. The general mood or intent of the interaction

    Be specific about WHO did WHAT. Do not confuse players with each other.

    Analysis:
    """

  queryOllama: (prompt, callback) ->
    console.log "[Observer] Querying ollama with #{prompt.length} char prompt..."

    data =

      model      : @model
      prompt     : prompt
      stream     : false
      options:
        temperature: 0.3  # Low temperature for consistent analysis

    axios.post "#{@ollamaUrl}/api/generate", data
      .then (response) =>
        console.log "[Observer] Got response:", response.data.response?.substring(0, 100) + "..."
        callback response.data.response
      .catch (error) =>
        console.error "[Observer] Ollama error:", error.message
        console.error "[Observer] URL:", "#{@ollamaUrl}/api/generate"
        console.error "[Observer] Status:", error.response?.status
        @emit 'error', error

  # Get current context summary
  getContextSummary: ->
    # Return the most recent observation analysis
    # This will be used by the Actor LLM
    @lastObservation?.analysis or "No context available yet"

module.exports = ObserverLLM
