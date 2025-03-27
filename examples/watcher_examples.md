# File Watcher Examples

This document provides practical examples of using the Firmo watcher module to monitor file changes and trigger actions in your test environment.

## Basic Watcher Usage

Here's a simple example of initializing the watcher and checking for file changes:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")

-- Initialize watcher with default configuration
watcher.init()

-- Check for changes manually
local changes = watcher.check_for_changes()
if changes and #changes > 0 then
  print("Files changed:")
  for _, file_path in ipairs(changes) do
    print("  - " .. file_path)
  end
end
```

## Continuous Watch Loop

This example shows how to create a continuous watch loop that polls for changes:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")

-- Initialize watcher with a custom configuration
watcher.configure({
  include_patterns = {"src/%.lua$", "tests/%.lua$"},
  exclude_patterns = {"%.bak$", "%.tmp$"},
  poll_interval = 500,  -- 500ms polling interval
  check_initial = false -- Don't report existing files as changed on first check
})

watcher.init()

-- Main watch loop
local running = true
while running do
  local changes = watcher.check_for_changes()
  
  if changes and #changes > 0 then
    print("Files changed:")
    for _, file_path in ipairs(changes) do
      print("  - " .. file_path)
    end
    
    -- Run some action when files change
    print("Running tests...")
    os.execute("lua test.lua tests/")
  end
  
  -- Sleep between checks to avoid CPU overuse
  firmo.await(watcher.get_poll_interval())
end
```

## Integration with Test Runner

This example demonstrates integrating the watcher with Firmo's test runner:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")
local test_runner = require("lib.tools.test_runner")

-- Configure and initialize the watcher
watcher.configure({
  include_patterns = {"src/%.lua$", "tests/%.lua$"},
  exclude_patterns = {"/tmp/", "%.tmp$"},
  poll_interval = 1000 -- 1 second polling interval
})

watcher.init()

-- Enable watch mode for the test runner
test_runner.configure({
  watch_mode = true,
  watch_patterns = {"tests/%.lua$"} -- Only watch test files
})

-- Function to run tests when files change
local function run_tests_on_change()
  local changes = watcher.check_for_changes()
  
  if changes and #changes > 0 then
    -- Filter changes to only include test files
    local test_changes = {}
    for _, file_path in ipairs(changes) do
      if file_path:match("tests/%.lua$") then
        table.insert(test_changes, file_path)
      end
    end
    
    if #test_changes > 0 then
      print("\nTest files changed, running tests...")
      test_runner.run_tests(test_changes)
    else
      print("\nSource files changed, running all tests...")
      test_runner.run_tests("tests/")
    end
  end
  
  return true -- Continue watching
end

-- Start the watching loop
print("Watching for file changes. Press Ctrl+C to exit.")
while true do
  run_tests_on_change()
  firmo.await(watcher.get_poll_interval())
end
```

## Auto-reloading Configuration

This example shows how to implement an auto-reloading configuration system:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")
local central_config = require("lib.core.central_config")

-- Initialize watcher to monitor configuration file
watcher.configure({
  include_patterns = {"%.firmo%-config%.lua$"},
  poll_interval = 2000 -- Check every 2 seconds
})

watcher.init()

-- Function to reload configuration when it changes
local function check_and_reload_config()
  local changes = watcher.check_for_changes()
  
  if changes and #changes > 0 then
    for _, file_path in ipairs(changes) do
      if file_path:match("%.firmo%-config%.lua$") then
        print("Configuration file changed, reloading...")
        
        -- Attempt to reload configuration
        local success, err = pcall(function()
          central_config.reload()
        end)
        
        if not success then
          print("Failed to reload configuration: " .. tostring(err))
        else
          print("Configuration reloaded successfully")
        end
      end
    end
  end
end

-- Main program loop
while true do
  check_and_reload_config()
  
  -- Your application logic here
  
  firmo.await(watcher.get_poll_interval())
end
```

## Handling Rapid Changes

This example demonstrates debouncing to handle rapid sequential file changes:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")

-- Initialize watcher
watcher.configure({
  include_patterns = {"src/%.lua$", "tests/%.lua$"},
  poll_interval = 300 -- 300ms polling interval (more responsive)
})

