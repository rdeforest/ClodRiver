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

  host    : 'localhost'
  port    : 7777
  username: 'Lemmy'
  password: 'pisebyg'

config = if fs.existsSync configPath

  yaml.load fs.readFileSync configPath, 'utf8'
else
  console.log "[INFO] No config found, using defaults"
  defaultConfig

# Create and run bot

bot = new MooBot config

bot.on 'logged-in', ->
  console.log "[INFO] Bot is ready!"

  # Example: Say hello after login
  setTimeout (-> bot.say "Hello! I'm a ClodRiver bot."), 2000

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
