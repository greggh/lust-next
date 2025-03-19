-- Error handling module for firmo
-- Provides standardized error handling, validation, and error reporting functions
local M = {}

-- Simple forward declarations for functions used before they're defined
local create_error -- Forward declaration for create_error function

-- Lazy-load dependencies to avoid circular dependencies
local _logging, _fs
local function get_logging()
  if not _logging then
    local success, logging = pcall(require, "lib.tools.logging")
    _logging = success and logging or nil
  end
  return _logging
end

---@diagnostic disable-next-line: unused-local, unused-function
local function get_fs()
  if not _fs then
    local success, fs = pcall(require, "lib.tools.filesystem")
    _fs = success and fs or nil
  end
  return _fs
end

-- Get a logger instance for this module
local function get_logger()
  local logging = get_logging()
  if logging then
    return logging.get_logger("ErrorHandler")
  end
  -- Return a stub logger if logging module isn't available
  return {
    error = function(msg)
      print("[ERROR] " .. msg)
    end,
    warn = function(msg)
      print("[WARN] " .. msg)
    end,
    info = function(msg)
      print("[INFO] " .. msg)
    end,
    debug = function(msg)
      print("[DEBUG] " .. msg)
    end,
    trace = function(msg)
      print("[TRACE] " .. msg)
    end,
  }
end

local logger = get_logger()

-- Module configuration
local config = {
  use_assertions = true, -- Use Lua assertions for validation errors
  verbose = false, -- Verbose error messages
  trace_errors = true, -- Include traceback information
  log_all_errors = true, -- Log all errors through the logging system
  exit_on_fatal = false, -- Exit the process on fatal errors
  capture_backtraces = true, -- Capture stack traces for errors
  in_test_run = false, -- Are we currently running tests? (Set by test runner)
  suppress_test_assertions = true, -- Whether to suppress expected validation errors in tests
  suppress_all_logging_in_tests = true, -- Whether to suppress ALL console output during tests
  current_test_metadata = nil, -- Metadata for the currently running test (if any)
}

-- IMPORTANT: We DO NOT detect test mode automatically by pattern matching filenames.
-- Instead, the test runner explicitly sets test mode via M.set_test_mode()
-- This ensures reliability across different environments and file structures.
-- See scripts/runner.lua for the proper implementation.

-- Do NOT set test run mode here - it will be set explicitly by the test runner

-- Error severity levels
M.SEVERITY = {
  FATAL = "FATAL", -- Unrecoverable errors that require process termination
  ERROR = "ERROR", -- Serious errors that might allow the process to continue
  WARNING = "WARNING", -- Warnings that need attention but don't stop execution
  INFO = "INFO", -- Informational messages about error conditions
}

-- Error categories
M.CATEGORY = {
  VALIDATION = "VALIDATION", -- Input validation errors
  IO = "IO", -- File I/O errors
  PARSE = "PARSE", -- Parsing errors
  RUNTIME = "RUNTIME", -- Runtime errors
  TIMEOUT = "TIMEOUT", -- Timeout errors
  MEMORY = "MEMORY", -- Memory-related errors
  CONFIGURATION = "CONFIG", -- Configuration errors
  UNKNOWN = "UNKNOWN", -- Unknown errors
  TEST_EXPECTED = "TEST_EXPECTED", -- Errors that are expected during tests
}

-- Internal helper to get a traceback
local function get_traceback(level)
  if not config.capture_backtraces then
    return nil
  end
  level = level or 3 -- Skip this function and the caller
  return debug.traceback("", level)
end

-- Internal helper to create an error object
create_error = function(message, category, severity, context, cause)
  local err = {
    message = message or "Unknown error",
    category = category or M.CATEGORY.UNKNOWN,
    severity = severity or M.SEVERITY.ERROR,
    timestamp = os.time(),
    traceback = get_traceback(),
    context = context or {},
    cause = cause, -- Original error that caused this one
  }

  -- Add file and line information if available
  local info = debug.getinfo(3, "Sl")
  if info then
    err.source_file = info.short_src
    err.source_line = info.currentline
  end

  return err
