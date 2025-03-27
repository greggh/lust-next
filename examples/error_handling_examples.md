# Error Handling Examples

This file provides practical examples of the firmo error handling system. Each example demonstrates a specific pattern or scenario with complete, ready-to-use code.

## Basic Error Handling Patterns

### Example 1: Input Validation

This example demonstrates proper input validation with structured error objects:

```lua
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")

-- Function with proper input validation
function calculate_square_root(value)
  -- Validate parameter existence
  if value == nil then
    return nil, error_handler.validation_error(
      "Value is required",
      {parameter = "value", operation = "calculate_square_root"}
    )
  end
  
  -- Validate parameter type
  if type(value) ~= "number" then
    return nil, error_handler.validation_error(
      "Value must be a number",
      {parameter = "value", provided_type = type(value), operation = "calculate_square_root"}
    )
  end
  
  -- Validate parameter value
  if value < 0 then
    return nil, error_handler.validation_error(
      "Cannot calculate square root of negative number",
      {parameter = "value", provided_value = value, operation = "calculate_square_root"}
    )
  end
  
  -- Perform the calculation
  return math.sqrt(value)
end

-- Using the function with error handling
local result, err = calculate_square_root(-5)
if not result then
  print("Error: " .. err.message)
  print("Category: " .. err.category)
  print("Context: " .. tostring(err.context.parameter) .. " = " .. tostring(err.context.provided_value))
else
  print("Result: " .. result)
end
```

### Example 2: Try-Catch Pattern for Risky Operations

This example shows how to wrap potentially error-throwing code in a safe try-catch pattern:

```lua
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")

-- A function that might throw an error
local function parse_json(json_string)
  if not json_string or json_string == "" then
    error("JSON string cannot be empty")
  end
  
  -- In a real case, this would use a proper JSON parser
  if json_string:match("^%s*{") then
    return {parsed = true, content = json_string}
  else
    error("Invalid JSON format")
  end
end

-- Safely call the function with try-catch pattern
function safe_parse_json(json_string)
  local success, result, additional = error_handler.try(function()
    return parse_json(json_string)
  end)
  
  if not success then
    -- When try fails, the error is in the result parameter
    print("Failed to parse JSON: " .. error_handler.format_error(result))
    return nil, result
  end
  
  -- When successful, the actual return value is in result
  return result, additional
end

-- Test with valid input
local valid_result = safe_parse_json('{ "key": "value" }')
print("Valid parse result:", valid_result and "Success" or "Failed")

-- Test with invalid input
local invalid_result, err = safe_parse_json("")
print("Invalid parse result:", invalid_result and "Success" or "Failed")
print("Error category:", err and err.category)
```

### Example 3: Safe I/O Operations

This example demonstrates proper file operations with error handling:

```lua
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

-- Function to safely read a configuration file
function read_config_file(file_path)
  -- Validate parameter
  if not file_path or type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "File path must be a string",
      {parameter = "file_path", provided_type = type(file_path), operation = "read_config_file"}
    )
  end
  
  -- Check if file exists
  local file_exists, exists_err = error_handler.safe_io_operation(
    function() return fs.file_exists(file_path) end,
    file_path,
    {operation = "check_file_exists"}
  )
  
  if exists_err then
    return nil, exists_err
  end
  
  if not file_exists then
    return nil, error_handler.io_error(
      "Configuration file does not exist: " .. file_path,
      {file_path = file_path, operation = "read_config_file"}
    )
  end
  
  -- Read file content
  local content, read_err = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    {operation = "read_config_file"}
  )
  
  if not content then
    return nil, read_err
  end
  
  -- In a real application, you might parse the content here
  return {
    content = content,
    file_path = file_path,
    timestamp = os.time()
  }
end

-- Usage example
local config, err = read_config_file("/path/to/config.lua")
if not config then
  print("Failed to read config: " .. error_handler.format_error(err))
else
  print("Config loaded successfully")
  print("Content length: " .. #config.content)
end
```

### Example 4: Resource Management with Error Handling

This example shows how to safely manage resources that need proper cleanup:

