-- Test script to understand how the --debug flag works
local logging = require("lib.tools.logging")

-- Get logger config
local config = logging.get_config()
print("Global log level: " .. config.global_level)

-- Create test loggers
local logger1 = logging.get_logger("Module1")
local logger2 = logging.get_logger("Module2")

-- Print debug level status
print("Module1 debug enabled: " .. tostring(logger1.is_debug_enabled()))
print("Module2 debug enabled: " .. tostring(logger2.is_debug_enabled()))

-- Log at different levels
print("\nLogging at different levels:")
logger1.error("ERROR from Module1")
logger1.warn("WARN from Module1")
logger1.info("INFO from Module1")
logger1.debug("DEBUG from Module1")

logger2.error("ERROR from Module2")
logger2.warn("WARN from Module2")
logger2.info("INFO from Module2")
logger2.debug("DEBUG from Module2")