watcher.init()

-- Variables for debouncing
local debounce_timeout = 500 -- ms
local last_change_time = 0
local pending_changes = {}

-- Main watch loop with debouncing
while true do
  local changes = watcher.check_for_changes()
  
  if changes and #changes > 0 then
    -- Record the current time
    local current_time = os.time() * 1000
    last_change_time = current_time
    
    -- Add new changes to pending changes
    for _, file_path in ipairs(changes) do
      if not pending_changes[file_path] then
        pending_changes[file_path] = true
      end
    end
    
    -- Continue loop without action to allow for more changes
  else
    -- Check if debounce period has elapsed and we have pending changes
    local current_time = os.time() * 1000
    local time_since_last_change = current_time - last_change_time
    
    if time_since_last_change >= debounce_timeout and next(pending_changes) ~= nil then
      -- Convert pending changes table to array
      local change_list = {}
      for file_path, _ in pairs(pending_changes) do
        table.insert(change_list, file_path)
      end
      
      -- Process the changes
      print("Files changed after debouncing:")
      for _, file_path in ipairs(change_list) do
        print("  - " .. file_path)
      end
      
      -- Run tests or other actions
      print("Running tests...")
      os.execute("lua test.lua tests/")
      
      -- Clear the pending changes
      pending_changes = {}
    end
  end
  
  -- Sleep between checks
  firmo.await(watcher.get_poll_interval())
end
```

## Resource Management

This example shows proper resource management with the watcher:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")
local error_handler = require("lib.tools.error_handler")

-- Initialize watcher with resource management
local function with_watcher(config, callback)
  -- Configure and initialize the watcher
  watcher.configure(config or {})
  
  local init_success, init_err = error_handler.try(function()
    return watcher.init()
  end)
  
  if not init_success then
    print("Failed to initialize watcher: " .. tostring(init_err))
    return false
  end
  
  -- Execute the callback function
  local callback_result, callback_err
  
  local success = error_handler.try(function()
    callback_result = callback()
  end)
  
  if not success then
    callback_err = callback_result
    print("Error in watch callback: " .. tostring(callback_err))
  end
  
  -- Always clean up resources
  local cleanup_success, cleanup_err = error_handler.try(function()
    return watcher.cleanup()
  end)
  
  if not cleanup_success then
    print("Warning: Failed to clean up watcher resources: " .. tostring(cleanup_err))
  end
  
  -- Return the callback results
  if callback_err then
    return false, callback_err
  else
    return true, callback_result
  end
end

-- Example usage of the resource management pattern
with_watcher({
  include_patterns = {"src/%.lua$", "tests/%.lua$"},
  poll_interval = 1000
}, function()
  print("Watching for changes. Press Ctrl+C to exit.")
  
  local running = true
  while running do
    local changes = watcher.check_for_changes()
    
    if changes and #changes > 0 then
      print("Files changed, running tests...")
      os.execute("lua test.lua tests/")
    end
    
    firmo.await(watcher.get_poll_interval())
  end
  
  return true
end)
```

## Error Handling

This example demonstrates robust error handling with the watcher:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")

-- Configure and initialize the watcher with robust error handling
local function init_watcher()
  -- Try to configure the watcher
  local success, result, err = error_handler.try(function()
    watcher.configure({
      include_patterns = {"src/%.lua$", "tests/%.lua$"},
      exclude_patterns = {"%.bak$", "%.tmp$"},
      poll_interval = 1000
    })
    
    return watcher.init()
  end)
  
  if not success then
    logger.error("Failed to initialize file watcher", {
      error = error_handler.format_error(result)
    })
    return false
  end
  
  return true
end

-- Check for changes with error handling
local function check_with_error_handling()
  local success, changes, err = error_handler.try(function()
    return watcher.check_for_changes()
  end)
  
  if not success then
    logger.error("Error checking for file changes", {
      error = error_handler.format_error(changes)
    })
    return nil
  end
  
  return changes
end

-- Main program with comprehensive error handling
if not init_watcher() then
  print("Could not initialize watcher, exiting.")
  os.exit(1)
end

-- Set up error recovery
local consecutive_errors = 0
local max_consecutive_errors = 5