end

-- Format an error object as a string
local function format_error(err)
  if type(err) == "string" then
    return err
  end

  if type(err) ~= "table" then
    return tostring(err)
  end

  if not err.category and not err.message then
    return tostring(err)
  end

  local parts = {}
  table.insert(parts, "[" .. (err.severity or "ERROR") .. "]")

  if err.category then
    table.insert(parts, err.category .. ":")
  end

  table.insert(parts, err.message or "Unknown error")

  if err.source_file and err.source_line then
    table.insert(parts, "(at " .. err.source_file .. ":" .. err.source_line .. ")")
  end

  local verbose = true -- Always be verbose for error handling
  if verbose and err.context and next(err.context) then
    table.insert(parts, "\nContext: ")
    for k, v in pairs(err.context) do
      table.insert(parts, " " .. k .. ": " .. tostring(v))
    end
  end

  return table.concat(parts, " ")
end

-- Add function to module
M.format_error = format_error

-- Rethrow an error
function M.rethrow(err)
  if type(err) == "table" and err.message then
    error(err.message, 2)
  else
    error(tostring(err), 2)
  end
end

-- REMOVED: Assert functions were moved to firmo.assert

-- Internal helper to log an error
local function log_error(err)
  -- Skip all error logging if config says not to log errors
  if not config.log_all_errors then
    return
  end

  -- IMMEDIATELY RETURN if we're in test mode and suppressing all logging
  if config.in_test_run and config.suppress_all_logging_in_tests then
    -- Store the error in a global table for potential debugging if needed
    _G._firmo_test_errors = _G._firmo_test_errors or {}
    table.insert(_G._firmo_test_errors, err)
    return
  end

  local logging = get_logging()
  if not logging then
    -- Fallback to print if logging isn't available
    print(string.format("[%s] %s: %s", err.severity, err.category, err.message))
    return
  end

  -- Convert to structured log
  local log_params = {
    category = err.category,
    context = err.context,
    source_file = err.source_file,
    source_line = err.source_line,
  }

  -- Add traceback in verbose mode
  if config.verbose and err.traceback then
    log_params.traceback = err.traceback
  end

  -- Add cause if available
  if err.cause then
    if type(err.cause) == "table" and err.cause.message then
      log_params.cause = err.cause.message
    else
      log_params.cause = tostring(err.cause)
    end
  end

  -- Check if we should suppress logging in test environment
  local log_level = "error"
  local suppress_logging = false
  local completely_skip_logging = false
  
  -- In test mode, we may suppress certain categories of errors
  -- This is the proper approach instead of unreliable pattern matching
  if config.in_test_run then
    -- Check if this is a test that expects errors
    if config.current_test_metadata and config.current_test_metadata.expect_error then
      -- If the current test explicitly expects errors, completely skip logging
      completely_skip_logging = true
    elseif config.suppress_test_assertions then
      -- Otherwise, only suppress logging for validation and test_expected errors
      if err.category == M.CATEGORY.VALIDATION or err.category == M.CATEGORY.TEST_EXPECTED then
        suppress_logging = true
      end
    end
  end
  
  -- When in a test with expect_error flag, handle errors specially
  if completely_skip_logging then
    -- Store the error in a global table for potential debugging if needed
    _G._firmo_test_errors = _G._firmo_test_errors or {}
    table.insert(_G._firmo_test_errors, err)
    
    -- Don't skip all logging - only downgrade ERROR and WARNING logs to DEBUG
    -- This allows explicit debug logging to still work
    if err.severity == M.SEVERITY.ERROR or err.severity == M.SEVERITY.WARNING then
      log_level = "debug"
    end
    
    -- Additionally check if debug logs are explicitly enabled
    local debug_enabled = logger.is_debug_enabled and logger.is_debug_enabled()
    if not debug_enabled then
      -- If debug logs aren't enabled, skip logging entirely
      return
    end
    -- Otherwise, continue with debug-level logging
  end
  
  -- Choose appropriate log level
  if err.severity == M.SEVERITY.FATAL then
    log_level = "error" -- Fatal errors are always logged at error level
  elseif err.severity == M.SEVERITY.ERROR then
    log_level = suppress_logging and "debug" or "error"
  elseif err.severity == M.SEVERITY.WARNING then
    log_level = suppress_logging and "debug" or "warn"
  else
    log_level = suppress_logging and "debug" or "info"
  end
  
  -- Log at the appropriate level
  if err.severity == M.SEVERITY.FATAL then
    logger.error("FATAL: " .. err.message, log_params)
  elseif log_level == "error" then
    logger.error(err.message, log_params)
  elseif log_level == "warn" then
    logger.warn(err.message, log_params)
  elseif log_level == "info" then
    logger.info(err.message, log_params)
  else -- debug
    logger.debug(err.message, log_params)
  end

  -- Handle fatal errors
  if err.severity == M.SEVERITY.FATAL and config.exit_on_fatal then
    os.exit(1)
  end
