#!/usr/bin/env lua
-- Example demonstrating advanced logging configuration with JSON structured logging

local lust = require("lust-next")
local logging = require("lib.tools.logging")

-- Create a custom logger for this example
local logger = logging.get_logger("json_logging_example")

-- Configure logging with JSON structured output
logging.configure({
  level = logging.LEVELS.DEBUG,  -- Enable all log levels for this example
  timestamps = true,             -- Enable timestamps in output
  use_colors = true,             -- Keep colors for console output
  output_file = "example.log",   -- Regular text log file
  json_file = "example.json",    -- JSON structured log file for machine processing
  log_dir = "logs",              -- Directory for log files
  max_file_size = 10 * 1024,     -- 10KB max file size (small for demo purposes)
  max_log_files = 3,             -- Keep 3 rotated log files
  module_filter = {"json_logging_example", "lust*"} -- Only log from these modules
})

-- Print information about the configuration
logger.info("Logging system configured with JSON structured output")
logger.info("Log files will be stored in the 'logs' directory")

-- Demonstrate different log levels
logger.error("This is an ERROR message - something has gone seriously wrong")
logger.warn("This is a WARNING - something unexpected happened but we can continue")
logger.info("This is an INFO message - general information about system operation")
logger.debug("This is a DEBUG message - detailed information for debugging purposes")
logger.verbose("This is a VERBOSE message - extremely detailed diagnostic information")

-- Demonstrate module filtering
local other_logger = logging.get_logger("filtered_module")
other_logger.info("This message won't appear due to module filtering")

-- Demonstrate module blacklisting
logging.clear_module_filters()  -- Clear existing filters
logging.blacklist_module("blacklisted_module")

local blacklisted = logging.get_logger("blacklisted_module")
blacklisted.info("This message won't appear due to module blacklisting")

local normal = logging.get_logger("normal_module")
normal.info("This message will appear since the module isn't blacklisted")

-- Demonstrate JSON structured logging format
logger.info("The above messages are being written in both text and JSON formats")
logger.info("Check the logs directory for the example.json file")
logger.debug("JSON logs are ideal for machine processing and analysis tools")

-- Generate a complex log message that demonstrates JSON escaping
logger.info("Complex JSON data: {\"user\":\"test\", \"status\":\"active\", \"values\":[1,2,3]}")

-- Show information about log files
logger.info("Log file rotation will happen when files exceed 10KB")
logger.info("Rotated files will have .1, .2, etc. appended to their names")

-- Testing message
logger.info("Run this example a few times to see log rotation in action")

print("\nCheck the logs directory for the following files:")
print("- logs/example.log: Regular text log file")
print("- logs/example.json: JSON structured log file")
print("\nThe JSON log contains structured data that can be parsed by log analysis tools.")