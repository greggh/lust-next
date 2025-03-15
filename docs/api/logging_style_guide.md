# Logging Style Guide

This guide establishes standards for writing log messages in the firmo framework. Following these guidelines ensures that logs are consistent, readable, and useful for both human and machine consumption.

## Core Principles

1. **Clarity**: Log messages should be clear and unambiguous
2. **Consistency**: Follow consistent patterns across all modules
3. **Separation**: Separate message content from contextual data
4. **Structure**: Enable machine parsing without sacrificing human readability

## Message Content Guidelines

### Do

- Write concise, clear messages explaining what happened
- Use active voice: "Found 5 files" (not "5 files were found")
- Use consistent terminology across the codebase
- Write full sentences with proper capitalization
- Include the operation being performed

### Don't

- Include formatting characters (dashes, indentation, asterisks)
- Include variable data in the message text
- Use abbreviations unless well-established
- Include timestamps or module names (the logger adds these)
- Include line breaks or multi-line messages

## Parameter Usage

Always separate contextual values from message text by passing them as a separate table parameter:

```lua
-- Bad: Variable data embedded in message
logger.info("Processed file " .. filename .. " with " .. count .. " lines")

-- Good: Variable data as separate parameters
logger.info("Processed file", {filename = filename, line_count = count})
```

### Parameter Naming Conventions

- Use snake_case for parameter names
- Be specific (use `operation_duration_ms` not just `time`)
- Include units in names when applicable (`size_bytes`, `duration_ms`)
- Use consistent names for the same data across different messages
- Follow these common naming patterns:
  - IDs: `user_id`, `file_id`, `transaction_id`
  - Names: `filename`, `function_name`, `module_name`
  - Counts: `line_count`, `error_count`, `total_files`
  - Metrics: `duration_ms`, `size_bytes`, `memory_usage_mb`
  - Errors: `error`, `error_message`, `error_code`

## Severity Level Guidelines

Use the appropriate severity level for each message:

| Level | When to Use |
|-------|-------------|
| trace | Extremely detailed debugging information (function entry/exit, variables) |
| debug | Information helpful during development (parameter values, intermediate results) |
| info  | Normal operational events (startup, shutdown, configuration loaded) |
| warn  | Concerning situations that don't prevent operation (fallback used, retry) |
| error | Problems that prevented a specific operation from succeeding |
| fatal | Critical failures that might cause application termination |

## Message Templates

Use these templates for common scenarios:

### Operations

- Starting: "Starting [operation]"
- Completion: "Completed [operation]"
- Failure: "Failed to [operation]"

### Resources

- Creation: "Created [resource]"
- Update: "Updated [resource]"
- Deletion: "Deleted [resource]"
- Not Found: "Could not find [resource]"

### Examples

```lua
-- Operation start/end
logger.info("Starting test execution", {test_count = 42, tag = "integration"})
logger.info("Completed test execution", {passed = 40, failed = 2, duration_ms = 1500})

-- Resource operations
logger.debug("Created temporary file", {filename = "/tmp/test123.lua"})
logger.debug("Deleted temporary file", {filename = "/tmp/test123.lua"})

-- Warnings
logger.warn("Missing configuration value", {key = "timeout", using_default = true})
logger.warn("Retrying failed operation", {attempt = 3, max_attempts = 5})

-- Errors
logger.error("Failed to open file", {filename = "/missing/file.lua", error = err_msg})
logger.error("Database query failed", {query_id = "user_lookup", error_code = 1045})

-- Metrics
logger.info("Performance metrics", {
  operation = "parse_file",
  filename = "large_file.lua",
  duration_ms = 234,
  memory_used_kb = 1500
})
```

## Special Cases

### Exception Handling

When logging exceptions, include both the error message and error object:

```lua
local success, error = pcall(function() 
  -- operation
end)

if not success then
  logger.error("Failed to execute operation", {
    operation = "file_download", 
    error = tostring(error)
  })
end
```

### Complex Data Structures

For complex data that needs to be logged:

```lua
-- For debug/trace levels, it's ok to include detailed data
logger.debug("Request details", {headers = headers_table, body = body_data})

-- For info and above, only include summary data
logger.info("Processed request", {
  endpoint = "/api/users",
  method = "POST",
  status_code = 200,
  response_time_ms = 150
})
```

## Implementation Guidelines

### Shared Logging Strategies

Common logging patterns for different modules:

1. **Configuration Loading**:
   ```lua
   logger.debug("Loading configuration", {source = "file", path = config_path})
   logger.info("Configuration loaded", {item_count = #config_items})
   ```

2. **File Operations**:
   ```lua
   logger.debug("Reading file", {path = file_path})
   logger.debug("File read complete", {path = file_path, size_bytes = file_size})
   ```

3. **Test Execution**:
   ```lua
   logger.info("Running test", {name = test_name, tags = test_tags})
   logger.info("Test completed", {name = test_name, result = "passed", duration_ms = 120})
   ```

### Print Statement Migration

When converting print statements to logger calls:

1. Identify the appropriate severity level
2. Extract variable data into separate parameters
3. Use a clear, concise message
4. Remove any formatting characters

Before:
```lua
print("--- Processing file: " .. filename .. " ---")
print("Found " .. #lines .. " lines, processing took " .. time .. "ms")
```

After:
```lua
logger.info("Processing file", {filename = filename})
logger.info("File processing complete", {filename = filename, line_count = #lines, duration_ms = time})
```

## Integration with Structured Logging

For optimal integration with JSON-based structured logging:

1. Keep messages simple and descriptive
2. Put all variable data in parameters
3. Use consistent parameter names
4. Avoid nesting parameters too deeply

This ensures logs can be effectively parsed and analyzed by external tools.