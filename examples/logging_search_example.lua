-- Example demonstrating log search capabilities
local logging = require("lib.tools.logging")
local log_search = require("lib.tools.logging.search")

-- First, let's generate some sample logs
print("=== Log Search Example ===")
print("")
print("This example demonstrates:")
print("1. Generating sample logs")
print("2. Searching logs by various criteria")
print("3. Getting log statistics")
print("4. Exporting logs to different formats")
print("")

-- Configure logging
logging.configure({
  level = logging.LEVELS.DEBUG,
  timestamps = true,
  use_colors = true,
  output_file = "search_example.log",
  json_file = "search_example.json",
  log_dir = "logs"
})

-- Create some loggers
local ui_logger = logging.get_logger("ui")
local api_logger = logging.get_logger("api")
local db_logger = logging.get_logger("database")

-- Generate sample logs
print("Generating sample logs...")

-- UI logs
ui_logger.info("Application started", {version = "1.0.0"})
ui_logger.debug("Rendering main window", {width = 800, height = 600})
ui_logger.debug("Loading resources", {count = 42})
ui_logger.info("User logged in", {user_id = 123, username = "test_user"})
ui_logger.warn("Slow render detected", {component = "chart", duration_ms = 150})

-- API logs
api_logger.info("API server started", {port = 8080})
api_logger.debug("Request received", {method = "GET", path = "/api/users"})
api_logger.debug("Processing request", {request_id = "req-123"})
api_logger.info("Request completed", {status = 200, duration_ms = 45})
api_logger.error("Request failed", {method = "POST", path = "/api/orders", error = "Database connection error"})

-- Database logs
db_logger.info("Database connection established", {host = "localhost", port = 5432})
db_logger.debug("Executing query", {query = "SELECT * FROM users"})
db_logger.debug("Query complete", {rows = 10, duration_ms = 5})
db_logger.warn("Slow query detected", {query = "SELECT * FROM orders", duration_ms = 1200})
db_logger.error("Query failed", {query = "INSERT INTO products", error = "Duplicate key violation"})

-- Flush logs to ensure they're written
logging.flush()

print("Sample logs generated in logs/search_example.log and logs/search_example.json")
print("")

-- Now demonstrate search capabilities
print("=== Searching Logs ===")

-- Search by level
print("\n1. Searching for ERROR level logs:")
local errors = log_search.search_logs({
  log_file = "logs/search_example.log",
  level = "ERROR"
})

if errors and errors.entries then
  for i, entry in ipairs(errors.entries) do
    print(string.format("  %d. [%s] %s: %s", 
      i, entry.timestamp, entry.module, entry.message))
  end
  print(string.format("  Found %d ERROR logs", errors.count))
else
  print("  No ERROR logs found or error occurred")
end

-- Search by module
print("\n2. Searching for logs from database module:")
local db_logs = log_search.search_logs({
  log_file = "logs/search_example.log",
  module = "database"
})

if db_logs and db_logs.entries then
  for i, entry in ipairs(db_logs.entries) do
    print(string.format("  %d. [%s] %s: %s", 
      i, entry.level, entry.timestamp, entry.message))
  end
  print(string.format("  Found %d database logs", db_logs.count))
else
  print("  No database logs found or error occurred")
end

-- Search by message content
print("\n3. Searching for logs containing 'query':")
local query_logs = log_search.search_logs({
  log_file = "logs/search_example.log",
  message_pattern = "query"
})

if query_logs and query_logs.entries then
  for i, entry in ipairs(query_logs.entries) do
    print(string.format("  %d. [%s] %s: %s", 
      i, entry.level, entry.module, entry.message))
  end
  print(string.format("  Found %d logs containing 'query'", query_logs.count))
else
  print("  No matching logs found or error occurred")
end

-- Get log statistics
print("\n=== Log Statistics ===")
local stats = log_search.get_log_stats("logs/search_example.log")

if stats then
  print(string.format("Total entries: %d", stats.total_entries))
  print("Entries by level:")
  for level, count in pairs(stats.by_level) do
    print(string.format("  %s: %d", level, count))
  end
  
  print("Entries by module:")
  for module, count in pairs(stats.by_module) do
    print(string.format("  %s: %d", module, count))
  end
  
  print(string.format("Errors: %d", stats.errors))
  print(string.format("Warnings: %d", stats.warnings))
  print(string.format("Time range: %s to %s", 
    stats.first_timestamp or "unknown", stats.last_timestamp or "unknown"))
  print(string.format("File size: %d bytes", stats.file_size or 0))
else
  print("Failed to get log statistics")
end

-- Export logs to different formats
print("\n=== Exporting Logs ===")

-- Export to CSV
local csv_result = log_search.export_logs(
  "logs/search_example.log", 
  "logs/search_example.csv", 
  "csv"
)

if csv_result then
  print(string.format("Exported %d entries to CSV: logs/search_example.csv", 
    csv_result.entries_processed))
else
  print("Failed to export logs to CSV")
end

-- Export to HTML
local html_result = log_search.export_logs(
  "logs/search_example.log", 
  "logs/search_example.html", 
  "html"
)

if html_result then
  print(string.format("Exported %d entries to HTML: logs/search_example.html", 
    html_result.entries_processed))
else
  print("Failed to export logs to HTML")
end

print("")
print("This example has demonstrated:")
print("1. Searching logs by level, module, and content")
print("2. Getting log statistics (counts, distribution, etc.)")
print("3. Exporting logs to different formats (CSV, HTML)")
print("")
print("The generated files are in the logs/ directory:")
print("- search_example.log - Original text logs")
print("- search_example.json - Original JSON logs")
print("- search_example.csv - Exported CSV format")
print("- search_example.html - Exported HTML format with styling")