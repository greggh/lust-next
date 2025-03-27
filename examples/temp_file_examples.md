# Temporary File Management Examples

This document provides example patterns for using Firmo's temporary file management system.

## Basic File Creation Examples

### Creating a Simple Temporary File

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create a temporary file with content
local file_path, err = temp_file.create_with_content("This is test content", "txt")
if err then
  print("Error creating temporary file: " .. tostring(err))
  return
end

print("Created temporary file at: " .. file_path)

-- Verify the file exists and has correct content
if fs.file_exists(file_path) then
  local content = fs.read_file(file_path)
  print("File content: " .. content)
else
  print("File doesn't exist")
end

-- File will be cleaned up automatically at the end of the test
```

### Creating a Temporary Directory

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create a temporary directory
local dir_path, err = temp_file.create_temp_directory()
if err then
  print("Error creating temporary directory: " .. tostring(err))
  return
end

print("Created temporary directory at: " .. dir_path)

-- Create files inside the directory
local file_path = dir_path .. "/test.txt"
fs.write_file(file_path, "File in temporary directory")

-- Verify file creation
if fs.file_exists(file_path) then
  print("Successfully created file in temporary directory")
else
  print("Failed to create file in temporary directory")
end

-- Directory and all its contents will be cleaned up automatically
```

## With-Pattern Examples

### Using with_temp_file for Automatic Cleanup

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create, use, and automatically clean up a temporary file
local result, err = temp_file.with_temp_file("Configuration data", function(temp_path)
  print("Using temporary file at: " .. temp_path)
  
  -- Read the content to verify
  local content = fs.read_file(temp_path)
  print("File content: " .. content)
  
  -- Modify the file
  fs.write_file(temp_path, content .. "\nAdditional data")
  
  -- Return a result from the callback
  return "Operation completed successfully"
end, "cfg")

if err then
  print("Error in with_temp_file: " .. tostring(err))
else
  print("Result: " .. result)
  -- At this point, the temporary file has already been cleaned up
end
```

### Using with_temp_directory for Directory Operations

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create, use, and automatically clean up a temporary directory
local result, err = temp_file.with_temp_directory(function(dir_path)
  print("Using temporary directory at: " .. dir_path)
  
  -- Create subdirectories
  local config_dir = dir_path .. "/config"
  fs.create_directory(config_dir)
  
  -- Create files
  fs.write_file(config_dir .. "/settings.json", '{"debug": true}')
  fs.write_file(dir_path .. "/README.md", "# Test Directory")
  
  -- Return information from the callback
  return {
    dir_path = dir_path,
    file_count = 2,
    status = "complete"
  }
end)

if err then
  print("Error in with_temp_directory: " .. tostring(err))
else
  print("Directory operation completed")
  print("Path: " .. result.dir_path)
  print("Files created: " .. result.file_count)
  -- At this point, the temporary directory and its contents have been cleaned up
end
```

## Complex Directory Structure Examples

### Creating a Test Project Structure

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create a temporary directory for a project structure
local project_dir, err = temp_file.create_temp_directory()
if err then
  print("Error creating project directory: " .. tostring(err))
  return
end

print("Created project directory at: " .. project_dir)

-- Create a typical project structure
local dirs = {
  src = project_dir .. "/src",
  test = project_dir .. "/test",
  config = project_dir .. "/config",
  docs = project_dir .. "/docs"
}

-- Create directories
for name, path in pairs(dirs) do
  local success, err = fs.create_directory(path)
  if not success then
    print("Error creating " .. name .. " directory: " .. tostring(err))
  else
    print("Created " .. name .. " directory")
  end
end

-- Create source files
fs.write_file(dirs.src .. "/main.lua", "print('Hello, world!')")
fs.write_file(dirs.src .. "/utils.lua", "local M = {}\nfunction M.add(a, b) return a + b end\nreturn M")

-- Create test files
fs.write_file(dirs.test .. "/main_test.lua", [[
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Main module", function()
  it("should print greeting", function()
    -- Test implementation
  end)
end)
]])

-- Create config file
fs.write_file(dirs.config .. "/settings.json", [[
{
  "debug": true,
  "logLevel": "info",
  "port": 8080
}
]])

-- Create documentation
fs.write_file(dirs.docs .. "/README.md", "# Test Project\nThis is a test project structure.")

print("Project structure created successfully")

-- Use the project structure for testing
-- ...

-- All directories and files will be cleaned up automatically
```

### Working with Multiple Files

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create multiple temporary files for a test
local files = {}

for i = 1, 5 do
  local content = "Content for file " .. i
  local file_path, err = temp_file.create_with_content(content, "txt")
  
  if err then
    print("Error creating file " .. i .. ": " .. tostring(err))
  else
    table.insert(files, file_path)
    print("Created file " .. i .. " at: " .. file_path)
  end
end

print("Created " .. #files .. " temporary files")

-- Use the files
for i, file_path in ipairs(files) do
  local content = fs.read_file(file_path)
  print("File " .. i .. " content: " .. content)
end

-- Files will be cleaned up automatically
```

