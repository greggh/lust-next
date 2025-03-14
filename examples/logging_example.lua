-- Example showing how to use the logging module
local lust_next = require('lust-next')
local logging = require('lib.tools.logging')

print("Logging Module Example")
print("----------------------")

-- Configure global logging
logging.configure({
  level = logging.LEVELS.INFO,     -- Global level
  timestamps = true,               -- Show timestamps
  use_colors = true                -- Use ANSI colors
})

-- Create loggers for different modules
local app_logger = logging.get_logger("App")
local db_logger = logging.get_logger("Database")
local ui_logger = logging.get_logger("UI")

-- Set specific log levels for some modules
logging.set_module_level("Database", logging.LEVELS.WARN)  -- Less verbose
logging.set_module_level("UI", logging.LEVELS.DEBUG)       -- More verbose

print("\nBasic logging examples:")
print("-----------------------")

-- Application logs
app_logger.error("Critical application error")
app_logger.warn("Application warning")
app_logger.info("Application information")
app_logger.debug("Debug information - not shown with INFO level")
app_logger.verbose("Verbose information - not shown with INFO level")

-- Database logs
print("\nModule-specific levels:")
print("----------------------")
db_logger.error("Database connection error")
db_logger.warn("Slow query warning")
db_logger.info("Database info - not shown with WARN level")

-- UI logs - will show debug but not verbose
ui_logger.info("UI component loaded")
ui_logger.debug("UI render details") -- Shows because UI is set to DEBUG level

-- Temporarily enable verbose logging globally
print("\nChanging global log level:")
print("------------------------")
logging.set_level(logging.LEVELS.VERBOSE)

app_logger.verbose("Now verbose logs appear everywhere")
db_logger.verbose("Even in database module")

-- Restore normal settings
logging.set_level(logging.LEVELS.INFO)

-- Using the helper function to configure logging from options
print("\nUsing configure_from_options:")
print("----------------------------")

-- Standard options object similar to what's used throughout the codebase
local options = {
  debug = true,
  verbose = false
}

-- Use the helper function to configure logging from standard options
logging.configure_from_options("ConfigModule", options)
local config_logger = logging.get_logger("ConfigModule")

config_logger.info("Config module info message")
config_logger.debug("Debug message is visible because debug=true")
config_logger.verbose("Verbose message hidden because verbose=false")

-- Change options to show verbose output
local verbose_options = {
  debug = false,
  verbose = true
}

logging.configure_from_options("VerboseModule", verbose_options)
local verbose_logger = logging.get_logger("VerboseModule")

verbose_logger.info("VerboseModule info message")
verbose_logger.debug("Debug message hidden because debug=false")
verbose_logger.verbose("Verbose message visible because verbose=true")

-- Log to a file
print("\nConfiguring file output:")
print("-----------------------")
logging.configure({
  output_file = "/tmp/lust-next-log.txt"
})

app_logger.info("This message goes to both console and file")
print("Check /tmp/lust-next-log.txt for the log file")

print("\nDone! Your logging module is working correctly.")