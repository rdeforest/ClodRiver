#!/usr/bin/env coffee

# test-model-sizes.coffee - Find maximum model size for available VRAM
# Usage: coffee test-model-sizes.coffee

{ exec } = require 'child_process'
{ promisify } = require 'util'
execAsync = promisify exec

# Test models in ascending size order
TEST_MODELS = [
  # Current models
  { name: 'llama3.2:1b', size: '~1GB' }
  { name: 'llama3.2:3b', size: '~2GB' }

  # 7B variants (different quantizations)
  { name: 'llama3.1:8b-instruct-q4_0', size: '~4.7GB' }
  { name: 'llama3.1:8b-instruct-q4_K_M', size: '~4.9GB' }  # Current
  { name: 'llama3.1:8b-instruct-q5_K_M', size: '~5.7GB' }
  { name: 'llama3.1:8b-instruct-q6_K', size: '~6.6GB' }
  { name: 'llama3.1:8b-instruct-q8_0', size: '~8.5GB' }

  # Larger models
  { name: 'llama3.1:13b-instruct-q4_K_M', size: '~7.9GB' }
  { name: 'llama3.1:13b-instruct-q5_K_M', size: '~9.2GB' }

  # Alternative models that might fit
  { name: 'mistral:7b-instruct-q4_K_M', size: '~4.1GB' }
  { name: 'mixtral:8x7b-instruct-v0.1-q2_K', size: '~15GB' }  # Probably too big
  { name: 'solar:10.7b-instruct-q4_K_M', size: '~6.1GB' }
  { name: 'gemma2:9b-instruct-q4_K_M', size: '~5.5GB' }
  { name: 'qwen2.5:7b-instruct-q4_K_M', size: '~4.7GB' }
  { name: 'qwen2.5:14b-instruct-q4_K_M', size: '~8.9GB' }
]

# Simple test prompt
TEST_PROMPT = "Hello! Please respond with a single sentence about yourself."

checkVRAM = ->
  try
    { stdout } = await execAsync 'nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits'
    [used, total] = stdout.trim().split(', ').map Number
    free = total - used
    return { used, total, free }
  catch error
    console.error "Error checking VRAM:", error.message
    return null

testModel = (modelName) ->
  console.log "\n" + "=".repeat(60)
  console.log "Testing: #{modelName}"
  console.log "=".repeat(60)

  # Check initial VRAM
  before = await checkVRAM()
  console.log "VRAM before: #{before.used}MB / #{before.total}MB (#{before.free}MB free)"

  # First ensure any loaded models are unloaded
  console.log "Unloading any existing models..."
  try
    await execAsync "curl -s http://localhost:11434/api/generate -d '{\"model\":\"_\",\"keep_alive\":0}'"
  catch
    # Ignore errors from unloading

  # Small delay to ensure unload completes
  await new Promise (resolve) -> setTimeout resolve, 2000

  # Pull model if not already available
  console.log "Ensuring model is available locally..."
  try
    { stdout, stderr } = await execAsync "ollama pull #{modelName}", { maxBuffer: 10 * 1024 * 1024 }
    if stderr
      console.log "Pull stderr:", stderr
  catch error
    console.error "Failed to pull model:", error.message
    return { success: false, error: "Failed to pull" }

  # Test loading and inference
  console.log "Loading model and running inference..."
  startTime = Date.now()

  try
    response = await fetch 'http://localhost:11434/api/generate',
      method: 'POST'
      headers: 'Content-Type': 'application/json'
      body: JSON.stringify
        model: modelName
        prompt: TEST_PROMPT
        stream: false

    if not response.ok
      throw new Error "API returned #{response.status}"

    result = await response.json()
    loadTime = Date.now() - startTime

    # Check VRAM while loaded
    during = await checkVRAM()
    vramUsed = during.used - before.used

    console.log "\n✅ SUCCESS!"
    console.log "Load + inference time: #{(loadTime/1000).toFixed(1)}s"
    console.log "VRAM during: #{during.used}MB / #{during.total}MB"
    console.log "Model VRAM usage: ~#{vramUsed}MB"
    console.log "Response: #{result.response}"

    # Unload model
    await fetch 'http://localhost:11434/api/generate',
      method: 'POST'
      headers: 'Content-Type': 'application/json'
      body: JSON.stringify
        model: modelName
        keep_alive: 0

    return {
      success: true
      vramUsed
      loadTime
      response: result.response
    }

  catch error
    console.error "\n❌ FAILED!"
    console.error "Error:", error.message
    return { success: false, error: error.message }