-- Watch loop with error recovery
while true do
  local changes = check_with_error_handling()
  
  if changes == nil then
    -- Error occurred during check
    consecutive_errors = consecutive_errors + 1
    
    if consecutive_errors >= max_consecutive_errors then
      logger.error("Too many consecutive errors, stopping watcher")
      break
    else
      -- Wait longer between checks when errors occur
      firmo.await(watcher.get_poll_interval() * 2)
    end
  else
    -- Reset error counter on successful check
    consecutive_errors = 0
    
    if changes and #changes > 0 then
      logger.info("Files changed", { count = #changes })
      
      -- Process changes safely
      for _, file_path in ipairs(changes) do
        local success, err = error_handler.try(function()
          -- Process each file change
          print("File changed: " .. file_path)
          
          -- Safely run tests
          local result = os.execute("lua test.lua " .. file_path)
          return result
        end)
        
        if not success then
          logger.warn("Failed to process file change", {
            file = file_path,
            error = error_handler.format_error(err)
          })
        end
      end
    end
    
    -- Normal wait between checks
    firmo.await(watcher.get_poll_interval())
  end
end

-- Clean up resources
local cleanup_success, cleanup_err = error_handler.try(function()
  return watcher.cleanup()
end)

if not cleanup_success then
  logger.error("Failed to clean up watcher resources", {
    error = error_handler.format_error(cleanup_err)
  })
end
```

## Integration with Live Reload

This example shows how to use the watcher for a simple live reload server:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")
local http_server = require("lib.tools.http_server") -- Hypothetical HTTP server module

-- Set up watcher for client-side files
watcher.configure({
  include_patterns = {"public/.*%.js$", "public/.*%.css$", "public/.*%.html$"},
  poll_interval = 500
})

watcher.init()

-- Set up a simple HTTP server
local server = http_server.create({
  port = 8080,
  root_dir = "public"
})

-- Set up WebSocket for live reload notifications
local clients = {}

server.on_websocket_connect("/livereload", function(client)
  table.insert(clients, client)
  print("Client connected to live reload")
end)

-- Watch loop that notifies clients of changes
local function watch_and_notify()
  while true do
    local changes = watcher.check_for_changes()
    
    if changes and #changes > 0 then
      print("Files changed, notifying clients:")
      for _, file_path in ipairs(changes) do
        print("  - " .. file_path)
      end
      
      -- Notify all connected clients
      for i, client in ipairs(clients) do
        if client.connected then
          client.send(JSON.encode({
            type = "reload",
            files = changes
          }))
        else
          -- Remove disconnected clients
          table.remove(clients, i)
        end
      end
    end
    
    firmo.await(watcher.get_poll_interval())
  end
end

-- Start the server
server.start()
print("Server started on http://localhost:8080")

-- Start the watcher
watch_and_notify()
```

## Using the Watcher in Test Files

This example shows how to use the watcher directly in test files:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")

-- Test suite for a module that changes files
describe("File Processor Module", function()
  local test_dir
  local test_files = {}
  
  -- Set up the test directory and watcher
  before(function()
    -- Create test directory
    test_dir = os.tmpname()
    os.remove(test_dir)
    os.execute("mkdir -p " .. test_dir)
    
    -- Create test files
    for i = 1, 3 do
      local file_path = test_dir .. "/test_" .. i .. ".txt"
      local file = io.open(file_path, "w")
      file:write("Original content " .. i)
      file:close()
      table.insert(test_files, file_path)
    end
    
    -- Configure and initialize watcher
    watcher.configure({
      include_patterns = {test_dir .. "/.*%.txt$"},
      poll_interval = 100 -- Fast polling for tests
    })
    
    watcher.init()
  end)
  
  -- Clean up after tests
  after(function()
    watcher.cleanup()
    
    -- Remove test files
    for _, file_path in ipairs(test_files) do
      os.remove(file_path)
    end
    
    -- Remove test directory
    os.execute("rmdir " .. test_dir)
  end)
  
  -- Test that watcher detects file changes
  it("should detect when files are modified", function()
    -- First check should return nothing since no changes yet
    local changes = watcher.check_for_changes()
    expect(changes).to.be.a("table")
    expect(#changes).to.equal(0)
    
    -- Modify a file
    local file = io.open(test_files[1], "w")
    file:write("Modified content")
    file:close()
    
    -- Give the file system a moment to register the change
    firmo.await(200)
    
    -- Check again, should detect the change
    changes = watcher.check_for_changes()
    expect(changes).to.be.a("table")
    expect(#changes).to.equal(1)
    expect(changes[1]).to.equal(test_files[1])
  end)
  
  -- Test that watcher detects new files
  it("should detect when files are added", function()
    -- Add a new file
    local new_file = test_dir .. "/new_file.txt"
    local file = io.open(new_file, "w")
    file:write("New file content")
    file:close()
    table.insert(test_files, new_file)
    
    -- Give the file system a moment to register the change
    firmo.await(200)
    
    -- Check for changes
    local changes = watcher.check_for_changes()
    expect(changes).to.be.a("table")
    expect(#changes).to.equal(1)
    expect(changes[1]).to.equal(new_file)
  end)
  
  -- Test that watcher respects exclude patterns
  it("should not detect excluded files", function()
    watcher.configure({
      include_patterns = {test_dir .. "/.*%.txt$"},
      exclude_patterns = {test_dir .. "/test_1%.txt$"},
      poll_interval = 100
    })
    
    -- Modify both included and excluded files
    local file1 = io.open(test_files[1], "w")
    file1:write("Modified again but excluded")
    file1:close()
    
    local file2 = io.open(test_files[2], "w")
    file2:write("Modified and included")
    file2:close()
    
    -- Give the file system a moment to register the changes
    firmo.await(200)
    
    -- Check for changes, should only detect file2
    local changes = watcher.check_for_changes()
    expect(changes).to.be.a("table")
    expect(#changes).to.equal(1)
    expect(changes[1]).to.equal(test_files[2])
  end)
end)
```

## Advanced Example: Intelligent Test Selection

This example demonstrates using the watcher for intelligent test selection based on dependencies:

```lua
local firmo = require("firmo")
local watcher = require("lib.tools.watcher")
local dependence_tracker = require("lib.tools.dependence_tracker") -- Hypothetical module

-- Initialize the dependency tracker
dependence_tracker.analyze_project("src/", "tests/")

-- Configure and initialize the watcher
watcher.configure({
  include_patterns = {"src/%.lua$", "tests/%.lua$"},
  poll_interval = 1000
})

watcher.init()

-- Function to select tests based on changed files
local function select_tests_for_changes(changes)
  local tests_to_run = {}
  
  for _, file_path in ipairs(changes) do
    -- If it's a test file, run it directly
    if file_path:match("^tests/") then
      table.insert(tests_to_run, file_path)
    else
      -- If it's a source file, find dependent tests
      local dependent_tests = dependence_tracker.find_dependent_tests(file_path)
      for _, test_path in ipairs(dependent_tests) do
        -- Add to the list if not already there
        local exists = false
        for _, existing in ipairs(tests_to_run) do
          if existing == test_path then
            exists = true
            break
          end
        end
        
        if not exists then
          table.insert(tests_to_run, test_path)
        end
      end
    end
  end
  
  return tests_to_run
end

-- Main watch loop with intelligent test selection
print("Watching for changes with intelligent test selection...")

while true do
  local changes = watcher.check_for_changes()
  
  if changes and #changes > 0 then
    print("Changes detected:")
    for _, file_path in ipairs(changes) do
      print("  - " .. file_path)
    end
    
    -- Select tests to run based on changes
    local tests_to_run = select_tests_for_changes(changes)
    
    if #tests_to_run > 0 then
      print("Running affected tests:")
      for _, test_path in ipairs(tests_to_run) do
        print("  - " .. test_path)
      end
      
      -- Run the selected tests
      for _, test_path in ipairs(tests_to_run) do
        os.execute("lua test.lua " .. test_path)
      end
    else
      print("No tests affected by these changes")
    end
  end
  
  firmo.await(watcher.get_poll_interval())
end
```

These examples demonstrate the various ways to use the watcher module in different scenarios, from basic file change monitoring to advanced use cases like intelligent test selection and live reloading.