end

-- Internal helper to handle an error
---@diagnostic disable-next-line: unused-local, unused-function
local function handle_error(err)
  -- Log the error
  log_error(err)

  -- Return the error as an object
  return nil, err
end

-- Initialize the error handler with configuration
function M.configure(options)
  if options then
    for k, v in pairs(options) do
      config[k] = v
    end
  end

  -- Configure from central_config if available
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    -- Register our module with default configuration
    central_config.register_module("error_handler", {
      -- Schema definition
      field_types = {
        use_assertions = "boolean",
        verbose = "boolean",
        trace_errors = "boolean",
        log_all_errors = "boolean",
        exit_on_fatal = "boolean",
        capture_backtraces = "boolean",
        in_test_run = "boolean",
        suppress_test_assertions = "boolean",
      }
    }, {
      -- Default values (matching our local config)
      use_assertions = config.use_assertions,
      verbose = config.verbose,
      trace_errors = config.trace_errors,
      log_all_errors = config.log_all_errors,
      exit_on_fatal = config.exit_on_fatal,
      capture_backtraces = config.capture_backtraces,
      in_test_run = config.in_test_run,
      suppress_test_assertions = config.suppress_test_assertions,
    })
    
    -- Now get configuration (will include our defaults if not yet set)
    local error_handler_config = central_config.get("error_handler")
    if error_handler_config then
      for k, v in pairs(error_handler_config) do
        config[k] = v
      end
    end
  end

  return M
end

-- Public API: Create an error
function M.create(message, category, severity, context, cause)
  return create_error(message, category, severity, context, cause)
end

-- Public API: Throw an error (with proper logging)
function M.throw(message, category, severity, context, cause)
  local err = create_error(message, category, severity, context, cause)
  log_error(err)
  error(err.message, 2) -- Level 2 to point to the caller
end

-- Public API: Assert a condition or throw an error
function M.assert(condition, message, category, context, cause)
  if not condition then
    local severity = M.SEVERITY.ERROR
    local err = create_error(message, category, severity, context, cause)
    log_error(err)

    if config.use_assertions then
      assert(false, err.message)
    else
      error(err.message, 2) -- Level 2 to point to the caller
    end
  end
  return condition
end

-- REMOVED: Assert functions were moved to firmo.assert

-- Compatibility function for table unpacking (works with both Lua 5.1 and 5.2+)
local unpack_table = table.unpack or unpack

-- Public API: Safely call a function and catch any errors
function M.try(func, ...)
  local result = { pcall(func, ...) }
  local success = table.remove(result, 1)

  if success then
    return true, unpack_table(result)
  else
    local err_message = result[1]

    -- Check if the error is already one of our error objects
    if type(err_message) == "table" and err_message.category then
      log_error(err_message)
      return false, err_message
    end

    -- Create an error object
    local err = create_error(tostring(err_message), M.CATEGORY.RUNTIME, M.SEVERITY.ERROR, { args = { ... } })

    log_error(err)
    return false, err
  end