```lua
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local temp_file = require("lib.tools.temp_file")

-- Function to process data with proper resource management
function process_data_with_temp_files(data)
  -- Track created resources for cleanup
  local resources = {}
  
  -- Create temporary file for input
  local input_file, create_err = error_handler.try(function()
    local file_path = temp_file.create_with_content(data, "dat")
    table.insert(resources, file_path) -- Track for cleanup
    return file_path
  end)
  
  if not input_file then
    -- No cleanup needed yet
    return nil, create_err
  end
  
  -- Create temporary file for output
  local output_file, output_err = error_handler.try(function()
    local file_path = temp_file.create_with_content("", "out")
    table.insert(resources, file_path) -- Track for cleanup
    return file_path
  end)
  
  if not output_file then
    -- Clean up first resource before returning
    cleanup_resources(resources)
    return nil, output_err
  end
  
  -- Process the data (simulated)
  local success, result, process_err = error_handler.try(function()
    -- In a real application, this would actually process the data
    local processed_data = "Processed: " .. data
    
    -- Write to output file
    local write_success = fs.write_file(output_file, processed_data)
    if not write_success then
      error("Failed to write processed data to output file")
    end
    
    return {
      input_file = input_file,
      output_file = output_file,
      processed_data = processed_data
    }
  end)
  
  -- Always clean up resources, even if processing failed
  local cleanup_err = cleanup_resources(resources)
  
  -- If there was a processing error, return that
  if not success then
    return nil, process_err
  end
  
  -- If there was a cleanup error but processing succeeded, log it but return the result
  if cleanup_err then
    -- In a real application, you would log this
    print("Warning: " .. error_handler.format_error(cleanup_err))
  end
  
  return result
end

-- Helper function to clean up resources
function cleanup_resources(resources)
  local error_occurred = false
  local last_error = nil
  
  for _, resource in ipairs(resources) do
    local success, err = error_handler.try(function()
      temp_file.remove(resource)
    end)
    
    if not success then
      error_occurred = true
      last_error = err
    end
  end
  
  if error_occurred then
    return error_handler.io_error(
      "Failed to clean up all resources",
      {resource_count = #resources},
      last_error -- Original error as cause
    )
  end
  
  return nil -- No error
end

-- Usage example
local result, err = process_data_with_temp_files("Sample data to process")
if not result then
  print("Processing failed: " .. error_handler.format_error(err))
else
  print("Processing succeeded")
  print("Processed data: " .. result.processed_data)
end
```

## Testing Error Conditions

### Example 5: Testing Expected Errors

This example demonstrates proper testing of error conditions:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Function under test
function divide(a, b)
  if type(a) ~= "number" or type(b) ~= "number" then
    return nil, error_handler.validation_error(
      "Both arguments must be numbers",
      {a_type = type(a), b_type = type(b)}
    )
  end
  
  if b == 0 then
    return nil, error_handler.validation_error(
      "Division by zero",
      {a = a, b = b}
    )
  end
  
  return a / b
end

