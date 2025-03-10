-- Example demonstrating advanced module filtering capabilities
local logging = require("lib.tools.logging")

-- Configure logging with module-specific settings
logging.configure({
  level = logging.LEVELS.INFO,         -- Default global level is INFO
  timestamps = true,
  use_colors = true,
  output_file = "module_filtering.log",
  json_file = "module_filtering.json",
  module_levels = {
    ["api"] = logging.LEVELS.ERROR,       -- API module shows only errors
    ["database"] = logging.LEVELS.DEBUG,  -- Database module is more verbose
    ["ui.*"] = logging.LEVELS.WARN,       -- All UI modules use warn level
  },
  -- Only include these modules in output (whitelist)
  module_filter = {
    "api", 
    "database", 
    "ui.*",
    "security"
  },
  -- Blacklist specific modules, even if they would match the filter
  module_blacklist = {
    "ui.debug"  -- Don't show ui.debug logs
  }
})

print("=== Module Filtering Example ===")
print("")
print("This example demonstrates:")
print("1. Module-specific log levels")
print("2. Module whitelisting with wildcards")
print("3. Module blacklisting")
print("4. Effective level calculation")
print("")

-- Create loggers for different modules
local api_logger = logging.get_logger("api")
local db_logger = logging.get_logger("database")
local ui_core_logger = logging.get_logger("ui.core")
local ui_debug_logger = logging.get_logger("ui.debug")
local security_logger = logging.get_logger("security")
local ignored_logger = logging.get_logger("ignored.module")

print("Module effective levels:")
print("- api: " .. api_logger.get_level())
print("- database: " .. db_logger.get_level())
print("- ui.core: " .. ui_core_logger.get_level())
print("- ui.debug: " .. ui_debug_logger.get_level() .. " (but blacklisted)")
print("- security: " .. security_logger.get_level())
print("- ignored.module: " .. ignored_logger.get_level() .. " (but not in whitelist)")
print("")

-- Log at different levels for each module
print("Logging at different levels for each module...")

-- API module (only ERROR level will be visible)
api_logger.trace("API trace message", {op = "trace"})
api_logger.debug("API debug message", {op = "debug"})
api_logger.info("API info message", {op = "info"})
api_logger.warn("API warning message", {op = "warn"})
api_logger.error("API error message", {op = "error"})

-- Database module (DEBUG and above will be visible)
db_logger.trace("Database trace message", {op = "trace"})
db_logger.debug("Database debug message", {op = "debug"})
db_logger.info("Database info message", {op = "info"})
db_logger.warn("Database warning message", {op = "warn"})
db_logger.error("Database error message", {op = "error"})

-- UI Core module (WARN and above will be visible due to wildcard match)
ui_core_logger.debug("UI Core debug message", {op = "debug"})
ui_core_logger.info("UI Core info message", {op = "info"})
ui_core_logger.warn("UI Core warning message", {op = "warn"})
ui_core_logger.error("UI Core error message", {op = "error"})

-- UI Debug module (should not be visible at all due to blacklist)
ui_debug_logger.debug("UI Debug debug message", {op = "debug"})
ui_debug_logger.warn("UI Debug warning message", {op = "warn"})
ui_debug_logger.error("UI Debug error message", {op = "error"})

-- Security module (INFO and above will be visible - follows global level)
security_logger.debug("Security debug message", {op = "debug"})
security_logger.info("Security info message", {op = "info"})
security_logger.warn("Security warning message", {op = "warn"})
security_logger.error("Security error message", {op = "error"})

-- Ignored module (not in whitelist, should not be visible)
ignored_logger.info("Ignored module info", {op = "info"})
ignored_logger.error("Ignored module error", {op = "error"})

-- Dynamic modification of filters
print("\nDynamically modifying module filters...")

-- Add ignored module to whitelist
logging.filter_module("ignored.module")
ignored_logger.error("Ignored module now visible", {op = "error"})

-- Remove a module from blacklist
logging.remove_from_blacklist("ui.debug")
ui_debug_logger.warn("UI Debug now visible", {op = "warn"})

-- Temporarily enable trace level for database
print("\nTemporarily enabling TRACE level for database module...")
logging.with_level("database", "trace", function()
  db_logger.trace("Database trace now visible", {op = "trace_enabled"})
end)
db_logger.trace("Database trace not visible again", {op = "trace_disabled"})

print("")
print("Logs have been written to:")
print("- Console")
print("- logs/module_filtering.log")
print("- logs/module_filtering.json")
print("")
print("Observe which messages appear based on module filtering rules.")