end

-- Public API: Create validation error
function M.validation_error(message, context)
  return create_error(message, M.CATEGORY.VALIDATION, M.SEVERITY.ERROR, context)
end

-- Public API: Create I/O error
function M.io_error(message, context, cause)
  return create_error(message, M.CATEGORY.IO, M.SEVERITY.ERROR, context, cause)
end

-- Public API: Create parse error
function M.parse_error(message, context, cause)
  return create_error(message, M.CATEGORY.PARSE, M.SEVERITY.ERROR, context, cause)
end

-- Public API: Create timeout error
function M.timeout_error(message, context)
  return create_error(message, M.CATEGORY.TIMEOUT, M.SEVERITY.ERROR, context)
end

-- Public API: Create a configuration error
function M.config_error(message, context)
  return create_error(message, M.CATEGORY.CONFIGURATION, M.SEVERITY.ERROR, context)
end

-- Public API: Create a runtime error
function M.runtime_error(message, context, cause)
  return create_error(message, M.CATEGORY.RUNTIME, M.SEVERITY.ERROR, context, cause)
end

-- Public API: Create a fatal error
function M.fatal_error(message, category, context, cause)
  return create_error(message, category or M.CATEGORY.UNKNOWN, M.SEVERITY.FATAL, context, cause)
end

-- Public API: Create a test expected error (for use in test stubs, mocks, etc.)
function M.test_expected_error(message, context, cause)
  return create_error(message, M.CATEGORY.TEST_EXPECTED, M.SEVERITY.ERROR, context, cause)
end

