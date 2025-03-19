-- Standardized Error Handling Example
--
-- This example demonstrates the standardized error handling patterns
-- implemented across the Firmo codebase.

-- Load firmo
package.path = "../?.lua;../lib/?.lua;../lib/?/init.lua;" .. package.path
local firmo = require("firmo")

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import necessary modules
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local temp_file = require("lib.tools.temp_file")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Initialize logger with error handling
local logger
local logger_init_success, logger_init_error = pcall(function()
  logger = logging.get_logger("standardized_error_example")
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

-- Example module with standardized error handling
local example_module = {}

-- Function that demonstrates proper input validation and error handling
function example_module.process_file(file_path, options)
  -- Validate parameters
  if not file_path or type(file_path) ~= "string" then
    return nil, error_handler.validation_error(
      "File path must be a string",
      {parameter = "file_path", provided_type = type(file_path)}
    )
  end
  
  options = options or {}
  
  -- Check if file exists with error handling
  local file_exists, file_exists_error = error_handler.try(function()
    return fs.file_exists(file_path)
  end)
  
  if not file_exists then
    return nil, error_handler.io_error(
      "Failed to check if file exists",
      {file_path = file_path, error = file_exists_error}
    )
  end
  
  if not file_exists[1] then
    return nil, error_handler.io_error(
      "File does not exist",
      {file_path = file_path}
    )
  end
  
  -- Read file with error handling
  local content, read_error = error_handler.safe_io_operation(
    function() return fs.read_file(file_path) end,
    file_path,
    {operation = "read_file"}
  )
  
  if not content then
    return nil, read_error
  end
  
  -- Process the content (just a simple example)
  local result = {
    file_path = file_path,
    content_length = #content,
    lines = 0
  }
  
  -- Count lines with error handling
  local success, lines_result = error_handler.try(function()
    local lines = 0
    for _ in content:gmatch("[^\r\n]+") do
      lines = lines + 1
    end
    return lines
  end)
  
  if success then
    result.lines = lines_result
  else
    -- Non-critical error, log but continue
    if logger then
      logger.warn("Failed to count lines", {
        file_path = file_path,
        error = error_handler.format_error(lines_result)
      })
    end
  end
  
  return result
end

-- Test suite
describe("Standardized Error Handling Example", function()
  -- Test resources for cleanup
  local test_files = {}
  
  -- Cleanup after tests with error handling
  after(function()
    if logger then
      logger.debug("Cleaning up test files", {
        file_count = #test_files
      })
    end
    
    for _, file_path in ipairs(test_files) do
      -- Remove file with error handling
      local success, err = pcall(function()
        return temp_file.remove(file_path)
      end)
      
      if not success then
        if logger then
          logger.warn("Failed to remove test file", {
            file_path = file_path,
            error = tostring(err)
          })
        end
      end
    end
    
    -- Clear the list
    test_files = {}
  end)
  
  -- Pattern 1: Basic Function Call with Error Handling
  describe("Pattern 1: Basic Function Call with Error Handling", function()
    -- Successful case
    it("should process a valid file", function()
      -- Create a test file with error handling
      local content = "Line 1\nLine 2\nLine 3"
      local file_path, create_error = test_helper.with_error_capture(function()
        return temp_file.create_with_content(content, "txt")
      end)()
      
      expect(create_error).to_not.exist("Failed to create test file: " .. tostring(create_error))
      expect(file_path).to.exist()
      
      -- Track for cleanup
      table.insert(test_files, file_path)
      
      -- Process file with error handling
      local result, process_error = test_helper.with_error_capture(function()
        return example_module.process_file(file_path)
      end)()
      
      expect(process_error).to_not.exist("Failed to process file: " .. tostring(process_error))
      expect(result).to.exist()
      expect(result.lines).to.equal(3)
    end)
    
    -- Error case - invalid parameter
    it("should handle invalid file path", { expect_error = true }, function()
      -- Try to process with nil file path
      local result, err = test_helper.with_error_capture(function()
        return example_module.process_file(nil)
      end)()
      
      -- Verify proper error handling
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.message).to.match("must be a string")
    end)
    
    -- Error case - file doesn't exist
    it("should handle non-existent file", { expect_error = true }, function()
      -- Try to process non-existent file
      local result, err = test_helper.with_error_capture(function()
        return example_module.process_file("/non/existent/file.txt")
      end)()
      
      -- Verify proper error handling
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.IO)
      expect(err.message).to.match("not exist")
    end)
  end)
  
  -- Pattern 2: Resource Management with Error Handling
  describe("Pattern 2: Resource Management with Error Handling", function()
    it("should create and manage resources safely", function()
      -- Create multiple test files with error handling
      for i = 1, 3 do
        local content = "Content for file " .. i
        local file_path, create_error = test_helper.with_error_capture(function()
          return temp_file.create_with_content(content, "txt")
        end)()
        
        expect(create_error).to_not.exist("Failed to create test file " .. i .. ": " .. tostring(create_error))
        expect(file_path).to.exist()
        
        -- Track for cleanup
        table.insert(test_files, file_path)
      end
      
      -- Verify all files were created
      expect(#test_files).to.equal(3)
      
      -- Test file existence with error handling
      for i, file_path in ipairs(test_files) do
        local exists, exists_error = test_helper.with_error_capture(function()
          return fs.file_exists(file_path)
        end)()
        
        expect(exists_error).to_not.exist("Failed to check if file " .. i .. " exists: " .. tostring(exists_error))
        expect(exists).to.be_truthy("File " .. i .. " should exist")
      end
    end)
  end)
  
  -- Pattern 3: Multiple Error Return Patterns
  describe("Pattern 3: Multiple Error Return Patterns", function()
    -- Function that returns nil + error
    local function nil_error_function(value)
      if value < 0 then
        return nil, "Value cannot be negative"
      end
      return value * 2
    end
    
    -- Function that returns false (no separate error)
    local function false_function(value)
      if value < 0 then
        return false
      end
      return true
    end
    
    -- Function that returns structured error
    local function structured_error_function(value)
      if value < 0 then
        return nil, error_handler.validation_error(
          "Value cannot be negative",
          {value = value}
        )
      end
      return value * 2
    end
    
    -- Test nil + error pattern
    it("should handle nil + error pattern", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return nil_error_function(-5)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("negative")
    end)
    
    -- Test false pattern
    it("should handle false return pattern", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return false_function(-5)
      end)()
      
      -- Different from nil+error pattern! Just a false result
      expect(result).to.equal(false)
      expect(err).to_not.exist()
    end)
    
    -- Test structured error pattern
    it("should handle structured error pattern", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return structured_error_function(-5)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
      expect(err.context.value).to.equal(-5)
    end)
    
    -- Test flexible error handling that works with all patterns
    it("should handle all error patterns flexibly", { expect_error = true }, function()
      -- Test function that tries all three error patterns
      local function test_all_patterns(pattern_type, value)
        if pattern_type == "nil_error" then
          return nil_error_function(value)
        elseif pattern_type == "false" then
          return false_function(value)
        else
          return structured_error_function(value)
        end
      end
      
      -- A flexible test pattern that handles all error types
      local function test_error_pattern(pattern_type)
        local result, err = test_helper.with_error_capture(function()
          return test_all_patterns(pattern_type, -5)
        end)()
        
        if pattern_type == "false" then
          -- Handle false pattern (no separate error object)
          expect(result).to.equal(false)
        else
          -- Handle nil+error and structured error patterns
          expect(result).to_not.exist()
          expect(err).to.exist()
          
          if pattern_type == "structured" then
            -- For structured errors, check properties
            expect(err.category).to.exist()
            expect(err.context).to.exist()
          else
            -- For string errors, check the message
            expect(err).to.match("negative")
          end
        end
      end
      
      -- Test all patterns
      test_error_pattern("nil_error")
      test_error_pattern("false")
      test_error_pattern("structured")
    end)
  end)
  
  -- Pattern 4: Logger Initialization with Fallback
  describe("Pattern 4: Logger Initialization with Fallback", function()
    it("should initialize logger or create fallback", function()
      -- This pattern is demonstrated in the setup code at the top
      -- Verify logger exists (either real or fallback)
      expect(logger).to.exist()
      expect(type(logger.warn)).to.equal("function")
      expect(type(logger.error)).to.equal("function")
    end)
  end)
end)

-- Run the test suite
firmo.run()

print("\nExample complete!")
print("This example demonstrated standardized error handling patterns in Firmo.")
print("For more details, see the documentation in docs/coverage_repair/error_handling_patterns.md")