## Test Framework Integration Examples

### Integrated Temp File Management in Tests

```lua
local firmo = require("firmo")
local temp_file = require("lib.tools.temp_file")
local temp_file_integration = require("lib.tools.temp_file_integration")
local fs = require("lib.tools.filesystem")

-- Initialize the integration with Firmo
temp_file_integration.initialize(firmo)

-- Extract test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Example test suite with temporary file usage
describe("File Processor", function()
  local config_file
  
  -- Create a shared temporary file for all tests in this describe block
  before(function()
    local file_path, err = temp_file.create_with_content([[
{
  "api_key": "test_key",
  "endpoint": "https://api.example.com",
  "timeout": 30
}
]], "json")
    
    expect(err).to_not.exist("Failed to create config file")
    config_file = file_path
  end)
  
  it("should read configuration from file", function()
    -- Test using the config file
    local content = fs.read_file(config_file)
    expect(content).to.exist()
    expect(content).to.match("api_key")
  end)
  
  it("should detect invalid config", function()
    -- Create a test-specific temporary file with invalid content
    local invalid_file, err = temp_file.create_with_content("{invalid json", "json")
    expect(err).to_not.exist("Failed to create invalid config file")
    
    -- Test with invalid file
    -- ...
    
    -- This file will be cleaned up automatically when the test completes
  end)
  
  it("should handle multiple config files", function()
    -- Create a temporary directory for multiple configs
    local config_dir, err = temp_file.create_temp_directory()
    expect(err).to_not.exist("Failed to create config directory")
    
    -- Create multiple config files
    fs.write_file(config_dir .. "/config1.json", '{"setting": "value1"}')
    fs.write_file(config_dir .. "/config2.json", '{"setting": "value2"}')
    
    -- Test with multiple config files
    -- ...
    
    -- Directory and all files will be cleaned up automatically
  end)
  
  -- The config_file will be cleaned up automatically when all tests complete
end)
```

### Manual Cleanup for Special Cases

```lua
local firmo = require("firmo")
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Extract test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Special Cleanup Cases", function()
  it("should handle manual cleanup when needed", function()
    -- Create temporary files
    local file1, err1 = temp_file.create_with_content("Content 1", "txt")
    local file2, err2 = temp_file.create_with_content("Content 2", "txt")
    
    expect(err1).to_not.exist()
    expect(err2).to_not.exist()
    
    -- For this test, we need to clean up file1 early
    local success, err = temp_file.remove(file1)
    expect(success).to.be_truthy("Failed to remove file1: " .. tostring(err))
    
    -- file2 will still be cleaned up automatically
  end)
  
  it("should clean up specific context", function()
    -- Create a bunch of temporary files
    for i = 1, 5 do
      local file_path, err = temp_file.create_with_content("Test " .. i, "txt")
      expect(err).to_not.exist()
    end
    
    -- Do some testing
    -- ...
    
    -- Explicitly clean up this test's files before it completes
    local success, errors = temp_file.cleanup_test_context()
    expect(success).to.be_truthy("Cleanup failed")
    expect(#errors).to.equal(0, "Cleanup had errors")
  end)
end)
```

## Statistical and Diagnostic Examples

### Tracking Temporary Resource Usage

```lua
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")

-- Create some temporary files and directories
for i = 1, 3 do
  local file_path, _ = temp_file.create_with_content("Content " .. i, "txt")
  print("Created file: " .. file_path)
end

local dir_path, _ = temp_file.create_temp_directory()
print("Created directory: " .. dir_path)

-- Create files in the directory
fs.write_file(dir_path .. "/file1.txt", "Nested file 1")
fs.write_file(dir_path .. "/file2.txt", "Nested file 2")

-- Get and print statistics
local stats = temp_file.get_stats()
print("\nTemporary Resource Statistics:")
print("  Total contexts: " .. stats.contexts)
print("  Total resources: " .. stats.total_resources)
print("  Files: " .. stats.files)
print("  Directories: " .. stats.directories)

-- List resources by context
print("\nResources by context:")
for context, context_stats in pairs(stats.resources_by_context) do
  print("  Context: " .. context)
  print("    Files: " .. context_stats.files)
  print("    Directories: " .. context_stats.directories)
  print("    Total: " .. context_stats.total)
end

-- Clean up all resources
print("\nCleaning up resources...")
local success, errors = temp_file.cleanup_all()

if success then
  print("All resources cleaned up successfully")
else
  print("Cleanup had errors: " .. #errors .. " errors")
  for i, err in ipairs(errors) do
    print("  Error " .. i .. ": Failed to clean up " .. err.type .. " at " .. err.path)
  end
end
```

### Integration Module Diagnostics