-- Test suite
describe("Division function", function()
  -- Test success case
  it("should divide two numbers", function()
    local result, err = divide(10, 2)
    expect(err).to_not.exist()
    expect(result).to.equal(5)
  end)
  
  -- Test error cases with expect_error flag
  it("should reject non-number arguments", { expect_error = true }, function()
    local result, err = divide("10", 2)
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.message).to.match("must be numbers")
    expect(err.context.a_type).to.equal("string")
  end)
  
  it("should reject division by zero", { expect_error = true }, function()
    local result, err = divide(10, 0)
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.message).to.equal("Division by zero")
    expect(err.context.a).to.equal(10)
    expect(err.context.b).to.equal(0)
  end)
  
  -- Test a function that throws errors directly
  it("should handle thrown errors", { expect_error = true }, function()
    local function throws_error()
      error("This is a thrown error")
    end
    
    local result, err = test_helper.with_error_capture(function()
      return throws_error()
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("This is a thrown error")
  end)
  
  -- Using expect_error helper
  it("should verify error message", { expect_error = true }, function()
    local function throws_specific_error()
      error("Specific error message")
    end
    
    local err = test_helper.expect_error(
      throws_specific_error, 
      "Specific error message"
    )
    
    expect(err).to.exist()
    expect(err.message).to.match("Specific error message")
  end)
end)
```

### Example 6: Testing Multiple Error Patterns

This example shows how to test functions with different error return patterns:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Function that returns nil + error
function validate_email(email)
  if not email or type(email) ~= "string" then
    return nil, error_handler.validation_error(
      "Email must be a string",
      {parameter = "email", provided_type = type(email)}
    )
  end
  
  if not email:match("^.+@.+%.%w+$") then
    return nil, error_handler.validation_error(
      "Invalid email format",
      {parameter = "email", provided_value = email}
    )
  end
  
  return email
end

-- Function that returns false for failure
function is_valid_username(username)
  if not username or type(username) ~= "string" then
    return false
  end
  
  if #username < 3 or #username > 20 then
    return false
  end
  
  if not username:match("^[a-zA-Z0-9_]+$") then
    return false
  end
  
  return true
end

-- Function that throws an error
function parse_date(date_string)
  if not date_string or type(date_string) ~= "string" then
    error("Date must be a string")
  end
  
  local year, month, day = date_string:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if not year then
    error("Invalid date format, expected YYYY-MM-DD")
  end
  
  return {year = tonumber(year), month = tonumber(month), day = tonumber(day)}
end

-- Test suite
describe("Error pattern tests", function()
  -- Test nil+error pattern
  describe("Email validation", function()
    it("should accept valid email", function()
      local result, err = validate_email("user@example.com")
      expect(err).to_not.exist()
      expect(result).to.equal("user@example.com")
    end)
    
    it("should reject nil email", { expect_error = true }, function()
      local result, err = validate_email(nil)
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("must be a string")
    end)
    
    it("should reject invalid format", { expect_error = true }, function()
      local result, err = validate_email("invalid-email")
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("Invalid email format")
    end)
  end)
  
  -- Test false return pattern
  describe("Username validation", function()
    it("should accept valid username", function()
      local result = is_valid_username("john_doe123")
      expect(result).to.be_truthy()
    end)
    
    it("should reject nil username", { expect_error = true }, function()
      local result = is_valid_username(nil)
      expect(result).to.equal(false)
    end)
    
    it("should reject short username", { expect_error = true }, function()
      local result = is_valid_username("ab")
      expect(result).to.equal(false)
    end)
    
    it("should reject invalid characters", { expect_error = true }, function()
      local result = is_valid_username("user@name")
      expect(result).to.equal(false)
    end)
  end)
  
  -- Test thrown error pattern
  describe("Date parsing", function()
    it("should parse valid date", function()
      local result = parse_date("2023-01-15")
      expect(result).to.exist()
      expect(result.year).to.equal(2023)
      expect(result.month).to.equal(1)
      expect(result.day).to.equal(15)
    end)
    
    it("should reject nil date", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        parse_date(nil)
      end, "Date must be a string")
      
      expect(err).to.exist()
    end)
    
    it("should reject invalid format", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        parse_date("2023/01/15")
      end, "Invalid date format")
      
      expect(err).to.exist()
    end)
  end)
  
  -- Test handling both patterns with a single function
  describe("Universal error test pattern", function()
    it("should handle different error types", { expect_error = true }, function()
      -- Function to test different error return patterns
      local function test_error_pattern(error_type, input)
        if error_type == "nil_error" then
          return validate_email(input)
        elseif error_type == "false" then
          return is_valid_username(input)
        else
          local result, err = test_helper.with_error_capture(function()
            return parse_date(input)
          end)()
          return result, err
        end
      end
      
      -- Test nil+error pattern
      local email_result, email_err = test_error_pattern("nil_error", "invalid")
      expect(email_result).to_not.exist()
      expect(email_err).to.exist()
      expect(email_err.message).to.match("Invalid email format")
      
      -- Test false pattern
      local username_result = test_error_pattern("false", "a")
      expect(username_result).to.equal(false)
      
      -- Test thrown error pattern
      local date_result, date_err = test_error_pattern("thrown", "invalid")
      expect(date_result).to_not.exist()
      expect(date_err).to.exist()
      expect(date_err.message).to.match("Invalid date format")
    end)
  end)
end)
```

## Advanced Error Handling Patterns

### Example 7: Error Propagation Chain

This example demonstrates proper error propagation through a chain of function calls:

```lua
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")

-- Low-level function that may fail
function read_data_from_source(source_id)
  if not source_id then
    return nil, error_handler.validation_error(
      "Source ID is required",
      {parameter = "source_id", operation = "read_data_from_source"}
    )
  end
  
  -- Simulate a source that doesn't exist
  if source_id == "missing" then
    return nil, error_handler.io_error(
      "Source not found",
      {source_id = source_id, operation = "read_data_from_source"}
    )
  end
  
  -- Simulate successful data reading
  return {id = source_id, data = "Sample data for " .. source_id}
end

-- Mid-level function that calls the low-level function
function process_source_data(source_id, options)
  -- Validate inputs
  if not options or type(options) ~= "table" then
    return nil, error_handler.validation_error(
      "Options must be a table",
      {parameter = "options", provided_type = type(options), operation = "process_source_data"}
    )
  end
  
  -- Call lower-level function
  local source_data, read_err = read_data_from_source(source_id)
  if not source_data then
    -- Propagate error with additional context
    return nil, error_handler.create(
      "Failed to process source data: " .. read_err.message,
      read_err.category,
      read_err.severity,
      {
        source_id = source_id,
        options = options,
        operation = "process_source_data",
        -- Include original error context
        original_context = read_err.context
      },
      read_err -- Set original error as cause
    )
  end
  
  -- Process the data (simulated)
  local processed_data = {
    source_id = source_data.id,
    processed = true,
    result = "Processed: " .. source_data.data,
    timestamp = os.time(),
    options_used = options
  }
  
  return processed_data
end

-- High-level function that calls the mid-level function
function generate_report(sources, report_type)
  -- Validate inputs
  if not sources or type(sources) ~= "table" or #sources == 0 then
    return nil, error_handler.validation_error(
      "Sources must be a non-empty array",
      {parameter = "sources", provided_type = type(sources), operation = "generate_report"}
    )
  end
  
  if not report_type or type(report_type) ~= "string" then
    return nil, error_handler.validation_error(
      "Report type must be a string",
      {parameter = "report_type", provided_type = type(report_type), operation = "generate_report"}
    )
  end
  
  -- Processing options based on report type
  local options = {
    format = report_type,
    include_metadata = true,
    timestamp = os.time()
  }
  
  -- Process each source
  local results = {}
  local errors = {}
  
  for i, source_id in ipairs(sources) do
    local processed_data, process_err = process_source_data(source_id, options)
    
    if not processed_data then
      -- Store error but continue processing other sources
      table.insert(errors, {
        source_id = source_id,
        error = process_err,
        index = i
      })
    else
      table.insert(results, processed_data)
    end
  end
  
  -- Generate report summary
  local report = {
    report_type = report_type,
    timestamp = os.time(),
    total_sources = #sources,
    successful = #results,
    failed = #errors,
    results = results
  }
  
  -- If all sources failed, return an error
  if #results == 0 and #errors > 0 then
    return nil, error_handler.runtime_error(
      "Failed to generate report: all sources failed",
      {
        report_type = report_type,
        sources = sources,
        errors = errors,
        operation = "generate_report"
      }
    )
  end
  
  -- If some sources failed, include errors in the report
  if #errors > 0 then
    report.errors = errors
    report.partial = true
  end
  
  return report
end

-- Usage example
local sources = {"source1", "source2", "missing", "source4"}
local report, err = generate_report(sources, "summary")

if not report then
  print("Failed to generate report: " .. error_handler.format_error(err))
else
  print("Report generated:")
  print("Type: " .. report.report_type)
  print("Total sources: " .. report.total_sources)
  print("Successful: " .. report.successful)
  print("Failed: " .. report.failed)
  
  if report.partial then
    print("\nWarning: Some sources failed:")
    for _, error_info in ipairs(report.errors) do
      print("  Source " .. error_info.source_id .. ": " .. 
            error_handler.format_error(error_info.error))
    end
  end
end
```

### Example 8: Error Handler Integration with Logging

This example shows proper integration between error handling and logging:

```lua
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

-- Initialize logger with error handling
local logger
local logger_init_success, logger_init_error = pcall(function()
  logger = logging.get_logger("error_example")
  return true
end)

if not logger_init_success then
  print("Warning: Failed to initialize logger: " .. tostring(logger_init_error))
  -- Create a minimal logger as fallback
  logger = {
    debug = function() end,
    info = function() end,
    warn = function(msg) print("WARN: " .. msg) end,
    error = function(msg) print("ERROR: " .. msg) end
  }
end

-- Function with integrated logging and error handling
function process_config(config_path, options)
  logger.debug("Processing config", {
    config_path = config_path,
    options = options
  })
  
  -- Validate parameters
  if not config_path then
    local err = error_handler.validation_error(
      "Config path is required",
      {parameter = "config_path", operation = "process_config"}
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Validate options if provided
  if options ~= nil and type(options) ~= "table" then
    local err = error_handler.validation_error(
      "Options must be a table if provided",
      {parameter = "options", provided_type = type(options), operation = "process_config"}
    )
    logger.error(err.message, err.context)
    return nil, err
  end
  
  -- Initialize with default options
  options = options or {}
  
  -- Attempt to read the config file
  logger.debug("Reading config file", {file_path = config_path})
  local fs = require("lib.tools.filesystem")
  local content, read_err = error_handler.safe_io_operation(
    function() return fs.read_file(config_path) end,
    config_path,
    {operation = "read_config"}
  )
  
  if not content then
    logger.error("Failed to read config file", {
      file_path = config_path,
      error = error_handler.format_error(read_err)
    })
    return nil, read_err
  end
  
  -- Attempt to parse the config
  logger.debug("Parsing config content", {content_length = #content})
  local config, parse_err = error_handler.try(function()
    -- In a real application, this would parse the config format
    -- For this example, we'll simulate a successful parse
    return {
      settings = {
        debug = options.debug or false,
        timeout = options.timeout or 30,
        max_retries = options.max_retries or 3
      },
      source_file = config_path,
      last_modified = os.time()
    }
  end)
  
  if not config then
    logger.error("Failed to parse config", {
      file_path = config_path,
      error = error_handler.format_error(parse_err)
    })
    return nil, parse_err
  end
  
  -- Apply any custom processing
  if options.transform then
    logger.debug("Applying custom transformation")
    local transformed, transform_err = error_handler.try(function()
      return options.transform(config)
    end)
    
    if not transformed then
      logger.error("Failed to transform config", {
        file_path = config_path,
        error = error_handler.format_error(transform_err)
      })
      return nil, transform_err
    end
    
    config = transformed
  end
  
  logger.info("Successfully processed config", {
    file_path = config_path,
    settings_count = #config.settings
  })
  
  return config
end

-- Usage example
local custom_transform = function(config)
  config.settings.custom_field = "Added by transform"
  return config
end

local config, err = process_config("/path/to/config.json", {
  debug = true,
  transform = custom_transform
})

if not config then
  logger.error("Config processing failed", {
    error = error_handler.format_error(err)
  })
else
  logger.info("Config ready to use", {
    debug_mode = config.settings.debug,
    custom_field = config.settings.custom_field
  })
end
```

