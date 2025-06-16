# Logging infrastructure for ClodRiver
# Supports console output and file logging with log rotation

fs = require 'fs'
path = require 'path'
util = require 'util'

class Logger
  constructor: (@config = {}) ->
    @logDir = @config.logDir or 'logs'
    @logFile = @config.logFile or 'clodriver.log'
    @maxSize = @config.maxSize or 10 * 1024 * 1024  # 10MB
    @maxFiles = @config.maxFiles or 5
    @consoleEnabled = @config.console ? true
    @fileEnabled = @config.file ? true

    # Log levels
    @levels =
      ERROR: 0
      WARN: 1
      INFO: 2
      DEBUG: 3

    @level = @levels[@config.level?.toUpperCase()] ? @levels.INFO

    # Create log directory if needed
    if @fileEnabled
      fs.mkdirSync @logDir, recursive: true unless fs.existsSync @logDir
      @currentLogPath = path.join @logDir, @logFile

  log: (level, component, message, data = null) ->
    levelName = Object.keys(@levels).find (k) => @levels[k] is level
    return unless level <= @level

    timestamp = new Date().toISOString()

    # Format message
    logEntry = "[#{timestamp}] [#{levelName}] [#{component}] #{message}"
    logEntry += " #{util.inspect(data, false, 2)}" if data

    # Console output
    if @consoleEnabled
      switch level
        when @levels.ERROR
          console.error logEntry
        when @levels.WARN
          console.warn logEntry
        else
          console.log logEntry

    # File output
    if @fileEnabled
      @writeToFile logEntry

  writeToFile: (entry) ->
    # Check file size and rotate if needed
    try
      stats = fs.statSync @currentLogPath
      @rotateLog() if stats.size > @maxSize
    catch
      # File doesn't exist yet, that's fine

    # Write entry
    fs.appendFileSync @currentLogPath, entry + '\n'

  rotateLog: ->
    # Rotate existing logs
    for i in [@maxFiles - 1..1]
      oldPath = path.join @logDir, "#{@logFile}.#{i}"
      newPath = path.join @logDir, "#{@logFile}.#{i + 1}"

      if fs.existsSync oldPath
        if i is @maxFiles - 1
          fs.unlinkSync oldPath  # Delete oldest
        else
          fs.renameSync oldPath, newPath

    # Move current log to .1
    fs.renameSync @currentLogPath, path.join(@logDir, "#{@logFile}.1")

  # Convenience methods
  error: (component, message, data) ->
    @log @levels.ERROR, component, message, data

  warn: (component, message, data) ->
    @log @levels.WARN, component, message, data

  info: (component, message, data) ->
    @log @levels.INFO, component, message, data

  debug: (component, message, data) ->
    @log @levels.DEBUG, component, message, data

  # MOO-specific logging helpers
  mooEvent: (event) ->
    @debug 'MOO', "Event: #{event.type}", event unless event.type is 'mcp'

  llmQuery: (component, prompt, response) ->
    @debug component, "Query", prompt: prompt.substring(0, 100) + '...'
    @debug component, "Response", response: response?.substring(0, 200) + '...'

  botAction: (action, details) ->
    @info 'Bot', action, details

module.exports = Logger