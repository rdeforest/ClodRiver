# ClodRiver Cakefile
# Development automation for MOO, database, and LLM setup

{exec, spawn} = require 'child_process'
fs = require 'fs'
path = require 'path'

# Helper functions
log = (msg) -> console.log "\x1b[32m[ClodRiver]\x1b[0m #{msg}"
warn = (msg) -> console.log "\x1b[33m[ClodRiver]\x1b[0m #{msg}"
error = (msg) -> console.log "\x1b[31m[ClodRiver]\x1b[0m #{msg}"

runCommand = (cmd, callback) ->
  exec cmd, (err, stdout, stderr) ->
    if err
      error "Command failed: #{cmd}"
      console.log stderr if stderr
      process.exit 1
    else
      console.log stdout if stdout
      callback?()

# Task definitions
task 'help', 'Show available tasks', ->
  console.log """
  ClodRiver Development Commands:
  
  MOO Server:
    cake setup:moo     Setup LambdaMOO with Waterpoint core
    cake start:moo     Start the MOO server (port 7777)
    cake stop:moo      Stop the MOO server
    cake status:moo    Check MOO server status
    cake clean:moo     Remove MOO installation (keeps database)
  
  Development:
    cake install       Install Node.js dependencies
    cake test          Run kava tests
    cake build         Compile CoffeeScript to JavaScript
    cake watch         Watch and compile CoffeeScript files
  
  Database Setup (future):
    cake setup:neo4j   Setup Neo4j database
    cake setup:ollama  Setup ollama for local LLMs
  """

# MOO setup and management
task 'setup:moo', 'Setup LambdaMOO with Waterpoint core', ->
  log "Setting up MOO server..."
  unless fs.existsSync 'setup-moo.sh'
    error "setup-moo.sh not found. Please create it first."
    process.exit 1
  
  runCommand 'chmod +x setup-moo.sh && ./setup-moo.sh', ->
    log "MOO setup complete!"

task 'start:moo', 'Start the MOO server', ->
  unless fs.existsSync 'moo/start-moo.sh'
    error "MOO not set up. Run 'cake setup:moo' first."
    process.exit 1
  
  log "Starting MOO server..."
  runCommand './moo/start-moo.sh'

task 'stop:moo', 'Stop the MOO server', ->
  if fs.existsSync 'moo/stop-moo.sh'
    log "Stopping MOO server..."
    runCommand './moo/stop-moo.sh'
  else
    error "MOO scripts not found. Run 'cake setup:moo' first."

task 'status:moo', 'Check MOO server status', ->
  if fs.existsSync 'moo/status-moo.sh'
    runCommand './moo/status-moo.sh'
  else
    error "MOO scripts not found. Run 'cake setup:moo' first."

task 'clean:moo', 'Remove MOO installation (keeps database)', ->
  log "Removing MOO installation (keeping database)..."
  runCommand 'rm -rf moo/', ->
    log "MOO installation removed. Database files preserved."

# Development tasks
task 'install', 'Install Node.js dependencies', ->
  log "Installing dependencies..."
  runCommand 'npm install', ->
    log "Dependencies installed!"

task 'test', 'Run kava tests', ->
  log "Running tests..."
  runCommand 'npm test'

task 'build', 'Compile CoffeeScript to JavaScript', ->
  log "Compiling CoffeeScript..."
  runCommand 'npx coffee --compile --output lib/ src/', ->
    log "Compilation complete!"

task 'watch', 'Watch and compile CoffeeScript files', ->
  log "Watching CoffeeScript files for changes..."
  runCommand 'npx coffee --watch --compile --output lib/ src/'

# Future database setup tasks
task 'setup:neo4j', 'Setup Neo4j database', ->
  warn "Neo4j setup not implemented yet"

task 'setup:ollama', 'Setup ollama for local LLMs', ->
  warn "Ollama setup not implemented yet"

# Convenience aliases
task 'moo:setup', 'Alias for setup:moo', -> invoke 'setup:moo'
task 'moo:start', 'Alias for start:moo', -> invoke 'start:moo'
task 'moo:stop', 'Alias for stop:moo', -> invoke 'stop:moo'
task 'moo:status', 'Alias for status:moo', -> invoke 'status:moo'
task 'moo:clean', 'Alias for clean:moo', -> invoke 'clean:moo'