testDualModels = (model1, model2) ->
  console.log "\n" + "#".repeat(60)
  console.log "DUAL MODEL TEST: #{model1} + #{model2}"
  console.log "#".repeat(60)

  # Check initial VRAM
  before = await checkVRAM()
  console.log "Starting VRAM: #{before.used}MB / #{before.total}MB (#{before.free}MB free)"

  # Load first model
  console.log "\nLoading first model: #{model1}"
  try
    response1 = await fetch 'http://localhost:11434/api/generate',
      method: 'POST'
      headers: 'Content-Type': 'application/json'
      body: JSON.stringify
        model: model1
        prompt: "Say hello"
        keep_alive: 300  # Keep loaded

    await response1.json()

    # Check VRAM with one model
    afterOne = await checkVRAM()
    model1Vram = afterOne.used - before.used
    console.log "First model VRAM: ~#{model1Vram}MB"

    # Load second model
    console.log "\nLoading second model: #{model2}"
    response2 = await fetch 'http://localhost:11434/api/generate',
      method: 'POST'
      headers: 'Content-Type': 'application/json'
      body: JSON.stringify
        model: model2
        prompt: "Say hello"
        keep_alive: 300  # Keep loaded

    await response2.json()

    # Check VRAM with both models
    afterBoth = await checkVRAM()
    totalVram = afterBoth.used - before.used
    model2Vram = afterBoth.used - afterOne.used

    console.log "\n✅ Both models loaded successfully!"
    console.log "Second model VRAM: ~#{model2Vram}MB"
    console.log "Total VRAM used: #{totalVram}MB"
    console.log "Remaining free: #{afterBoth.free}MB"

    # Clean up
    for model in [model1, model2]
      await fetch 'http://localhost:11434/api/generate',
        method: 'POST'
        headers: 'Content-Type': 'application/json'
        body: JSON.stringify
          model: model
          keep_alive: 0

    return { success: true, totalVram, remaining: afterBoth.free }

  catch error
    console.error "\n❌ Failed to load both models"
    console.error "Error:", error.message
    return { success: false, error: error.message }

# Main test runner
main = ->
  console.log "GPU Model Size Tester"
  console.log "Testing available VRAM for LLM models..."

  # Check if ollama is running
  try
    await fetch 'http://localhost:11434/api/tags'
  catch
    console.error "\n❌ Ollama doesn't appear to be running!"
    console.error "Start it with: ollama serve"
    process.exit 1

  # Initial VRAM check
  initial = await checkVRAM()
  console.log "\nInitial VRAM: #{initial.used}MB / #{initial.total}MB (#{initial.free}MB free)"

  results = []

  # Test individual models
  console.log "\n### INDIVIDUAL MODEL TESTS ###"
  for model in TEST_MODELS
    # Skip if definitely too big
    estimatedSize = parseInt(model.size.match(/\d+/)?[0] or 0) * 1000
    if estimatedSize > initial.free + 1000  # Allow some overhead
      console.log "\nSkipping #{model.name} (#{model.size}) - too large for available VRAM"
      continue

    result = await testModel model.name
    results.push { model: model.name, size: model.size, ...result }

    # Stop if we're getting close to limits
    if result.success and result.vramUsed > initial.free * 0.8
      console.log "\nApproaching VRAM limit, stopping individual tests"
      break

  # Test some dual model combinations
  console.log "\n### DUAL MODEL TESTS ###"
  dualTests = [
    ['llama3.1:8b-instruct-q4_K_M', 'qwen2.5-coder:7b-instruct-q4_K_M']  # Current
    ['llama3.1:8b-instruct-q5_K_M', 'qwen2.5:7b-instruct-q4_K_M']        # Slightly larger
    ['llama3.1:13b-instruct-q4_K_M', 'llama3.2:3b']                      # Big + small
    ['gemma2:9b-instruct-q4_K_M', 'mistral:7b-instruct-q4_K_M']          # Alternative models
  ]

  for [model1, model2] in dualTests
    await testDualModels model1, model2
    # Add delay between tests
    await new Promise (resolve) -> setTimeout resolve, 3000

  # Summary
  console.log "\n" + "=".repeat(60)
  console.log "SUMMARY OF SUCCESSFUL MODELS"
  console.log "=".repeat(60)

  successful = results.filter (r) -> r.success
  successful.sort (a, b) -> b.vramUsed - a.vramUsed

  for result in successful
    console.log "#{result.model}: ~#{result.vramUsed}MB VRAM, #{(result.loadTime/1000).toFixed(1)}s load time"

  console.log "\nRecommendation based on your ~8.7GB total VRAM:"
  console.log "- For quality: llama3.1:13b-instruct-q4_K_M (if it fits)"
  console.log "- For balance: llama3.1:8b-instruct-q5_K_M or gemma2:9b-instruct-q4_K_M"
  console.log "- For speed: Keep current models but improve prompts"

# Run the test
main().catch (error) ->
  console.error "Unexpected error:", error
  process.exit 1