-- Complete example demonstrating all logging features
local logging = require("lib.tools.logging")

print("=== Complete Logging Features Example ===")
print("")
print("This example demonstrates ALL available logging features:")
print("1. Core logging functionality with structured parameters")
print("2. Buffering for high-volume logging")
print("3. Search capabilities for log analysis")
print("4. Export to external analysis tools")
print("5. Integration with test output formatters")
print("6. Silent mode for testing output-sensitive code")
print("7. Module filtering and blacklisting")
print("")

-- Configure logging with comprehensive settings
logging.configure({
  level = logging.LEVELS.DEBUG,        -- Set default level to DEBUG
  timestamps = true,                   -- Include timestamps
  use_colors = true,                   -- Use colors for console output
  output_file = "complete_example.log", -- Log to file
  json_file = "complete_example.json", -- Output structured JSON logs
  log_dir = "logs",                    -- Store logs in logs/ directory
  buffer_size = 20,                    -- Buffer logs (20 entries)
  buffer_flush_interval = 5,           -- Flush every 5 seconds
  standard_metadata = {                -- Standard fields for all logs
    app_version = "1.0.0",
    environment = "development"
  }
})

-- Create a regular logger
local logger = logging.get_logger("complete_example")

-- Create a buffered logger for high-volume operations
local buffered_logger = logging.create_buffered_logger("high_volume", {
  buffer_size = 50,                    -- Buffer 50 entries before writing
  flush_interval = 2,                  -- Flush every 2 seconds
  output_file = "high_volume.log"      -- Separate log file
})

print("=== 1. Core Logging Functionality ===")
logger.info("Application started", {
  startup_time_ms = 234,
  config_file = "/etc/app/config.json"
})

logger.debug("Configuration loaded", {
  settings = {
    timeout = 30,
    retry_count = 3,
    cache_enabled = true
  }
})

logger.warn("Resource usage high", {
  cpu_percent = 78,
  memory_mb = 1256,
  disk_io_ops = 450
})

logger.error("Failed to connect to service", {
  service = "database",
  host = "db.example.com",
  port = 5432,
  error = "Connection refused"
})

-- Demonstrate all levels
print("\nDemonstrating all log levels:")
logger.fatal("Fatal error example", {error_code = "F001"})
logger.error("Error example", {error_code = "E001"})
logger.warn("Warning example", {code = "W001"})
logger.info("Info example", {status = "healthy"})
logger.debug("Debug example", {detail = "connection pool size: 10"})
logger.trace("Trace example", {function_name = "process_item", args = {id = 123}})

print("\n=== 2. Buffered Logging for High Volume ===")
print("Generating high-volume logs (buffered)...")

-- Generate some high-volume logs
for i = 1, 40 do
  buffered_logger.debug("Processing item", {
    index = i,
    item_id = "ITEM-" .. i,
    status = i % 3 == 0 and "completed" or "in_progress",
    processing_time_ms = 10 + i * 2
  })
end

-- Manually flush the buffer
buffered_logger.flush()
print("Buffered logs flushed to disk")

print("\n=== 3. Log Search Capabilities ===")
-- Load search module
local search = logging.search()

-- Demonstrate simple search
print("Searching for ERROR level logs:")
local error_results = search.search_logs({
  log_file = "logs/complete_example.log",
  level = "ERROR"
})

if error_results and error_results.count > 0 then
  print(string.format("Found %d ERROR logs", error_results.count))
  
  -- Show the first result
  if error_results.entries and error_results.entries[1] then
    local entry = error_results.entries[1]
    print(string.format("  - [%s] %s: %s", 
      entry.timestamp or "", entry.module or "", entry.message or ""))
  end
end

-- Get statistics
print("\nGathering log statistics:")
local stats = search.get_log_stats("logs/complete_example.log")
if stats then
  print(string.format("Total log entries: %d", stats.total_entries))
  print("Log level distribution:")
  for level, count in pairs(stats.by_level or {}) do
    print(string.format("  - %s: %d", level, count))
  end
  print(string.format("Errors: %d, Warnings: %d", stats.errors or 0, stats.warnings or 0))
end

print("\n=== 4. Export to External Analysis Tools ===")
-- Load export module
local export = logging.export()

-- Get supported platforms
local platforms = export.get_supported_platforms()
print("Supported export platforms:")
for i, platform in ipairs(platforms) do
  print(string.format("  %d. %s", i, platform))
end

-- Create export example for Elasticsearch
print("\nExporting logs to Elasticsearch format:")
local export_result = export.create_platform_file(
  "logs/complete_example.json",
  "elasticsearch",
  "logs/export_elasticsearch.json",
  {
    environment = "demo",
    service_name = "lust-next-complete-example"
  }
)

if export_result then
  print(string.format("Exported %d entries to Elasticsearch format", 
    export_result.entries_processed))
end

print("\n=== 5. Test Formatter Integration ===")
-- Load formatter integration module
local formatter_integration = logging.formatter_integration()

-- Create a test logger with context
local test_logger = formatter_integration.create_test_logger("Example Test", {
  suite = "Demo",
  category = "Example"
})

-- Use the test logger with steps
test_logger.info("Starting example test")
local step1_logger = test_logger.step("First Step")
step1_logger.debug("Executing first step", {parameter = "value"})
step1_logger.info("First step completed")

local step2_logger = test_logger.step("Second Step")
step2_logger.debug("Executing second step", {item_count = 42})
step2_logger.info("Second step completed")

test_logger.info("Test completed successfully")

print("Test logging with context completed")

print("\n=== 6. Silent Mode for Testing ===")
-- Enable silent mode
print("Enabling silent mode (no log output)...")
logging.configure({silent = true})

-- These logs should not appear
logger.info("This log should NOT appear")
logger.error("This error should NOT appear", {error = "test"})

-- Disable silent mode
logging.configure({silent = false})
logger.info("Logging enabled again", {silent_mode = false})

print("Silent mode demonstrated")

print("\n=== 7. Module Filtering and Blacklisting ===")
-- Create some additional loggers
local ui_logger = logging.get_logger("ui")
local api_logger = logging.get_logger("api")
local db_logger = logging.get_logger("database")

-- Normal logging (all modules)
print("Normal logging (all modules):")
ui_logger.info("UI module log")
api_logger.info("API module log")
db_logger.info("Database module log")

-- Filter to specific module
print("\nFiltering to UI module only:")
logging.filter_module("ui")
ui_logger.info("UI module log (should appear)")
api_logger.info("API module log (should NOT appear)")
db_logger.info("API module log (should NOT appear)")

-- Clear filters
logging.clear_module_filters()

-- Blacklist a module
print("\nBlacklisting database module:")
logging.blacklist_module("database")
ui_logger.info("UI module log (should appear)")
api_logger.info("API module log (should appear)")
db_logger.info("Database module log (should NOT appear)")

-- Clear blacklist
logging.clear_blacklist()
logger.info("All modules enabled again")

print("\n=== All Features Demonstrated ===")
print("")
print("Log files created:")
print("- logs/complete_example.log - Main log file (text format)")
print("- logs/complete_example.json - Structured JSON logs")
print("- logs/high_volume.log - Buffered high-volume logs")
print("- logs/export_elasticsearch.json - Example export for Elasticsearch")
print("")
print("This comprehensive example demonstrated all the advanced logging")
print("capabilities including buffering, search, export and test integration.")