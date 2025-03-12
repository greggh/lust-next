-- Simple example demonstrating the logging system
local logging = require("lib.tools.logging")

-- Configure logging with minimal output
logging.configure({
  level = logging.LEVELS.INFO,
  module_blacklist = {"filesystem"},  -- Disable filesystem module logs
  timestamps = true,
  use_colors = true
})

-- Create a logger for this example
local logger = logging.get_logger("simple_example")

print("=== Simple Logging Example ===")
print("")

-- Demonstrate different log levels
logger.fatal("A fatal error occurred", {error_code = "F001"})
logger.error("An error occurred", {error_code = "E001"})
logger.warn("A warning occurred", {code = "W001"})
logger.info("An informational message", {status = "success"})
logger.debug("A debug message", {debug_data = {key = "value"}})  -- Won't appear at INFO level
logger.trace("A trace message", {function_name = "test"})  -- Won't appear at INFO level

print("\nOnly FATAL, ERROR, WARN, and INFO messages are shown by default")
print("To see DEBUG and TRACE messages, change the level:")

-- Enable debug logs
logging.set_level(logging.LEVELS.DEBUG)
print("\nAfter setting level to DEBUG:")
logger.debug("Now debug messages appear", {debug_key = "debug_value"})

-- Enable all logs
logging.set_level(logging.LEVELS.TRACE)
print("\nAfter setting level to TRACE:")
logger.trace("Now trace messages appear too", {trace_key = "trace_value"})