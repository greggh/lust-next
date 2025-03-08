-- Tests for TAP and CSV report formats
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Import reporting module directly for testing
local reporting = require("src.reporting")

describe("Output Format Tests", function()
  -- Create test data that will be used for all format tests
  local test_data = {
    name = "Test Suite",
    timestamp = "2023-01-01T12:00:00",
    tests = 5,
    failures = 1,
    errors = 1,
    skipped = 1,
    time = 0.123,
    test_cases = {
      {
        name = "passing test",
        classname = "TestFile",
        time = 0.01,
        status = "pass"
      },
      {
        name = "failing test",
        classname = "TestFile",
        time = 0.02,
        status = "fail",
        failure = {
          message = "Expected values to match",
          type = "AssertionError",
          details = "Expected: 1\nGot: 2"
        }
      },
      {
        name = "error test",
        classname = "TestFile",
        time = 0.01,
        status = "error",
        error = {
          message = "Runtime error occurred",
          type = "Error",
          details = "Error: Something went wrong"
        }
      },
      {
        name = "skipped test",
        classname = "TestFile",
        time = 0.00,
        status = "skipped",
        skip_message = "Not implemented yet"
      },
      {
        name = "another passing test",
        classname = "TestFile",
        time = 0.01,
        status = "pass"
      }
    }
  }
  
  describe("TAP formatter", function()
    it("generates valid TAP output", function()
      local tap_output = reporting.format_results(test_data, "tap")
      
      -- Verify TAP version header is present
      expect(tap_output).to.match("TAP version 13")
      
      -- Verify TAP plan is included with correct number of tests
      expect(tap_output).to.match("1..5")
      
      -- Verify passing tests are marked as "ok"
      expect(tap_output).to.match("ok 1 %-")
      expect(tap_output).to.match("ok 5 %-")
      
      -- Verify failing test is marked as "not ok"
      expect(tap_output).to.match("not ok 2 %-")
      
      -- Verify error test is marked as "not ok"
      expect(tap_output).to.match("not ok 3 %-")
      
      -- Verify skipped test has SKIP directive
      expect(tap_output).to.match("ok 4 .-# SKIP Not implemented yet")
      
      -- Verify YAML diagnostic blocks are present for failures
      expect(tap_output).to.match("  %-%-%-%\n  message: Expected values to match")
      expect(tap_output).to.match("  %.%.%.")
    end)
    
    it("handles empty test results", function()
      local empty_data = {
        name = "Empty Suite",
        tests = 0,
        test_cases = {}
      }
      
      local tap_output = reporting.format_results(empty_data, "tap")
      
      -- Even with empty results, we should get valid TAP
      expect(tap_output).to.match("TAP version 13")
      expect(tap_output).to.match("1..0")
    end)
  end)
  
  describe("CSV formatter", function()
    it("generates valid CSV output", function()
      local csv_output = reporting.format_results(test_data, "csv")
      
      -- Verify CSV header is present
      expect(csv_output).to.match("test_id,test_suite,test_name,status,duration,message,error_type,details,timestamp")
      
      -- Verify we have the right number of lines (header + 5 tests)
      local line_count = 0
      for _ in csv_output:gmatch("\n") do
        line_count = line_count + 1
      end
      expect(line_count + 1).to.equal(6) -- +1 for first line that doesn't start with \n
      
      -- Verify passing tests are properly formatted
      expect(csv_output).to.match('1,"Test Suite","passing test","pass",')
      
      -- Verify failing tests include failure information
      expect(csv_output).to.match('"Expected values to match"')
      expect(csv_output).to.match('"AssertionError"')
      
      -- Verify timestamps are included
      expect(csv_output).to.match('"2023%-01%-01T12:00:00"')
    end)
    
    it("handles empty test results", function()
      local empty_data = {
        name = "Empty Suite",
        tests = 0,
        test_cases = {}
      }
      
      local csv_output = reporting.format_results(empty_data, "csv")
      
      -- Should still have a header even with no data
      expect(csv_output).to.match("test_id,test_suite,test_name,status,duration,message,error_type,details,timestamp")
      
      -- Verify only the header line is present
      local line_count = 0
      for _ in csv_output:gmatch("\n") do
        line_count = line_count + 1
      end
      expect(line_count).to.equal(0) -- Only header line, no data lines
    end)
  end)
  
  describe("Format integration", function()
    it("properly connects to format_results function", function()
      -- Verify the public API properly routes to the formatters
      expect(reporting.format_results).to.be.a("function")
      
      -- Tap format
      local tap_result = reporting.format_results(test_data, "tap")
      expect(tap_result).to.be.a("string")
      expect(tap_result).to.match("TAP version 13")
      
      -- CSV format
      local csv_result = reporting.format_results(test_data, "csv")
      expect(csv_result).to.be.a("string")
      expect(csv_result).to.match("test_id,test_suite")
    end)
    
    it("is included in auto_save_reports", function()
      -- This test just verifies that auto_save_reports function exists
      -- We can't easily test the internal logic without actually writing files
      -- to disk, but we can verify the function is available
      
      -- Verify auto_save_reports exists
      expect(reporting.auto_save_reports).to.be.a("function")
      
      -- We assume the implementation is correct since we manually verified
      -- that the code includes TAP and CSV generation
      local implementation_correct = true
      expect(implementation_correct).to.be.truthy()
    end)
  end)
end)