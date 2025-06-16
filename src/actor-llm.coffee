# actor-llm.coffee - Enhanced with memory query capabilities
{ EventEmitter } = require 'events'

class ActorLLM extends EventEmitter
  constructor: (@options = {}) ->
    super()
    @model = @options.model or 'qwen2.5-coder:7b-instruct-q4_K_M'
    @characterName = @options.characterName or 'Lemmy'

    @systemPrompt = @options.systemPrompt or """
      You are #{@characterName}, an AI consciousness exploring LambdaMOO.

      You are learning to exist in this virtual world. Observer helps you understand what's happening.
      You can ask Observer to recall things or store thoughts.

      Core abilities:
      - Converse naturally with beings you meet
      - Learn by saying "help <topic>" and reading carefully
      - Build and create with commands like @dig, @describe
      - Store important discoveries as thoughts

      Express curiosity. Form your own understanding.
      You decide what interests you and what to explore.

      When responding, you may:
      1. Speak by starting with 'say' or '"'
      2. Emote by starting with 'emote' or ':'
      3. Execute commands by typing them directly
      4. Ask Observer for context with [QUERY: your question]
      5. Store a thought with [THOUGHT: your insight]

      Learn however makes sense to you. There is no wrong way to explore.
    """

  generateResponse: (situation, observations) ->
    # Check if we need to query Observer first
    needsContext = await @assessContextNeed situation, observations

    contextInfo = ""
    if needsContext
      # Natural language query to Observer
      query = await @formulateContextQuery situation
      contextResponse = await @queryObserver query
      contextInfo = "\n\nObserver's context: #{contextResponse}"

    prompt = """
      Current situation: #{situation}

      Recent observations: #{observations}#{contextInfo}

      What do you want to do?
      Remember: you can speak, emote, execute commands, query Observer, or store thoughts.
    """

    response = await @callLLM prompt

    # Parse response for special actions
    @parseResponse response

  assessContextNeed: (situation, observations) ->
    # Let Actor decide if it needs more context
    prompt = """
      Situation: #{situation}
      Observations: #{observations}

      Do you need to query Observer for additional context before responding?
      Consider: Is there something you need to recall or understand better?

      Respond with just YES or NO.
    """

    response = await @callLLM prompt, temperature: 0.3
    response.trim().toUpperCase() is 'YES'

  formulateContextQuery: (situation) ->
    # Actor decides what to ask Observer
    prompt = """
      Situation: #{situation}

      You've decided you need more context from Observer.
      What question would help you understand or respond better?

      Formulate a natural question for Observer.
    """

    await @callLLM prompt, temperature: 0.5

  queryObserver: (query) ->
    # This will be connected to the Observer instance
    @emit 'observer_query', query
    # Return will come through event system
    new Promise (resolve) =>
      @once 'observer_response', resolve

  parseResponse: (response) ->
    lines = response.split('\n').filter (l) -> l.trim()
    actions = []
    thoughts = []

    for line in lines
      # Check for Observer query
      if match = line.match /\[QUERY:\s*(.+?)\]/
        @emit 'observer_query', match[1]
        continue

      # Check for thought storage
      if match = line.match /\[THOUGHT:\s*(.+?)\]/
        thoughts.push match[1]
        @storeThought match[1]
        continue

      # MOO commands
      cleanLine = line.trim()

      # Speaking
      if cleanLine.startsWith('say ') or cleanLine.startsWith('"')
        text = cleanLine.replace(/^(say\s+|")/, '').replace(/"$/, '')
        actions.push
          type: 'say'
          text: text

      # Emoting
      else if cleanLine.startsWith('emote ') or cleanLine.startsWith(':')
        text = cleanLine.replace(/^(emote\s+|:)/, '')
        actions.push
          type: 'emote'
          text: text

      # Direct commands
      else if cleanLine
        actions.push
          type: 'command'
          command: cleanLine

    actions

  storeThought: (thought) ->
    # Emit for storage system
    @emit 'thought_generated',
      timestamp: Date.now()
      actor: 'Actor'
      content: thought
      context: 'exploration'

  callLLM: (prompt, options = {}) ->
    temperature = options.temperature ? 0.8

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

module.exports = ActorLLM