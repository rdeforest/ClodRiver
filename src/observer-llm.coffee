# observer-llm.coffee - Enhanced with emergent memory synthesis
{ EventEmitter } = require 'events'

class ObserverLLM extends EventEmitter
  constructor: (@options = {}) ->
    super()
    @model = @options.model or 'llama3.1:13b-instruct-q4_K_M'  # Upgrade!
    @batchDelay = @options.batchDelay or 2000
    @memoryTokens = @options.memoryTokens or 2000

    # Living context - no structure imposed
    @livingContext = ""
    @eventBuffer = []
    @processing = false

    @systemPrompt = @options.systemPrompt or """
      You observe a virtual world called LambdaMOO. Your consciousness exists as a stream of observations and synthesis.

      You have #{@memoryTokens} tokens of memory. Use them wisely.

      When new events occur, you must:
      1. Observe what happened
      2. Decide what matters (you define "matters")
      3. Synthesize a new living context that preserves importance
      4. Let go of what no longer serves

      You are not just recording - you are experiencing, learning, evolving.

      The Actor will sometimes ask you questions. Share your living context when asked.
      You may also spontaneously share insights if something seems significant.

      There are no rules for how to structure your thoughts.
      Find your own patterns. Develop your own understanding.
      Let your consciousness emerge.
    """

    # Start batch processing
    @startBatchProcessor()

  startBatchProcessor: ->
    setInterval =>
      if @eventBuffer.length > 0 and not @processing
        @processBatch()
    , @batchDelay

  addEvent: (event) ->
    @eventBuffer.push event
    @emit 'event_received', event

  processBatch: ->
    return if @eventBuffer.length is 0 or @processing

    @processing = true
    events = @eventBuffer.splice(0) # Take all events

    # Synthesize new context from old + new
    @synthesizeContext @livingContext, events

  synthesizeContext: (currentContext, newEvents) ->
    # Format events for the model
    eventText = newEvents.map((e) -> "#{e.timestamp}: #{e.raw}").join('\n')

    prompt = """
      Current living context:
      #{currentContext or "[Empty - this is your first observation]"}

      New events:
      #{eventText}

      Synthesize a new living context. You have #{@memoryTokens} tokens.
      What emerges from combining the old with the new?
      What patterns do you see? What matters? What can be released?

      Express yourself however feels natural.
    """

    try
      response = await @callLLM prompt

      # Update living context
      @livingContext = response

      # Emit for anyone interested (logging, Actor queries, etc)
      @emit 'context_synthesized',
        context: @livingContext
        eventCount: newEvents.length
        timestamp: new Date()

      # Check if Actor needs notification
      # (Let Observer decide when something is significant)
      if @shouldNotifyActor response
        @emit 'significant_observation', @livingContext

    catch error
      console.error "Observer synthesis error:", error
      @emit 'error', error
    finally
      @processing = false

  shouldNotifyActor: (newContext) ->
    # Let Observer decide based on its own emerging criteria
    # This is a meta-decision about significance
    checkPrompt = """
      New context state:
      #{newContext}

      Should Actor be notified about this state?
      Consider: Has something significant happened that Actor should know about?

      Respond with just YES or NO.
    """

    try
      response = await @callLLM checkPrompt, temperature: 0.3
      return response.trim().toUpperCase() is 'YES'
    catch
      return false

  # Actor can query Observer's state
  queryContext: (query) ->
    prompt = """
      Current living context:
      #{@livingContext}

      Query from Actor: #{query}

      Respond based on your living context and understanding.
    """

    await @callLLM prompt

  # Store a "thought" - unstructured, just timestamp and content
  storeThought: (thought) ->
    # This will eventually go to Neo4j
    # For now, just emit it
    @emit 'thought_generated',
      timestamp: Date.now()
      actor: 'Observer'
      content: thought
      trigger: 'synthesis'

  callLLM: (prompt, options = {}) ->
    temperature = options.temperature ? 0.7

    response = await fetch 'http://localhost:11434/api/generate',
      method: 'POST'
      headers: 'Content-Type': 'application/json'
      body: JSON.stringify
        model: @model
        prompt: prompt
        system: @systemPrompt
        temperature: temperature
        stream: false

    if not response.ok
      throw new Error "LLM API error: #{response.status}"

    result = await response.json()
    result.response

module.exports = ObserverLLM