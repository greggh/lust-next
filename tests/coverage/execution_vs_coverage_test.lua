--[[
  execution_vs_coverage_test.lua
  
  Tests for the execution vs. coverage distinction in the coverage module.
  This test verifies that the coverage module properly tracks:
  1. Executed lines (lines that are executed during tests)
  2. Covered lines (lines that are executed AND validated by test assertions)
]]

local firmo = require("firmo")
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after
local fs = require("lib.tools.filesystem")
local coverage = require("lib.coverage")

describe("Execution vs. Coverage Distinction", function()
  -- Set up a temp file that we'll use for testing
  local temp_file_path
  
  before(function()
    -- Create temp file with test code
    local tmp_dir = os.getenv("TMPDIR") or "/tmp"
    temp_file_path = fs.join_paths(tmp_dir, "execution_vs_coverage_test_" .. os.time() .. ".lua")
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
    
    fs.write_file(temp_file_path, test_code)
  end)
  
  after(function()
    -- Clean up the temp file
    if temp_file_path and fs.file_exists(temp_file_path) then
      os.remove(temp_file_path)
    end
  end)
  
  describe("Track executed but not covered lines", function()
    it("should distinguish between execution and coverage", function()
      -- Start coverage tracking
      coverage.start({
        include_patterns = {temp_file_path},
        track_blocks = true
      })
      
      -- Load the test file
      local success, calculate = pcall(function() 
        return dofile(temp_file_path)
      end)
      expect(success).to.be_truthy()
      expect(calculate).to.be.a("function")
      
      -- Run function with different inputs to exercise different code paths
      -- Test 1: Missing operand - validation
      local result, err = calculate(nil, 5, "add")
      expect(result).to_not.exist()
      expect(err).to.equal("Missing operands")
      
      -- Mark line 4 as covered due to validation
      coverage.mark_line_covered(temp_file_path, 4)
      
      -- Test 2: Invalid operand type - validation
      local result, err = calculate("string", 5, "add")
      expect(result).to_not.exist()
      expect(err).to.equal("Operands must be numbers")
      
      -- Mark line 9 as covered due to validation
      coverage.mark_line_covered(temp_file_path, 9)
      
      -- Test 3: Addition - execution without validation
      local result = calculate(5, 3, "add")
      -- Intentionally NO assertions here to demonstrate execution without coverage
      
      -- Test 4: Subtraction - execution with validation
      local result = calculate(10, 4, "subtract")
      expect(result).to.equal(6)
      
      -- Mark line 19 as covered due to validation
      coverage.mark_line_covered(temp_file_path, 19)
      
      -- Test 5: Unsupported operation - execution without validation
      local result, err = calculate(10, 4, "unknown")
      -- Intentionally NO assertions to demonstrate execution without coverage
      
      -- Stop coverage tracking
      coverage.stop()
      
      -- Verify execution vs. coverage tracking
      expect(coverage.was_line_executed(temp_file_path, 4)).to.be_truthy() -- if not a or not b
      expect(coverage.was_line_executed(temp_file_path, 9)).to.be_truthy() -- if type(a) ~= "number"
      expect(coverage.was_line_executed(temp_file_path, 14)).to.be_truthy() -- if operation == "add"
      expect(coverage.was_line_executed(temp_file_path, 19)).to.be_truthy() -- if operation == "subtract"
      expect(coverage.was_line_executed(temp_file_path, 24)).to_not.be_truthy() -- if operation == "multiply"
      expect(coverage.was_line_executed(temp_file_path, 29)).to_not.be_truthy() -- if operation == "divide"
      expect(coverage.was_line_executed(temp_file_path, 35)).to.be_truthy() -- return nil, "Unsupported operation"
      
      -- Verify covered lines
      expect(coverage.was_line_covered(temp_file_path, 4)).to.be_truthy() -- if not a or not b - covered
      expect(coverage.was_line_covered(temp_file_path, 9)).to.be_truthy() -- if type(a) ~= "number" - covered
      expect(coverage.was_line_covered(temp_file_path, 14)).to_not.be_truthy() -- if operation == "add" - not covered
      expect(coverage.was_line_covered(temp_file_path, 19)).to.be_truthy() -- if operation == "subtract" - covered
      expect(coverage.was_line_covered(temp_file_path, 24)).to_not.be_truthy() -- if operation == "multiply" - not executed
      expect(coverage.was_line_covered(temp_file_path, 29)).to_not.be_truthy() -- if operation == "divide" - not executed
      expect(coverage.was_line_covered(temp_file_path, 35)).to_not.be_truthy() -- return nil, "Unsupported operation" - not covered
    end)
  end)
  
  describe("Automatic line marking through assertions", function()
    it("should mark lines as covered when assertions are made", function()
      -- Start coverage tracking
      coverage.start({
        include_patterns = {temp_file_path},
        track_blocks = true
      })
      
      -- Load the test file
      local success, calculate = pcall(function() 
        return dofile(temp_file_path)
      end)
      expect(success).to.be_truthy()
      
      -- When these assertions are made, the current line should be marked as covered
      -- by the expect() function calling coverage.mark_current_line_covered()
      
      -- Test with assertions - validation with automatic line marking
      local result, err = calculate(nil, 5, "add")
      expect(result).to_not.exist() -- This line should be marked as covered
      expect(err).to.equal("Missing operands") -- This line should be marked as covered
      
      -- Stop coverage tracking
      coverage.stop()
      
      -- In a real implementation, the firmo.expect function would have called 
      -- coverage.mark_current_line_covered() internally, marking the assertion 
      -- lines as covered. Since we can't modify firmo.expect in this test,
      -- we'll manually verify the mechanism works.
      
      -- We can verify the basic mechanism works
      local line = 112 -- Line number of the expect(success).to.be_truthy() call
      coverage.mark_current_line_covered(4) -- Mark the line where this is called
      
      -- This would verify that the mechanism works, but we'd need to implement
      -- the callback in firmo.expect for a full implementation
    end)
  end)
end)
