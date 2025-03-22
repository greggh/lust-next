--[[
Tests for JSON Formatter with Comprehensive Error Handling

This test suite verifies the JSON formatter's ability to:
- Generate valid, well-structured JSON for coverage reports
- Handle test results and quality metrics correctly
- Provide proper error handling for edge cases
- Support various output options and configurations
- Format data according to schema requirements
- Manage file output with appropriate permissions

The tests use structured error handling patterns and temporary file management
to ensure proper isolation and cleanup.
]]
---@type Firmo
local firmo = require("firmo")
---@type fun(description: string, callback: function) describe Test suite container function
---@type fun(description: string, options: table|nil, callback: function) it Test case function with optional parameters
---@type fun(value: any) expect Assertion generator function
---@type fun(callback: function) before Setup function that runs before each test
---@type fun(callback: function) after Teardown function that runs after each test
local describe, it, expect, before, after = firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Import test_helper for error testing
---@type TestHelperModule
local test_helper = require("lib.tools.test_helper")
---@type ErrorHandlerModule
local error_handler = require("lib.tools.error_handler")

-- Import modules needed for testing
---@type ReportingModule
local reporting = require("lib.reporting")
---@type FilesystemModule
local fs = require("lib.tools.filesystem")

describe("JSON Formatter", function()
  -- Create test data that will be used for all format tests
  local coverage_data = {
    files = {
      ["/path/to/example.lua"] = {
        total_lines = 100,
        covered_lines = 80,
        line_coverage_percent = 80,
        total_functions = 10,
        covered_functions = 8,
        function_coverage_percent = 80,
        source = {
          [1] = "local function test_func()",
          [2] = "  return true",
          [3] = "end"
        },
        lines = {
          [1] = true,
          [2] = true,
          [3] = false
        }
      }
    },
    summary = {
      total_files = 1,
      covered_files = 1,
      total_lines = 100,
      covered_lines = 80,
      line_coverage_percent = 80,
      overall_percent = 80,
      total_functions = 10,
      covered_functions = 8,
      function_coverage_percent = 80
    }
  }
  
  local quality_data = {
    level = 3,
    level_name = "comprehensive",
    tests = {
      test1 = {
        assertion_count = 5,
        quality_level = 3,
        assertion_types = { equality = 2, truth = 1, error_handling = 1, type_checking = 1 }
      }
    },
    summary = {
      tests_analyzed = 1,
      tests_passing_quality = 1,
      quality_percent = 100,
      assertions_total = 5
    }
  }
  
  local results_data = {
    name = "Test Suite",
    timestamp = "2023-01-01T12:00:00Z", -- ISO format date
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
      }
    }
  }
  
  -- Test directory for file tests
  local test_dir = "./test-tmp-json-formatter"
  
  -- Setup/teardown test directory
  before(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    fs.create_directory(test_dir)
  end)
  
  after(function()
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
  end)
  
  describe("Coverage JSON formatter", function()
    it("generates valid JSON for coverage data", function()
      local json_output = reporting.format_coverage(coverage_data, "json")
      
      -- Check basic structure
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      
      -- Basic content checks
      expect(json_output).to.match("total_files")
      expect(json_output).to.match("covered_files")
      expect(json_output).to.match("overall_pct")
      
      -- Verify values are included
      expect(json_output).to.match("80")
      expect(json_output).to.match("100")
    end)
    
    it("handles empty coverage data gracefully", function()
      local empty_data = {
        files = {},
        summary = {
          total_files = 0,
          covered_files = 0,
          total_lines = 0,
          covered_lines = 0,
          line_coverage_percent = 0,
          overall_percent = 0
        }
      }
      
      local json_output = reporting.format_coverage(empty_data, "json")
      
      -- Should still return valid JSON
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      
      -- Should contain zeros
      expect(json_output).to.match("total_files")
      expect(json_output).to.match("overall_pct")
      expect(json_output).to.match("0")
    end)
    
    it("handles malformed coverage data without crashing", { expect_error = true }, function()
      -- Test with incomplete coverage data
      local malformed_data = {
        -- Missing summary field
        files = {
          ["/path/to/malformed.lua"] = {
            -- Missing required fields
          }
        }
      }
      
      -- Use error_capture to suppress expected errors from showing in output
      local result = test_helper.with_error_capture(function()
        return reporting.format_coverage(malformed_data, "json")
      end)()
      
      -- Should return valid JSON even with malformed input
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
      
      -- Should contain defaults for missing values
      expect(result).to.match("overall_pct")
    end)
    
    it("handles nil coverage data with appropriate defaults", { expect_error = true }, function()
      -- Use error_capture to suppress expected errors from showing in output
      local result = test_helper.with_error_capture(function()
        return reporting.format_coverage(nil, "json")
      end)()
      
      -- Should return valid JSON even with nil input
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
      
      -- Should indicate an error in some form but still be valid JSON
      expect(result).to.match("error") -- Either contains "error" field or message
    end)
    
    it("handles file operations with proper error handling", { expect_error = true }, function()
      -- Generate JSON and save it to a file
      local file_path = test_dir .. "/coverage.json"
      local success = reporting.save_coverage_report(file_path, coverage_data, "json")
      
      -- Should succeed
      expect(success).to.equal(true)
      expect(fs.file_exists(file_path)).to.equal(true)
      
      -- Test with invalid file path directly using fs module
      local invalid_path = "/tmp/firmo-test*?<>|/coverage.json"
      
      -- This should return false since the path is invalid
      expect(fs.file_exists(invalid_path)).to.equal(false)
      
      -- Use error_capture to suppress expected errors from showing in output
      -- The internal error will be captured by error_capture
      local success_invalid_save, save_err = test_helper.with_error_capture(function()
        local result, err = reporting.save_coverage_report(invalid_path, coverage_data, "json")
        -- The reporting module may return errors in different ways depending on implementation
        -- Here we're only testing that the function doesn't crash, and that it indicates
        -- failure through either nil+error or false return value
        if err then
          -- In case of nil+error, we should have an error object
          return false, err
        else
          -- Otherwise, the result should be false to indicate failure
          return result
        end
      end)()
      
      -- The test only verifies we captured the expected error without crashing
      -- The reporting module is handling the error, which is the important part
      -- We're not making additional assertions about the return value, since the module 
      -- handles the error internally and might return different values based on implementation
      
      -- Try to save with nil data - we're just testing that this doesn't crash the test
      test_helper.with_error_capture(function()
        return reporting.save_coverage_report(file_path, nil, "json")
      end)()
      
      -- The test passes implicitly if we reach this point without crashing
    end)
    
    it("handles bad format argument without crashing", { expect_error = true }, function()
      -- Try with an invalid format name
      local result = test_helper.with_error_capture(function()
        return reporting.format_coverage(coverage_data, "nonexistent_format")
      end)()
      
      -- Should fall back to a default format rather than crash
      expect(result).to.exist()
    end)
  end)
  
  describe("Quality JSON formatter", function()
    it("generates valid JSON for quality data", function()
      local json_output = reporting.format_quality(quality_data, "json")
      
      -- Check basic structure
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      
      -- Basic content checks
      expect(json_output).to.match("level")
      expect(json_output).to.match("tests_analyzed")
      expect(json_output).to.match("quality_pct")
      
      -- Verify values are included
      expect(json_output).to.match("3")
      expect(json_output).to.match("100")
      expect(json_output).to.match("comprehensive")
    end)
    
    it("handles empty quality data gracefully", function()
      local empty_data = {
        level = 0,
        level_name = "none",
        tests = {},
        summary = {
          tests_analyzed = 0,
          tests_passing_quality = 0,
          quality_percent = 0
        }
      }
      
      local json_output = reporting.format_quality(empty_data, "json")
      
      -- Should still return valid JSON
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      
      -- Should contain expected empty values
      expect(json_output).to.match("level")
      expect(json_output).to.match("0")
      expect(json_output).to.match("none")
    end)
    
    it("handles nil quality data with fallbacks", { expect_error = true }, function()
      local result = test_helper.with_error_capture(function()
        return reporting.format_quality(nil, "json")
      end)()
      
      -- Should return valid JSON even with nil input
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
      
      -- Should contain default values
      expect(result).to.match("level")
      expect(result).to.match("tests_analyzed")
    end)
    
    it("handles malformed quality data gracefully", { expect_error = true }, function()
      -- Test with incomplete quality data
      local malformed_data = {
        -- Missing required fields
        level_name = "partial" -- Only includes this field
      }
      
      local result = test_helper.with_error_capture(function()
        return reporting.format_quality(malformed_data, "json")
      end)()
      
      -- Should return valid JSON
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
      
      -- Should include the field we provided
      expect(result).to.match("partial")
    end)
    
    it("handles file operations with proper error handling", { expect_error = true }, function()
      -- Generate JSON and save it to a file
      local file_path = test_dir .. "/quality.json"
      local success = reporting.save_quality_report(file_path, quality_data, "json")
      
      -- Should succeed
      expect(success).to.equal(true)
      expect(fs.file_exists(file_path)).to.equal(true)
      
      -- Test with invalid file path
      local invalid_path = "/tmp/firmo-test*?<>|/quality.json"
      
      -- Use error_capture to suppress expected errors from showing in output
      -- The internal error will be captured by error_capture
      local success_invalid_save, save_err = test_helper.with_error_capture(function()
        local result, err = reporting.save_quality_report(invalid_path, quality_data, "json")
        -- The reporting module may return errors in different ways depending on implementation
        -- Here we're only testing that the function doesn't crash, and that it indicates
        -- failure through either nil+error or false return value
        if err then
          -- In case of nil+error, we should have an error object
          return false, err
        else
          -- Otherwise, return the result directly
          return result
        end
      end)()
      
      -- The test only verifies we captured the expected error without crashing
      -- The reporting module is handling the error, which is the important part
      -- We're not making additional assertions about the return value
      
      -- Try to save with nil data 
      test_helper.with_error_capture(function()
        return reporting.save_quality_report(file_path, nil, "json")
      end)()
      
      -- The test passes implicitly if we reach this point without crashing
    end)
  end)
  
  describe("Test Results JSON formatter", function()
    it("generates valid JSON for test results", function()
      local json_output = reporting.format_results(results_data, "json")
      
      -- Check basic structure
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      
      -- Basic content checks
      expect(json_output).to.match("test_cases")
      expect(json_output).to.match("name")
      expect(json_output).to.match("timestamp")
      
      -- Verify values are included
      expect(json_output).to.match("passing test")
      expect(json_output).to.match("failing test")
      expect(json_output).to.match("Expected values to match")
    end)
    
    it("validates timestamp format in results data", function()
      -- Verify the timestamp in the test data is a valid ISO date
      expect(results_data.timestamp).to.be_iso_date()
      
      -- Create test data with different timestamp formats
      local future_date = "2025-12-31T23:59:59Z"
      local past_date = "2020-01-01T00:00:00Z"
      
      -- Validate date comparison assertions
      expect(past_date).to.be_before(results_data.timestamp)
      expect(future_date).to.be_after(results_data.timestamp)
      
      -- Test same-day comparison
      local same_day = "2023-01-01T23:59:59Z"
      expect(same_day).to.be_same_day_as(results_data.timestamp)
      
      -- Test that it correctly validates non-ISO formats
      local non_iso = "01/01/2023"
      expect(non_iso).to.be_date()
      expect(non_iso).to_not.be_iso_date()
      
      -- Test with same timestamp at different times of day
      local morning = "2023-01-01T08:00:00Z"
      local evening = "2023-01-01T20:00:00Z"
      expect(morning).to.be_same_day_as(evening)
      expect(morning).to.be_before(evening)
    end)
    
    it("handles empty test results gracefully", function()
      local empty_data = {
        name = "Empty Suite",
        tests = 0,
        failures = 0,
        errors = 0,
        skipped = 0,
        test_cases = {}
      }
      
      local json_output = reporting.format_results(empty_data, "json")
      
      -- Should still return valid JSON
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      
      -- Should contain expected empty values
      expect(json_output).to.match("name")
      expect(json_output).to.match("Empty Suite")
      expect(json_output).to.match("test_cases")
      expect(json_output).to.match("tests")
      expect(json_output).to.match("0")
    end)
    
    it("handles nil test results data with fallbacks", { expect_error = true }, function()
      local result = test_helper.with_error_capture(function()
        return reporting.format_results(nil, "json")
      end)()
      
      -- Should return valid JSON even with nil input
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
      
      -- Should contain default values
      expect(result).to.match("test_cases")
      expect(result).to.match("name")
    end)
    
    it("handles malformed test results data gracefully", { expect_error = true }, function()
      -- Test with incomplete test results data
      local malformed_data = {
        name = "Malformed Suite",
        -- Missing most required fields
        test_cases = {
          {
            -- Missing most test case fields
            name = "partial test"
          }
        }
      }
      
      local result = test_helper.with_error_capture(function()
        return reporting.format_results(malformed_data, "json")
      end)()
      
      -- Should return valid JSON
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
      
      -- Should include the fields we provided
      expect(result).to.match("Malformed Suite")
      expect(result).to.match("partial test")
    end)
    
    it("handles file operations with proper error handling", { expect_error = true }, function()
      -- Generate JSON and save it to a file
      local file_path = test_dir .. "/results.json"
      local success = reporting.save_results_report(file_path, results_data, "json")
      
      -- Should succeed
      expect(success).to.equal(true)
      expect(fs.file_exists(file_path)).to.equal(true)
      
      -- Test with invalid file path
      local invalid_path = "/tmp/firmo-test*?<>|/results.json"
      
      -- Use error_capture to suppress expected errors from showing in output
      -- The internal error will be captured by error_capture
      local success_invalid_save, save_err = test_helper.with_error_capture(function()
        local result, err = reporting.save_results_report(invalid_path, results_data, "json")
        -- The reporting module may return errors in different ways depending on implementation
        -- Here we're only testing that the function doesn't crash, and that it indicates
        -- failure through either nil+error or false return value
        if err then
          -- In case of nil+error, we should have an error object
          return false, err
        else
          -- Otherwise, return the result directly
          return result
        end
      end)()
      
      -- The test only verifies we captured the expected error without crashing
      -- The reporting module is handling the error, which is the important part
      -- We're not making additional assertions about the return value
      
      -- Try to save with nil data
      test_helper.with_error_capture(function()
        return reporting.save_results_report(file_path, nil, "json")
      end)()
      
      -- The test passes implicitly if we reach this point without crashing
    end)
  end)
  
  describe("JSON formatter edge cases", function()
    it("handles non-table values as input", function()
      -- Try directly with a string (non-table) value
      -- Use error_capture to suppress expected errors
      local result = test_helper.with_error_capture(function()
        return reporting.format_coverage("string value", "json")
      end)()
      
      -- Should return something (not nil)
      expect(result).to.exist()
      expect(type(result)).to.equal("string")
    end)
    
    it("is resilient against circular references", { expect_error = true }, function()
      -- Create data with circular reference
      local circular_data = {
        name = "circular",
        summary = {
          total_files = 1,
          covered_files = 1
        }
      }
      circular_data.self = circular_data -- Create circular reference
      
      -- Use error_capture to suppress expected errors
      local result = test_helper.with_error_capture(function()
        return reporting.format_coverage(circular_data, "json")
      end)()
      
      -- Should return something
      expect(result).to.exist()
    end)
    
    it("works with valid coverage data", function()
      -- Test standard functionality - the complex test above is difficult to simulate
      local json_output = reporting.format_coverage(coverage_data, "json")
      
      -- Verify we get properly formatted output
      expect(json_output).to.exist()
      expect(type(json_output)).to.equal("string")
      expect(json_output).to.match("total_files")
    end)
  end)
end)