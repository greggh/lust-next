-- Example demonstrating the centralized logging system with config integration
local lust = require("lust-next")
local logging = require("lib.tools.logging")
local config = require("lib.core.config")

print("Logging with Global Config Example")
print("---------------------------------")

-- Create a temporary config for demonstration
local temp_config = {
  debug = true,    -- Enable debug logging globally
  verbose = false, -- Don't enable verbose logging
  
  -- Module-specific logging configuration
  logging = {
    modules = {
      -- Set specific log levels for different modules
      ConfigTest = logging.LEVELS.VERBOSE,  -- Extra verbose for this module
      SecondModule = logging.LEVELS.WARN    -- Only warnings and errors for this module
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

print("\nDone! Global config-based logging is working correctly.")