-- Public API: Safely execute an I/O operation with proper error handling
function M.safe_io_operation(operation, file_path, context, transform_result)
  transform_result = transform_result or function(result)
    return result
  end

  local result, err = operation()

  if result ~= nil or err == nil then
    -- Either operation succeeded (result is not nil) or
    -- operation returned nil, nil (no error, just negative result, e.g., file doesn't exist)
    return transform_result(result)
  end

  -- Add file path to context
  context = context or {}
  context.file_path = file_path

  -- Create an I/O error
  local error_obj = M.io_error((err or "I/O operation failed: ") .. tostring(file_path), context, err)

  -- Log and return
  log_error(error_obj)
  return nil, error_obj
end

-- Public API: Check if a value is an error object
function M.is_error(value)
  return type(value) == "table" and value.message ~= nil and value.category ~= nil and value.severity ~= nil
end

-- Add a metatable to error objects for better string conversion
local mt = {
  __tostring = function(err)
    if type(err) == "table" and err.message then
      return err.message
    else
      return tostring(err)
    end
  end
}

-- Update the create_error function to set metatable
local original_create_error = create_error
create_error = function(message, category, severity, context, cause)
  local err = original_create_error(message, category, severity, context, cause)
  return setmetatable(err, mt)
end

-- Public API: Format an error for display
function M.format_error(err, include_traceback)
  if not M.is_error(err) then
    if type(err) == "string" then
      return err
    else
      return tostring(err)
    end
  end

  local parts = {
    string.format("[%s] %s: %s", err.severity, err.category, err.message),
  }

  -- Add source location if available
  if err.source_file and err.source_line then
    table.insert(parts, string.format(" (at %s:%d)", err.source_file, err.source_line))
  end

  -- Add context if available and not empty
  if err.context and next(err.context) then
    table.insert(parts, "\nContext:")
    for k, v in pairs(err.context) do
      table.insert(parts, string.format("  %s: %s", k, tostring(v)))
    end
  end

  -- Add cause if available
  if err.cause then
    if type(err.cause) == "table" and err.cause.message then
      table.insert(parts, "\nCaused by: " .. err.cause.message)
    else
      table.insert(parts, "\nCaused by: " .. tostring(err.cause))
    end
  end

  -- Add traceback if requested and available
  if include_traceback and err.traceback then
    table.insert(parts, "\nTraceback:" .. err.traceback)
  end

  return table.concat(parts, "")
end

-- Public API: Configure from global config
function M.configure_from_config()
  -- Try to load central_config directly
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    -- Register our module with central_config if not already done
    central_config.register_module("error_handler", {
      -- Schema definition
      field_types = {
        use_assertions = "boolean",
        verbose = "boolean",
        trace_errors = "boolean",
        log_all_errors = "boolean",
        exit_on_fatal = "boolean",
        capture_backtraces = "boolean",
        in_test_run = "boolean",
        suppress_test_assertions = "boolean",
      }
    }, {
      -- Default values (matching our local config)
      use_assertions = config.use_assertions,
      verbose = config.verbose,
      trace_errors = config.trace_errors,
      log_all_errors = config.log_all_errors,
      exit_on_fatal = config.exit_on_fatal,
      capture_backtraces = config.capture_backtraces,
      in_test_run = config.in_test_run,
      suppress_test_assertions = config.suppress_test_assertions,
    })
    
    -- Get the centralized configuration
    local error_handler_config = central_config.get("error_handler")
    if error_handler_config then
      M.configure(error_handler_config)
    end
  end
  return M
end

-- Functions to control test mode
function M.set_test_mode(enabled)
  config.in_test_run = enabled and true or false
  
  -- Update central_config if available
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    central_config.set("error_handler.in_test_run", config.in_test_run)
    
    -- We'll handle logging suppression locally through our module
  end
  
  -- Don't try to configure logging directly - use its own methods
  -- This can cause circular dependencies and type issues
  
  return config.in_test_run
end

function M.is_test_mode()
  return config.in_test_run
end

-- Check if we're suppressing all logging in tests
function M.is_suppressing_test_logs()
  return config.in_test_run and config.suppress_all_logging_in_tests
end

-- Helper function to check if an error is an expected test error
function M.is_expected_test_error(err)
  if not M.is_error(err) then
    return false
  end
  
  -- Expected test errors are VALIDATION errors or explicitly marked TEST_EXPECTED errors
  local is_expected_category = err.category == M.CATEGORY.VALIDATION or 
                              err.category == M.CATEGORY.TEST_EXPECTED
  
  -- Check for test metadata with expect_error flag
  -- Tests with { expect_error = true } flag have ALL error logging completely suppressed
  -- This is different from tests that lack the flag, where only validation/test_expected errors are suppressed
  if config.current_test_metadata and config.current_test_metadata.expect_error then
    logger.debug("Expected test error detected via test metadata", {
      error_category = err.category,
      metadata_name = config.current_test_metadata.name,
      expect_error = true
    })
    return true
  end
  
  return is_expected_category
end

-- Function to set metadata for the current test
function M.set_current_test_metadata(metadata)
  -- Log the metadata change
  if metadata then
    logger.debug("Setting test metadata", {
      metadata_name = metadata.name,
      expect_error = metadata.expect_error or false,
    })
  else
    logger.debug("Clearing test metadata")
  end
  
  config.current_test_metadata = metadata
  
  -- Update central_config if available
  local ok, central_config = pcall(require, "lib.core.central_config")
  if ok and central_config then
    central_config.set("error_handler.current_test_metadata", config.current_test_metadata)
  end
  
  return config.current_test_metadata
end

-- Function to get current test metadata
function M.get_current_test_metadata()
  return config.current_test_metadata
end

-- Function to check if current test expects errors
function M.current_test_expects_errors()
  return config.current_test_metadata and config.current_test_metadata.expect_error == true
end

-- Retrieve expected errors captured during tests
function M.get_expected_test_errors()
  return _G._firmo_test_expected_errors or {}
end

-- Clear the collection of expected errors
function M.clear_expected_test_errors()
  _G._firmo_test_expected_errors = {}
  return true
end

-- Automatically configure from global config if available
M.configure_from_config()

return M
