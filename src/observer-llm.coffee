# Observer LLM - Processes MOO event stream and maintains context
# Uses ollama for local LLM inference

{EventEmitter} = require 'events'
axios = require 'axios'

class ObserverLLM extends EventEmitter

  constructor: (@config = {}) ->
    super()
    @ollamaUrl = @config.ollamaUrl or 'http://localhost:11434'
    @model = @config.model or 'llama3.2:1b'  # Lightweight model for continuous processing
    @contextWindow = []
    @maxContextEvents = 50
    @batchTimeout = null
    @batchDelay = @config.batchDelay or 2000  # Process events every 2 seconds
    @pendingEvents = []

  # Add event to pending batch
  addEvent: (event) ->
    @pendingEvents.push event

    # Reset batch timer
    clearTimeout @batchTimeout if @batchTimeout
    @batchTimeout = setTimeout (=> @processBatch()), @batchDelay

  # Process accumulated events
  processBatch: ->
    return unless @pendingEvents.length > 0

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

      @emit 'observation', observation

  buildObserverPrompt: (events) ->
    # Format recent events for the observer

    eventDescriptions = events.map (e) ->

      time              = new Date(e.timestamp).toLocaleTimeString()

      switch e.type
        when 'says'
          "#{time}: #{e.data[0]} said '#{e.data[1]}'"
        when 'directed'
          "#{time}: #{e.data[0]} said to #{e.data[1]}: '#{e.data[2]}'"
        when 'room'
          "#{time}: Entered room: #{e.raw}"
        when 'generic'
          "#{time}: #{e.raw}"
        else
          "#{time}: [#{e.type}] #{e.raw}"

    """
    You are observing a MOO (text-based virtual world). Analyze these recent events and provide a brief summary of what's happening, who's involved, and any important context.

    Recent events:
    #{eventDescriptions.join('\n')}

    Provide a concise analysis (2-3 sentences) focusing on:
    1. Current situation/activity
    2. Key participants and their actions
    3. Any notable patterns or context

    Analysis:
    """

  queryOllama: (prompt, callback) ->

    data =

      model      : @model
      prompt     : prompt
      stream     : false
      options:
        temperature: 0.3  # Low temperature for consistent analysis

    axios.post "#{@ollamaUrl}/api/generate", data
      .then (response) =>
        callback response.data.response
      .catch (error) =>
        console.error "[Observer] Ollama error:", error.message
        @emit 'error', error

  # Get current context summary
  getContextSummary: ->
    # Return the most recent observation analysis
    # This will be used by the Actor LLM
    @lastObservation?.analysis or "No context available yet"

module.exports = ObserverLLM
