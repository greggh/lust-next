-- Example demonstrating the centralized logging system with config integration
local lust = require("lust-next")
local logging = require("lib.tools.logging")
local config = require("lib.core.config")
local fs = require("lib.tools.filesystem")

print("Logging with Global Config Example")
print("---------------------------------")

-- Create logs directory if it doesn't exist
fs.ensure_directory_exists("logs")

-- Remove any existing example log files
local example_log = "logs/config_example.log"
if fs.file_exists(example_log) then
  fs.remove_file(example_log)
end
for i = 1, 5 do
  local rotated_log = example_log .. "." .. i
  if fs.file_exists(rotated_log) then
    fs.remove_file(rotated_log)
  end
end

-- Create a temporary config for demonstration
local temp_config = {
  debug = true,    -- Enable debug logging globally
  verbose = false, -- Don't enable verbose logging
  
  -- Complete logging configuration
  logging = {
    level = 3,  -- Default to INFO
    timestamps = true,
    use_colors = true,
    output_file = "config_example.log",
    log_dir = "logs",
    max_file_size = 1024,  -- Small size (1KB) to demonstrate rotation
    max_log_files = 3,     -- Keep 3 rotated files
    
    -- Module-specific log levels
    modules = {
      -- Set specific log levels for different modules
      ConfigTest = logging.LEVELS.VERBOSE,  -- Extra verbose for this module
      SecondModule = logging.LEVELS.WARN,   -- Only warnings and errors for this module
      RotationDemo = logging.LEVELS.DEBUG   -- Demo of log rotation
    }
  }
}

-- Set the global config for this example
config.loaded = temp_config

print("\nUsing configure_from_config:")
print("---------------------------")

-- Configure loggers using the global config
logging.configure_from_config("ConfigTest")
logging.configure_from_config("SecondModule") 
logging.configure_from_config("DefaultModule") -- Not in config, should use global debug=true

-- Create loggers for different modules
local config_logger = logging.get_logger("ConfigTest")
local second_logger = logging.get_logger("SecondModule")
local default_logger = logging.get_logger("DefaultModule")

-- Demonstrate logging at different levels
print("\nTesting log levels based on configuration:")

-- ConfigTest logger (VERBOSE level)
config_logger.error("ConfigTest error message")
config_logger.warn("ConfigTest warning message")
config_logger.info("ConfigTest info message")
config_logger.debug("ConfigTest debug message - visible because debug=true")
config_logger.verbose("ConfigTest verbose message - visible because explicitly set to VERBOSE")

-- SecondModule logger (WARN level)
second_logger.error("SecondModule error message - always visible")
second_logger.warn("SecondModule warning message - visible at WARN level")
second_logger.info("SecondModule info message - hidden at WARN level")
second_logger.debug("SecondModule debug message - hidden at WARN level")

-- DefaultModule logger (inherits global DEBUG level)
default_logger.error("DefaultModule error message")
default_logger.warn("DefaultModule warning message")
default_logger.info("DefaultModule info message")
default_logger.debug("DefaultModule debug message - visible because global debug=true")
default_logger.verbose("DefaultModule verbose message - hidden because global verbose=false")

-- Show how a module would typically use this
print("\nTypical Module Initialization with Global Config:")
print("----------------------------------------------")

function example_module_init()
  print("Initializing example module...")
  
  -- Just one line to configure logging - no need to pass config
  logging.configure_from_config("ExampleModule")
  
  local logger = logging.get_logger("ExampleModule")
  logger.info("Example module initialized")
  logger.debug("Debug details about initialization (visible with debug=true)")
  
  return { name = "ExampleModule" }
end

-- Run the example initialization
local module = example_module_init()

-- Create a special logger to demonstrate log rotation
print("\nDemonstrating log rotation:")
print("-------------------------")
logging.configure_from_config("RotationDemo")  
local rotation_logger = logging.get_logger("RotationDemo")

-- Generate enough logs to trigger rotation
print("Writing logs to trigger rotation...")
for i = 1, 50 do
  rotation_logger.debug("Log entry " .. i .. ": " .. string.rep("x", 30))
end

-- Check if log rotation worked
print("Checking for rotated log files...")
if fs.file_exists(example_log) then
  print("- Main log file exists: " .. example_log)
end

for i = 1, 3 do
  local rotated_log = example_log .. "." .. i
  if fs.file_exists(rotated_log) then
    print("- Rotated log file exists: " .. rotated_log)
  end
end

print("\nLog files have been created in the logs directory:")
print("- logs/config_example.log (main log file)")
print("- logs/config_example.log.[1-3] (rotated log files)")

print("\nDone! Global config-based logging is working correctly with log rotation.")