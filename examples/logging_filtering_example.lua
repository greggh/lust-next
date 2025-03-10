#!/usr/bin/env lua
-- Example demonstrating module filtering and log level control for the logging system

local lust = require("lust-next")
local logging = require("lib.tools.logging")

-- Initialize several loggers for different modules to demonstrate filtering
local ui_logger = logging.get_logger("ui")
local network_logger = logging.get_logger("network")
local database_logger = logging.get_logger("database")
local api_logger = logging.get_logger("api")
local test_logger = logging.get_logger("test")

-- Configure basic logging parameters
logging.configure({
  level = logging.LEVELS.INFO,  -- Default global level
  timestamps = true,            -- Show timestamps
  use_colors = true,            -- Use ANSI colors
  output_file = "filtered.log", -- Log file
  log_dir = "logs"              -- Log directory
})

-- Show initial state
print("\n=== Initial state (all modules at INFO level) ===")
ui_logger.info("UI module info message - visible")
ui_logger.debug("UI module debug message - hidden (below threshold)")
network_logger.info("Network module info message - visible")
database_logger.info("Database module info message - visible")

-- Set specific levels for different modules
print("\n=== Module-specific log levels ===")
logging.set_module_level("ui", logging.LEVELS.ERROR)       -- Only errors from UI
logging.set_module_level("network", logging.LEVELS.DEBUG)  -- Debug and above from network
logging.set_module_level("database", logging.LEVELS.WARN)  -- Warning and above from database

ui_logger.warn("UI module warning - hidden (below ERROR threshold)")
ui_logger.error("UI module error - visible (at ERROR level)")
network_logger.info("Network info - visible (above DEBUG threshold)")
network_logger.debug("Network debug - visible (at DEBUG level)")
database_logger.warn("Database warning - visible (at WARN level)")
database_logger.info("Database info - hidden (below WARN threshold)")

-- Apply module filtering (only show logs from specific modules)
print("\n=== Module filtering (only UI and API logs) ===")
logging.filter_module("ui")
logging.filter_module("api")

ui_logger.error("UI error - visible (module is in filter)")
network_logger.error("Network error - hidden (module not in filter)")
api_logger.info("API info - visible (module is in filter)")
database_logger.error("Database error - hidden (module not in filter)")

-- Show wildcard patterns
print("\n=== Wildcard pattern filtering ===")
logging.clear_module_filters()  -- Clear existing filters
logging.filter_module("test*")  -- Any module starting with "test"

test_logger.info("Test module - visible (matches wildcard)")
logging.get_logger("test_ui").info("Test UI module - visible (matches wildcard)")
logging.get_logger("testing").info("Testing module - visible (matches wildcard)")
ui_logger.info("UI module - hidden (doesn't match wildcard)")

-- Demonstrate blacklisting
print("\n=== Module blacklisting ===")
logging.clear_module_filters()  -- Clear existing filters
logging.blacklist_module("database")  -- Blacklist database module

ui_logger.info("UI module - visible (not blacklisted)")
network_logger.info("Network module - visible (not blacklisted)")
database_logger.error("Database error - hidden (module is blacklisted)")
api_logger.info("API module - visible (not blacklisted)")

-- Show wildcard blacklisting
print("\n=== Wildcard blacklisting ===")
logging.clear_blacklist()
logging.blacklist_module("test*")  -- Blacklist any module starting with "test"

ui_logger.info("UI module - visible (not blacklisted)")
test_logger.info("Test module - hidden (matches blacklist wildcard)")
logging.get_logger("test_ui").info("Test UI - hidden (matches blacklist wildcard)")

-- Reset everything
print("\n=== Reset to normal state ===")
logging.clear_module_filters()
logging.clear_blacklist()
logging.set_level(logging.LEVELS.INFO)  -- Set global level back to INFO

ui_logger.info("UI module - visible")
network_logger.info("Network module - visible")
database_logger.info("Database module - visible")
test_logger.info("Test module - visible")

-- Show the filter configuration
print("\n=== Current configuration ===")
local config = logging.get_config()
print("Global log level: " .. (config.global_level or "nil"))
print("Module filters: " .. (config.module_filter and 
    (type(config.module_filter) == "table" and table.concat(config.module_filter, ", ") or 
    tostring(config.module_filter)) or "nil"))
print("Module blacklist: " .. (#config.module_blacklist > 0 and table.concat(config.module_blacklist, ", ") or "none"))
print("Module-specific levels:")
for module, level in pairs(config.module_levels) do
  print("  " .. module .. ": " .. level)
end

print("\nLog filtering allows you to control which messages appear from specific modules.")
print("This is useful when debugging a specific part of the application, or to reduce noise.")
print("The logs directory will contain a filtered.log file with this example's output.")