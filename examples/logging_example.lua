-- Comprehensive Example of the Logging System
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

print("=== Firmo Logging System: Comprehensive Example ===\n")

-- SECTION 1: Basic Configuration and Usage
print("SECTION 1: Basic Configuration and Usage")
print("----------------------------------------")

-- Configure global logging
logging.configure({
  level = logging.LEVELS.INFO,     -- Global level
  timestamps = true,               -- Show timestamps
  use_colors = true,               -- Use ANSI colors
  buffer_size = 100,               -- Buffer up to 100 messages
  buffer_flush_interval = 5        -- Auto-flush buffer every 5 seconds
})

-- Create loggers for different modules
local app_logger = logging.get_logger("App")
local db_logger = logging.get_logger("Database")
local ui_logger = logging.get_logger("UI")

-- Set specific log levels for some modules
logging.set_module_level("Database", logging.LEVELS.WARN)  -- Less verbose
logging.set_module_level("UI", logging.LEVELS.DEBUG)       -- More verbose

-- Basic logging examples
app_logger.error("Critical application error")
app_logger.warn("Application warning")
app_logger.info("Application information")
app_logger.debug("Debug information - not shown with INFO level")
app_logger.verbose("Verbose information - not shown with INFO level")

-- Database logs (WARN level)
db_logger.error("Database connection error")
db_logger.warn("Slow query warning")
db_logger.info("Database info - not shown with WARN level")

-- UI logs (DEBUG level)
ui_logger.info("UI component loaded")
ui_logger.debug("UI render details") -- Shows because UI is set to DEBUG level
ui_logger.verbose("UI verbose details - not shown with DEBUG level")

-- SECTION 2: Structured Logging with Context
print("\nSECTION 2: Structured Logging with Context")
print("------------------------------------------")

-- Log with structured context data
app_logger.info("User authentication successful", {
  user_id = 12345,
  username = "example_user",
  login_time = os.time(),
  session_id = "sess_abc123"
})

-- Error with detailed context
db_logger.error("Database query failed", {
  query = "SELECT * FROM users WHERE id = ?",
  params = {42},
  error_code = "ER_ACCESS_DENIED",
  db_host = "localhost",
  retry_attempt = 2
})

-- SECTION 3: Context Manager and Level Changes
print("\nSECTION 3: Context Manager and Level Changes")
print("--------------------------------------------")

-- Temporarily change the log level
print("Temporarily changing log level to VERBOSE:")
logging.with_level("App", "verbose", function()
  -- Inside this block, VERBOSE level is enabled for App module
  app_logger.verbose("Detailed parameter values", {
    memory_usage = 1024 * 1024 * 45, -- 45MB
    cache_stats = { hits = 124, misses = 23 },
    connection_pool = { active = 5, idle = 10 }
  })
end)

-- After the block, the level returns to normal
app_logger.verbose("This verbose message should NOT appear")

-- SECTION 4: File Output and JSON Format
print("\nSECTION 4: File Output and JSON Format")
print("--------------------------------------")

-- Configure logging to write to files
local temp_log_path = os.tmpname()
local temp_json_path = os.tmpname() .. ".json"

logging.configure({
  level = logging.LEVELS.INFO,
  output_file = temp_log_path,   -- Text log file
  json_file = temp_json_path,    -- JSON structured log file
  standard_metadata = {          -- Metadata added to all logs
    app_version = "1.0.0",
    environment = "example"
  }
})

app_logger.info("This message is written to both log files")
db_logger.error("Database error with context", {
  error_type = "connection_timeout",
  source_file = "db_connector.lua",
  line = 42
})

-- Flush the buffer to ensure logs are written
logging.flush()

print("Log files written to:")
print("- Text log: " .. temp_log_path)
print("- JSON log: " .. temp_json_path)

-- SECTION 5: Error Handling Integration
print("\nSECTION 5: Error Handling Integration")
print("-------------------------------------")

-- Demonstrate logging with error objects
local function process_data(data)
  if type(data) ~= "table" then
    return nil, error_handler.validation_error(
      "Data must be a table",
      {parameter = "data", provided_type = type(data)}
    )
  end
  
  return true
end

-- Log the error with proper context
local success, result, err = error_handler.try(function()
  return process_data("not a table")
end)

if not success then
  app_logger.error("Failed to process data", {
    error = error_handler.format_error(result),
    error_details = result,
    operation = "process_data"
  })
end

-- SECTION 6: Performance and Conditional Logging
print("\nSECTION 6: Performance and Conditional Logging")
print("----------------------------------------------")

-- Demonstrate would_log for performance-sensitive contexts
if app_logger.would_log("debug") then
  -- Only calculate expensive debug data if debug level is enabled
  local debug_data = {
    -- Expensive to calculate metrics that we only want in debug mode
    memory_usage = collectgarbage("count") * 1024,
    num_tables = 0,
    -- Count tables in _G (just as an example of "expensive" calculation)
    -- In a real app, this might be a complex analysis of app state
    global_keys = setmetatable({}, {__mode = "k"})
  }
  
  for k, v in pairs(_G) do
    if type(v) == "table" then
      debug_data.num_tables = debug_data.num_tables + 1
      debug_data.global_keys[k] = true
    end
  end
  
  app_logger.debug("Memory and table statistics", debug_data)
end

-- SECTION 7: Configuring from Options
print("\nSECTION 7: Configuring from Options")
print("-----------------------------------")

-- Standard options object similar to what's used throughout firmo
local options = {
  debug = true,
  verbose = false,
  quiet = false
}

-- Configure module logging based on standard option patterns
logging.configure_from_options("ConfigModule", options)
local config_logger = logging.get_logger("ConfigModule")

config_logger.info("Config module initialized")
config_logger.debug("Debug message visible because debug=true")
config_logger.verbose("Verbose message hidden because verbose=false")

-- SECTION 8: Silent Mode for Testing
print("\nSECTION 8: Silent Mode for Testing")
print("----------------------------------")

-- Enable silent mode (useful during tests)
logging.silent_mode(true)
app_logger.error("This error won't appear in output (silent mode)")
app_logger.info("This info won't appear in output (silent mode)")

-- Disable silent mode
logging.silent_mode(false)
app_logger.info("Messages visible again after disabling silent mode")

-- Clean up temporary files
os.remove(temp_log_path)
os.remove(temp_json_path)

print("\n=== Logging Example Complete ===")
print("To use the logging system in your own code:")
print("1. Require the module: local logging = require('lib.tools.logging')")
print("2. Configure once: logging.configure({ level = logging.LEVELS.INFO, ... })")
print("3. Create loggers: local logger = logging.get_logger('MyModule')")
print("4. Log with context: logger.info('Message', { key = value })")