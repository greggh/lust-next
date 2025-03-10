-- Example showcasing the updated logging system with structured messages
local logging = require("lib.tools.logging")

-- Configure with structured JSON logging
logging.configure({
  level = logging.LEVELS.DEBUG,       -- Set default level to DEBUG
  timestamps = true,                  -- Include timestamps
  use_colors = true,                  -- Use colors for console output
  output_file = "structured.log",     -- Log to file
  json_file = "structured.json",      -- Output structured JSON logs
  buffer_size = 10,                   -- Buffer logs in memory (10 entries)
  buffer_flush_interval = 5,          -- Flush every 5 seconds
  standard_metadata = {               -- Standard fields for all logs
    app_version = "1.0.0",
    environment = "development",
    host = "example-host"
  }
})

-- Create a module-specific logger
local logger = logging.get_logger("structured_example")

print("=== Structured Logging Example ===")
print("")
print("This example demonstrates:")
print("1. Proper message formatting (separate message from data)")
print("2. JSON structured logging with parameters")
print("3. Buffer-based logging for high volume scenarios")
print("4. Standard metadata fields in all logs")
print("")

-- Examples of properly structured log messages
logger.info("Application started", {
  startup_time_ms = 234,
  config_file = "/etc/app/config.json"
})

-- Log error with parameters
logger.error("Failed to connect to database", {
  db_host = "localhost",
  db_port = 5432,
  error_code = "ECONNREFUSED",
  retry_count = 3
})

-- Log API request with structured data
logger.info("Processed API request", {
  endpoint = "/api/users",
  method = "POST",
  status_code = 200,
  request_id = "req-1234",
  duration_ms = 125,
  user_id = 42
})

-- Demonstrate conditional logging
if logger.would_log("debug") then
  -- Only calculate expensive debug data if debug level is enabled
  local debug_data = {
    memory_usage = 1024 * 1024 * 45, -- 45MB
    cache_stats = {
      hits = 124,
      misses = 23,
      ratio = 0.84
    },
    connection_pool = {
      active = 5,
      idle = 10,
      max = 20
    }
  }
  
  logger.debug("System status", debug_data)
end

-- Use dynamic level from string
logger.log(logging.LEVELS.WARN, "Configuration issue detected", {
  config_key = "timeout",
  expected = "number",
  received = "string",
  using_default = true
})

-- Buffer high-volume logs (these will be buffered and written in batch)
for i = 1, 15 do
  logger.debug("Processing item in loop", {
    index = i,
    total = 15,
    item_id = "item-" .. i,
    processing_time_ms = 10 + i
  })
end

-- Force flush the buffer
logging.flush()
logger.info("Buffer flushed", {count = 15})

-- Demonstrate level changes with context manager
logging.with_level("structured_example", "trace", function()
  -- Inside this block, trace level is enabled for the module
  logger.trace("Temporary trace enabled", {
    function_name = "process_data",
    args = {limit = 100, offset = 0}
  })
end)

-- After the block, the level returns to normal
logger.trace("This trace message should NOT appear")

-- Fatal error example
logger.fatal("Critical system failure", {
  component = "data_processor",
  error = "Out of memory",
  memory_used_mb = 1954,
  memory_limit_mb = 2048
})

print("")
print("The logs have been written to:")
print("- Console (human-readable format)")
print("- logs/structured.log (human-readable format)")
print("- logs/structured.json (machine-readable JSON)")
print("")
print("Examine these files to see the difference in formats")