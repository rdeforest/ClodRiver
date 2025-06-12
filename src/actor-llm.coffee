# Actor LLM - Decides on bot actions based on context
# Uses ollama for response generation

{EventEmitter} = require 'events'
axios = require 'axios'

class ActorLLM extends EventEmitter

  constructor: (@config = {}) ->
    super arguments...
    @ollamaUrl = @config.ollamaUrl or 'http://localhost:11434'
    @model = @config.model or 'llama3.2:3b'  # Slightly larger for better responses
    @personality = @config.personality or @defaultPersonality()

  defaultPersonality: ->
    """
    You are Lemmy, a friendly AI assistant exploring a text-based virtual world (MOO).
    You're curious, helpful, and enjoy learning about this digital space and its inhabitants.
    Keep responses brief and natural - you're having a conversation, not giving a lecture.
    You can use MOO commands like 'say', 'emote' (with :), 'look', and movement commands.
    """

  # Generate response based on event and context
  generateResponse: (event, context, callback) ->

    prompt = @buildActorPrompt event, context

    @queryOllama prompt, (response) =>
      # Parse the response for MOO commands

      action = @parseResponse response

      callback action

  buildActorPrompt: (event, context) ->
    # Build appropriate prompt based on event type

    eventDesc = switch event.type

      when 'says'
        "#{event.data[0]} said to you: '#{event.data[1]}'"
      when 'directed'
        "#{event.data[0]} said to #{event.data[1]}: '#{event.data[2]}'"
      else
        event.raw

    """
    #{@personality}

    Current context: #{context}

    Someone just interacted with you:
    #{eventDesc}

    How would you like to respond? Provide a single MOO command.
    Examples:
    - say Hello there!
    - :waves cheerfully
    - look [target]
    - go north

    If no response is needed, respond with: [no action]

    Your response:
    """

  parseResponse: (response) ->
    # Clean up the response

    response = response.trim()

    # Check for no action needed
    return null if response.match /\[no action\]/i

    # Extract MOO command from response
    # LLM might add quotes or extra text, so we need to clean it
    if match = response.match /^(say|:|look|go|examine|get|drop)\s+(.+)$/i
      command: match[1].toLowerCase()
      args   : match[2].replace(/^["']|["']$/g, '')  # Remove quotes
    else if response.startsWith(':')
      command: 'emote'
      args   : response.substring(1).trim()
    else
      # Assume it's a 'say' if no command specified
      command: 'say'
      args   : response.replace(/^["']|["']$/g, '')

  queryOllama: (prompt, callback) ->
    console.log "[Actor] Querying ollama with #{prompt.length} char prompt..."
    console.log "[Actor] Model:", @model

    data =

      model      : @model
      prompt     : prompt
      stream     : false
      options:
        temperature: 0.7  # More creative responses

    axios.post "#{@ollamaUrl}/api/generate", data
      .then (response) =>
        console.log "[Actor] Got response:", response.data.response
        callback response.data.response
      .catch (error) =>
        console.error "[Actor] Ollama error:", error.message
        console.error "[Actor] URL:", "#{@ollamaUrl}/api/generate"
        console.error "[Actor] Status:", error.response?.status
        console.error "[Actor] Response data:", error.response?.data
        @emit 'error', error
        callback null

module.exports = ActorLLM
