#!/usr/bin/env coffee

# run-bot.coffee - Run the MOO bot with configuration
fs = require 'fs'
path = require 'path'
yaml = require 'js-yaml'
MOOBot = require '../src/moo-bot'  # Updated class name

# Load configuration
configPath = process.argv[2] or path.join(__dirname, '..', 'config', 'bot.yaml')

try
  configFile = fs.readFileSync configPath, 'utf8'
  config = yaml.load configFile
catch error
  console.error "Failed to load config from #{configPath}:", error.message
  process.exit 1

console.log """
Starting MOO Bot with configuration:
- Host: #{config.host}:#{config.port}
- Username: #{config.username}
- LLM: #{if config.enableLLM then 'Enabled' else 'Disabled'}
"""

if config.enableLLM
  console.log "- Observer: #{config.observer?.model or config.model or 'default'}"
  console.log "- Actor: #{config.actor?.model or config.model or 'default'}"
  if config.observer?.model is config.actor?.model or config.model
    console.log "  (Using same model - VRAM shared!)"

# Create and start bot
bot = new MOOBot config

# Event handlers for monitoring
bot.on 'connected', ->
  console.log "\n✓ Connected to MOO"

bot.on 'logged_in', ->
  console.log "✓ Logged in as #{config.username}"
  console.log "\nBot is now active. Press Ctrl+C to quit.\n"

bot.on 'moo_event', (event) ->
  if config.debug
    timestamp = new Date().toISOString().split('T')[1].split('.')[0]
    console.log "[#{timestamp}] #{event.raw}"

bot.on 'thought', (thought) ->
  console.log "\n💭 [#{thought.actor}] #{thought.content}\n"

bot.on 'error', (error) ->
  console.error "\n❌ Error:", error.message

bot.on 'disconnected', ->
  console.log "\n✗ Disconnected from MOO"
  process.exit 0

# Graceful shutdown
process.on 'SIGINT', ->
  console.log "\n\nShutting down..."
  bot.disconnect()
  setTimeout ->
    console.log "Forced exit"
    process.exit 0
  , 2000

# Connect!
bot.connect()

# Keep process alive
process.stdin.resume()