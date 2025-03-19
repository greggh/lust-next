-- Test script to verify debug logging behavior
local logging = require("lib.tools.logging")

-- Create test loggers
local logger1 = logging.get_logger("Module1")
local logger2 = logging.get_logger("Module2")

-- Print diagnostic info
print("Debug flag detection:")
print("_G._firmo_debug_mode:", _G._firmo_debug_mode)

print("\nLogger configuration:")
print("Module1 debug enabled:", logger1.is_debug_enabled())
print("Module2 debug enabled:", logger2.is_debug_enabled())

print("\nLogging levels:")
local config = logging.get_config()
print("Global level:", config.global_level)
print("DEBUG level constant:", logging.LEVELS.DEBUG)
print("INFO level constant:", logging.LEVELS.INFO)

-- Try to set all loggers to DEBUG level
logging.set_level(logging.LEVELS.DEBUG)

print("\nAfter setting global level to DEBUG:")
print("Module1 debug enabled:", logger1.is_debug_enabled())
print("Module2 debug enabled:", logger2.is_debug_enabled())

-- Test logging with DEBUG level
print("\nLogging at DEBUG level:")
logger1.debug("DEBUG from Module1")
logger2.debug("DEBUG from Module2")