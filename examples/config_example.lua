-- Configuration system example for lust-next
--
-- This example demonstrates how to use the configuration system in lust-next.
-- Run with: lua examples/config_example.lua

local lust = require("lust-next")

print("lust-next Configuration System Example")
print("=====================================")
print("")

-- Import the filesystem module
local fs = require("lib.tools.filesystem")

-- Create and load a temporary config file
local temp_config_path = "temp_config.lua"
local content = [[
-- Temporary configuration file for demo purposes
return {
  -- Output Formatting
  format = {
    use_color = true,
    indent_char = '  ',  -- Use spaces instead of tabs
    indent_size = 2,     -- Use 2 spaces for indentation
    show_trace = true,   -- Show stack traces for errors
    show_success_detail = true,
    default_format = "dot", -- Use dot format for tests
  },
  
  -- Parallel Execution
  parallel = {
    workers = 2,         -- Use only 2 workers for parallel execution
    timeout = 30,        -- Reduce timeout to 30 seconds
  },
  
  -- Custom formatting
  reporting = {
    report_dir = "./custom-reports",
    timestamp_format = "%Y%m%d-%H%M",
  }
}
]]

local success, err = fs.write_file(temp_config_path, content)
if success then
  print("Created temporary config file at " .. temp_config_path)
else
  print("Failed to create temporary config file: " .. (err or "unknown error"))
  os.exit(1)
end

-- Step 1: Load the configuration file
print("\nStep 1: Load the configuration file")
local config, err = lust.config.load_from_file(temp_config_path)
if config then
  print("Successfully loaded configuration from " .. temp_config_path)
else
  print("Failed to load configuration: " .. tostring(err))
  os.exit(1)
end

-- Step 2: Apply the configuration to lust
print("\nStep 2: Apply the configuration")
lust.config.apply_to_lust(lust)

-- Step 3: Verify the configuration was applied
print("\nStep 3: Verify the configuration was applied")
print("Format options:")
print("  indent_char: '" .. lust.format_options.indent_char .. "'")
print("  indent_size: " .. lust.format_options.indent_size)
print("  show_trace: " .. tostring(lust.format_options.show_trace))
print("  dot_mode: " .. tostring(lust.format_options.dot_mode))

print("\nParallel options:")
print("  workers: " .. lust.parallel.options.workers)
print("  timeout: " .. lust.parallel.options.timeout)

print("\nReporting options:")
print("  report_dir: " .. lust.report_config.report_dir)
print("  timestamp_format: " .. lust.report_config.timestamp_format)

-- Step 4: Run a simple test with the new configuration
print("\nStep 4: Run a simple test with the new configuration")
print("Note the dot format output (.F) and 2-space indentation:")

-- Define a test suite
lust.describe("Configuration Example", function()
  lust.it("should pass", function()
    lust.expect(true).to.be(true)
  end)
  
  lust.it("should fail for demonstration", function()
    lust.expect(true).to.be(false)
  end)
end)

-- Clean up the temporary file
local delete_success, delete_err = fs.delete_file(temp_config_path)
if delete_success then
  print("\nRemoved temporary config file: " .. temp_config_path)
else
  print("\nFailed to remove temporary config file: " .. (delete_err or "unknown error"))
end
print("\nIn a real project, you would create a .lust-next-config.lua file in your project root.")
print("Use 'lua lust-next.lua --create-config' to generate a template configuration file.")