### Example 9: Test Helper with Error Capture

This example demonstrates using the test helper module for error testing:

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Functions to test
function validates_input(input)
  if not input then
    return nil, error_handler.validation_error(
      "Input is required",
      {parameter = "input", operation = "validates_input"}
    )
  end
  return true
end

function throws_directly()
  error("This is a direct error")
end

function is_valid_format(input)
  if type(input) ~= "string" then
    return false
  end
  return true
end

-- Test suite
describe("Error Testing Patterns", function()
  -- Testing nil+error return pattern
  describe("with_error_capture for nil+error pattern", function()
    it("should handle success case", function()
      local result, err = test_helper.with_error_capture(function()
        return validates_input("valid")
      end)()
      
      expect(err).to_not.exist()
      expect(result).to.equal(true)
    end)
    
    it("should handle error case", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return validates_input(nil)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    end)
  end)
  
  -- Testing functions that throw errors
  describe("with_error_capture for throws pattern", function()
    it("should catch thrown errors", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return throws_directly()
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("This is a direct error")
    end)
  end)
  
  -- Testing functions that return false
  describe("testing false return value", function()
    it("should handle false return", { expect_error = true }, function()
      local result = is_valid_format(123)
      expect(result).to.equal(false)
    end)
  end)
  
  -- Using expect_error helper
  describe("expect_error helper", function()
    it("should verify error message", { expect_error = true }, function()
      local err = test_helper.expect_error(function()
        throws_directly()
      end, "This is a direct error")
      
      expect(err).to.exist()
      expect(err.message).to.match("This is a direct error")
    end)
    
    it("should fail if no error thrown", { expect_error = true }, function()
      local success, err = pcall(function()
        test_helper.expect_error(function()
          return "No error here"
        end, "Expected an error")
      end)
      
      expect(success).to.equal(false)
      expect(tostring(err)).to.match("Expected function to fail")
    end)
    
    it("should fail if wrong error message", { expect_error = true }, function()
      local success, err = pcall(function()
        test_helper.expect_error(function()
          error("Wrong error message")
        end, "Expected different message")
      end)
      
      expect(success).to.equal(false)
      expect(tostring(err)).to.match("Expected error message to match")
    end)
  end)
  
  -- Using error suppression system
  describe("error suppression", function()
    it("should suppress expected errors", { expect_error = true }, function()
      -- This error will be suppressed in normal output
      local result, err = validates_input(nil)
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      
      -- Log something to verify suppression
      local logger = require("lib.tools.logging").get_logger("test")
      logger.error("This error log should be suppressed")
    end)
  end)
end)
```

## Run these examples

To run these examples, use the firmo test runner:

```bash
# Example 5: Testing Expected Errors
lua test.lua examples/error_handling_example.lua

# Example 6: Testing Multiple Error Patterns
lua test.lua examples/error_patterns_example.lua

# Example 9: Test Helper with Error Capture
lua test.lua examples/test_helper_example.lua
```

For the non-test examples (1-4, 7-8), create Lua files with the provided code and run them directly:

```bash
lua examples/input_validation_example.lua
lua examples/try_catch_example.lua
lua examples/safe_io_example.lua
lua examples/resource_management_example.lua
lua examples/error_propagation_example.lua
lua examples/logging_integration_example.lua
```

These examples provide a comprehensive reference for implementing proper error handling throughout your Lua codebase using the firmo framework.