```lua
local temp_file = require("lib.tools.temp_file")
local temp_file_integration = require("lib.tools.temp_file_integration")
local firmo = require("firmo")

-- Initialize integration with Firmo
temp_file_integration.initialize(firmo)

-- Create some temporary files
for i = 1, 3 do
  local file_path, _ = temp_file.create_with_content("Content " .. i, "txt")
  print("Created file: " .. file_path)
end

-- Get integration statistics
local stats = temp_file_integration.get_stats()
print("\nIntegration Statistics:")
print("  Registered callbacks: " .. stats.registered_callbacks)
print("  Test starts handled: " .. stats.test_starts)
print("  Test ends handled: " .. stats.test_ends)
print("  Suite ends handled: " .. stats.suite_ends)
print("  Cleanup operations: " .. stats.cleanup_operations)
print("  Cleanup errors: " .. stats.cleanup_errors)
print("  Files cleaned: " .. stats.files_cleaned)
print("  Bytes cleaned: " .. stats.bytes_cleaned)

-- Clean up with multiple attempts for resilience
print("\nCleaning up with resilient strategy...")
local success, errors, stats = temp_file_integration.cleanup_all(3)

if success then
  print("All resources cleaned up successfully after " .. (stats.attempts or 1) .. " attempts")
else
  print("Cleanup still had " .. #errors .. " errors after " .. (stats.attempts or 1) .. " attempts")
end
```

## Complete End-to-End Example

```lua
local firmo = require("firmo")
local temp_file = require("lib.tools.temp_file")
local temp_file_integration = require("lib.tools.temp_file_integration")
local fs = require("lib.tools.filesystem")

-- Initialize the integration
temp_file_integration.initialize(firmo)

-- Extract test functions
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Example test suite with comprehensive temporary file usage
describe("Configuration Manager", function()
  -- Track temporary files for this test suite
  local test_resources = {}
  
  before(function()
    -- Create a test directory structure
    local config_dir, err = temp_file.create_temp_directory()
    expect(err).to_not.exist("Failed to create config directory")
    test_resources.config_dir = config_dir
    
    -- Create default config files
    fs.write_file(config_dir .. "/default.json", '{"log_level": "info", "timeout": 30}')
    fs.write_file(config_dir .. "/dev.json", '{"log_level": "debug", "timeout": 60}')
    fs.write_file(config_dir .. "/prod.json", '{"log_level": "error", "timeout": 10}')
  end)
  
  after(function()
    -- Display statistics (not needed, but useful for the example)
    local stats = temp_file.get_stats()
    print("Resources at end of test: " .. stats.total_resources)
    
    -- All resources will be cleaned up automatically
  end)
  
  describe("when loading configuration files", function()
    it("should load the default configuration", function()
      local default_path = test_resources.config_dir .. "/default.json"
      expect(fs.file_exists(default_path)).to.be_truthy("Default config file missing")
      
      local content = fs.read_file(default_path)
      expect(content).to.match("log_level")
      expect(content).to.match("info")
    end)
    
    it("should handle invalid configuration files", function()
      -- Create a temporary file with invalid JSON
      local invalid_file, err = temp_file.create_with_content("{invalid", "json")
      expect(err).to_not.exist("Failed to create invalid config file")
      
      -- Verify it exists but contains invalid content
      expect(fs.file_exists(invalid_file)).to.be_truthy("Invalid file wasn't created")
      local content = fs.read_file(invalid_file)
      expect(content).to.equal("{invalid")
      
      -- This file will be cleaned up automatically
    end)
    
    it("should merge configurations", function()
      -- Create a temporary directory for this specific test
      local test_dir, err = temp_file.create_temp_directory()
      expect(err).to_not.exist("Failed to create test directory")
      
      -- Create files needed just for this test
      fs.write_file(test_dir .. "/base.json", '{"setting1": "value1", "setting2": "value2"}')
      fs.write_file(test_dir .. "/override.json", '{"setting2": "new_value"}')
      
      -- Test code would go here
      -- ...
      
      -- This directory and its files will be cleaned up automatically
    end)
  end)
  
  describe("when generating configuration", function()
    it("should create properly formatted configuration files", function()
      -- Use with_temp_file pattern for this test
      local result, err = temp_file.with_temp_file("", function(output_path)
        -- Generate a config file at the output path
        fs.write_file(output_path, [[
{
  "generated": true,
  "timestamp": ]] .. os.time() .. [[,
  "settings": {
    "option1": true,
    "option2": 42
  }
}
]])
        
        -- Read back and test the generated file
        local content = fs.read_file(output_path)
        expect(content).to.match("generated")
        expect(content).to.match("timestamp")
        
        return "File generated successfully"
      end, "json")
      
      expect(err).to_not.exist("Error in with_temp_file")
      expect(result).to.equal("File generated successfully")
    end)
  end)
end)
```