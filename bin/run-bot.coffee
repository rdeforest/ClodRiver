#!/usr/bin/env coffee
# Run the MOO bot for testing

MooBot = require '../src/moo-bot'
fs     = require 'fs'
path   = require 'path'
yaml   = require 'js-yaml'

# Load config

configPath = path.join __dirname, '..', 'config', 'bot.yaml'

# Default config if file doesn't exist

defaultConfig =

  host       : 'localhost'
  port       : 7777
  username   : 'Lemmy'
  password   : 'devpass123'
  enableLLM  : true  # Enable LLM support
  observer:
    model      : 'llama3.1:8b-instruct-q4_K_M'  # Better comprehension
    batchDelay : 2000
  actor:
    model      : 'qwen2.5-coder:7b-instruct-q4_K_M'  # Good for structured responses
    personality: null  # Use default

config = if fs.existsSync configPath

  yaml.load fs.readFileSync configPath, 'utf8'
else
  console.log "[INFO] No config found, using defaults"
  defaultConfig

# Check if LLM is requested but ollama might not be running
if config.enableLLM
  console.log "[INFO] LLM support enabled. Make sure ollama is running!"
  console.log "[INFO] Observer model: #{config.observer?.model or 'llama3.2:1b'}"
  console.log "[INFO] Actor model: #{config.actor?.model or 'llama3.2:3b'}"

# Create and run bot

bot = new MooBot config

bot.on 'logged-in', ->
  console.log "[INFO] Bot is ready!"

  # Example: Say hello after login
  setTimeout (-> bot.say "Hello! I'm Lemmy, an AI exploring this world."), 2000

bot.on 'error', (err) ->
  console.error "[ERROR]", err
  process.exit 1

# Handle graceful shutdown
process.on 'SIGINT', ->
  console.log "\n[INFO] Shutting down..."
  bot.say "Goodbye!"
  setTimeout (-> 
    bot.disconnect()
    process.exit 0
  ), 1000

# Connect
bot.connect()

# Keep process alive
process.stdin.resume()
