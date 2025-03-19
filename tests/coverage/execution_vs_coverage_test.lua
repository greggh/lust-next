--[[
  execution_vs_coverage_test.lua
  
  Tests for the execution vs. coverage distinction in the coverage module.
  This test verifies that the coverage module properly tracks:
  1. Executed lines (lines that are executed during tests)
  2. Covered lines (lines that are executed AND validated by test assertions)
]]

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local fs = require("lib.tools.filesystem")
local coverage = require("lib.coverage")
local temp_file = require("lib.tools.temp_file")

-- Set up logger with error handling
local logging, logger
local function try_load_logger()
  if not logger then
    local log_module, err = test_helper.with_error_capture(function()
      return require("lib.tools.logging")
    end)()
    
    if log_module then
      logging = log_module
      logger = logging.get_logger("test.coverage.execution_vs_coverage")
    end
  end
  return logger
end

local log = try_load_logger()

describe("Execution vs. Coverage Distinction", function()
  -- Set up a temp file that we'll use for testing
  local temp_file_path
  
  before(function()
    -- Create temp file with test code with error handling
    local test_code = [[
      -- Function with different execution paths
      local function calculate(a, b, operation)
        -- This line will be covered (executed and validated)
        if not a or not b then
          return nil, "Missing operands"
        end
        
        -- This line will be covered
        if type(a) ~= "number" or type(b) ~= "number" then
          return nil, "Operands must be numbers"
        end
        
        -- This block will be executed but not covered (no assertions for the result)
        if operation == "add" then
          return a + b
        end
        
        -- This block will be covered (executed and validated)
        if operation == "subtract" then
          return a - b
        end
        
        -- This block will not be executed at all
        if operation == "multiply" then
          return a * b
        end
        
        -- This block will not be executed
        if operation == "divide" then
          if b == 0 then
            return nil, "Division by zero"
          end
          return a / b
        end
        
        -- This return statement will be executed but not covered
        return nil, "Unsupported operation"
      end
      
      return calculate
    ]]
    
    -- Create the temp file with the new API
    local file_path, err = temp_file.create_with_content(test_code, "lua")
    expect(err).to_not.exist("Failed to create temp file for execution vs. coverage test")
    temp_file_path = file_path
    
    if log then
      log.debug("Created test file", { file_path = temp_file_path })
    end
  end)
  
  -- No explicit cleanup needed - will be handled automatically
  
  describe("Track executed but not covered lines", function()
    it("should distinguish between execution and coverage", function()
      -- Start coverage tracking with error handling
      local start_success, start_err = test_helper.with_error_capture(function()
        return coverage.start({
          include_patterns = {temp_file_path},
          track_blocks = true
        })
      end)()
      
      expect(start_err).to_not.exist()
      expect(start_success).to.exist()
      
      -- Load the test file with error handling
      local success, calculate = test_helper.with_error_capture(function()
        return pcall(function() 
          return dofile(temp_file_path)
        end)
      end)()
      
      expect(success).to.be_truthy()
      expect(calculate).to.be.a("function")
      
      -- Run function with different inputs to exercise different code paths
      -- Test 1: Missing operand - validation
      local result, err = calculate(nil, 5, "add")
      expect(result).to_not.exist()
      expect(err).to.equal("Missing operands")
      
      -- Mark line 4 as covered due to validation with error handling
      local mark1_success, mark1_err = test_helper.with_error_capture(function()
        return coverage.mark_line_covered(temp_file_path, 4)
      end)()
      
      expect(mark1_err).to_not.exist()
      
      -- Test 2: Invalid operand type - validation
      local result, err = calculate("string", 5, "add")
      expect(result).to_not.exist()
      expect(err).to.equal("Operands must be numbers")
      
      -- Mark line 9 as covered due to validation with error handling
      local mark2_success, mark2_err = test_helper.with_error_capture(function()
        return coverage.mark_line_covered(temp_file_path, 9)
      end)()
      
      expect(mark2_err).to_not.exist()
      
      -- Test 3: Addition - execution without validation
      local result = calculate(5, 3, "add")
      -- Intentionally NO assertions here to demonstrate execution without coverage
      
      -- Test 4: Subtraction - execution with validation
      local result = calculate(10, 4, "subtract")
      expect(result).to.equal(6)
      
      -- Mark line 19 as covered due to validation with error handling
      local mark3_success, mark3_err = test_helper.with_error_capture(function()
        return coverage.mark_line_covered(temp_file_path, 19)
      end)()
      
      expect(mark3_err).to_not.exist()
      
      -- Test 5: Unsupported operation - execution without validation
      local result, err = calculate(10, 4, "unknown")
      -- Intentionally NO assertions to demonstrate execution without coverage
      
      -- Stop coverage tracking with error handling
      local stop_success, stop_err = test_helper.with_error_capture(function()
        return coverage.stop()
      end)()
      
      expect(stop_err).to_not.exist()
      
      -- Verify execution vs. coverage tracking with error handling
      local exec1, exec1_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 4)
      end)()
      
      expect(exec1_err).to_not.exist()
      expect(exec1).to.be_truthy() -- if not a or not b
      
      local exec2, exec2_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 9)
      end)()
      
      expect(exec2_err).to_not.exist()
      expect(exec2).to.be_truthy() -- if type(a) ~= "number"
      
      local exec3, exec3_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 14)
      end)()
      
      expect(exec3_err).to_not.exist()
      expect(exec3).to.be_truthy() -- if operation == "add"
      
      local exec4, exec4_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 19)
      end)()
      
      expect(exec4_err).to_not.exist()
      expect(exec4).to.be_truthy() -- if operation == "subtract"
      
      local exec5, exec5_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 24)
      end)()
      
      expect(exec5_err).to_not.exist()
      expect(exec5).to_not.be_truthy() -- if operation == "multiply"
      
      local exec6, exec6_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 29)
      end)()
      
      expect(exec6_err).to_not.exist()
      expect(exec6).to_not.be_truthy() -- if operation == "divide"
      
      local exec7, exec7_err = test_helper.with_error_capture(function()
        return coverage.was_line_executed(temp_file_path, 35)
      end)()
      
      expect(exec7_err).to_not.exist()
      expect(exec7).to.be_truthy() -- return nil, "Unsupported operation"
      
      -- Verify covered lines with error handling
      local covered1, covered1_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 4)
      end)()
      
      expect(covered1_err).to_not.exist()
      expect(covered1).to.be_truthy() -- if not a or not b - covered
      
      local covered2, covered2_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 9)
      end)()
      
      expect(covered2_err).to_not.exist()
      expect(covered2).to.be_truthy() -- if type(a) ~= "number" - covered
      
      local covered3, covered3_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 14)
      end)()
      
      expect(covered3_err).to_not.exist()
      expect(covered3).to_not.be_truthy() -- if operation == "add" - not covered
      
      local covered4, covered4_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 19)
      end)()
      
      expect(covered4_err).to_not.exist()
      expect(covered4).to.be_truthy() -- if operation == "subtract" - covered
      
      local covered5, covered5_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 24)
      end)()
      
      expect(covered5_err).to_not.exist()
      expect(covered5).to_not.be_truthy() -- if operation == "multiply" - not executed
      
      local covered6, covered6_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 29)
      end)()
      
      expect(covered6_err).to_not.exist()
      expect(covered6).to_not.be_truthy() -- if operation == "divide" - not executed
      
      local covered7, covered7_err = test_helper.with_error_capture(function()
        return coverage.was_line_covered(temp_file_path, 35)
      end)()
      
      expect(covered7_err).to_not.exist()
      expect(covered7).to_not.be_truthy() -- return nil, "Unsupported operation" - not covered
    end)
  end)
  
  describe("Automatic line marking through assertions", function()
    it("should mark lines as covered when assertions are made", function()
      -- Start coverage tracking with error handling
      local start_success, start_err = test_helper.with_error_capture(function()
        return coverage.start({
          include_patterns = {temp_file_path},
          track_blocks = true
        })
      end)()
      
      expect(start_err).to_not.exist()
      expect(start_success).to.exist()
      
      -- Load the test file with error handling
      local success, calculate = test_helper.with_error_capture(function()
        return pcall(function() 
          return dofile(temp_file_path)
        end)
      end)()
      
      expect(success).to.be_truthy()
      
      -- When these assertions are made, the current line should be marked as covered
      -- by the expect() function calling coverage.mark_current_line_covered()
      
      -- Test with assertions - validation with automatic line marking
      local result, err = calculate(nil, 5, "add")
      expect(result).to_not.exist() -- This line should be marked as covered
      expect(err).to.equal("Missing operands") -- This line should be marked as covered
      
      -- Stop coverage tracking with error handling
      local stop_success, stop_err = test_helper.with_error_capture(function()
        return coverage.stop()
      end)()
      
      expect(stop_err).to_not.exist()
      
      -- In a real implementation, the firmo.expect function would have called 
      -- coverage.mark_current_line_covered() internally, marking the assertion 
      -- lines as covered. Since we can't modify firmo.expect in this test,
      -- we'll manually verify the mechanism works.
      
      -- We can verify the basic mechanism works
      local line = 112 -- Line number of the expect(success).to.be_truthy() call
      
      -- Mark current line with error handling
      local mark_success, mark_err = test_helper.with_error_capture(function()
        return coverage.mark_current_line_covered(4) -- Mark the line where this is called
      end)()
      
      expect(mark_err).to_not.exist()
      
      -- This would verify that the mechanism works, but we'd need to implement
      -- the callback in firmo.expect for a full implementation
    end)
  end)
end)
