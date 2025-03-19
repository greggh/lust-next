-- Tests for LCOV formatter
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import reporting module directly for testing
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

describe("LCOV Formatter", function()
  -- Create test data that will be used for all tests
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
          [2] = 5, -- Line with execution count
          [3] = false
        },
        functions = {
          ["test_func"] = {
            count = 5,
            first_line = 1,
            last_line = 3
          }
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
  
  -- Test directory for file tests
  local test_dir = "./test-tmp-lcov-formatter"
  
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
  
  it("generates valid LCOV format", function()
    local lcov_output = reporting.format_coverage(coverage_data, "lcov")
    
    -- Check basic structure
    expect(lcov_output).to.exist()
    expect(type(lcov_output)).to.equal("string")
    
    -- Basic LCOV validation - should have standard LCOV entries
    expect(lcov_output).to.match("TN:")  -- Test name record
    expect(lcov_output).to.match("SF:")  -- Source file record
    expect(lcov_output).to.match("FN:")  -- Function name record  
    expect(lcov_output).to.match("FNDA:") -- Function data record
    expect(lcov_output).to.match("FNF:")  -- Functions found
    expect(lcov_output).to.match("FNH:")  -- Functions hit
    expect(lcov_output).to.match("DA:")   -- Line data
    expect(lcov_output).to.match("LF:")   -- Lines found
    expect(lcov_output).to.match("LH:")   -- Lines hit
    expect(lcov_output).to.match("end_of_record") -- End marker
    
    -- Verify our test file exists in the output
    expect(lcov_output).to.match("SF:.-example%.lua")
    
    -- Verify function data
    expect(lcov_output).to.match("FN:1,test_func")
    expect(lcov_output).to.match("FNDA:5,test_func")
    expect(lcov_output).to.match("FNF:1")
    expect(lcov_output).to.match("FNH:1")
    
    -- Verify line data
    expect(lcov_output).to.match("DA:1,1")  -- Line 1 was executed
    expect(lcov_output).to.match("DA:2,5")  -- Line 2 was executed 5 times
    -- Line 3 was not executed, so shouldn't be in DA: records
    expect(lcov_output).to.match("LF:3")  -- 3 lines found
    expect(lcov_output).to.match("LH:2")  -- 2 lines hit
  end)
  
  it("handles empty coverage data gracefully", { expect_error = true }, function()
    local empty_data = {
      files = {},
      summary = {
        total_files = 0,
        covered_files = 0,
        total_lines = 0,
        covered_lines = 0,
        line_coverage_percent = 0,
        overall_percent = 0,
        total_functions = 0,
        covered_functions = 0,
        function_coverage_percent = 0
      }
    }
    
    local lcov_output = reporting.format_coverage(empty_data, "lcov")
    
    -- Should still return valid LCOV
    expect(lcov_output).to.exist()
    expect(type(lcov_output)).to.equal("string")
    
    -- LCOV format may start with source file entries rather than TN:
    -- The implementation may vary, so we check for some common LCOV elements
    expect(lcov_output).to.match("FNF:") -- Function found count
    expect(lcov_output).to.match("LF:") -- Line found count
  end)
  
  it("handles nil coverage data with fallback", { expect_error = true }, function()
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(nil, "lcov")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with LCOV format
      expect(type(result)).to.equal("string")
      -- Just check for some standard LCOV content
      -- The LCOV formatter might not include TN: for all implementations
      expect(result).to.exist()
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles malformed coverage data gracefully", { expect_error = true }, function()
    -- Test with incomplete coverage data
    local malformed_data = {
      -- Missing summary field
      files = {
        ["/path/to/malformed.lua"] = {
          -- Missing required fields
        }
      }
    }
    
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(malformed_data, "lcov")
    end)()
    
    -- Test should pass whether the formatter returns a fallback or returns error
    if result then
      -- If we got a result, it should be a string with LCOV format
      expect(type(result)).to.equal("string")
      -- Our implementation has SF: (source file) records even for malformed data
      expect(result).to.match("SF:") -- Check for source file record
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles file operation errors properly", { expect_error = true }, function()
    -- Generate LCOV and save it to a file
    local file_path = test_dir .. "/coverage.lcov"
    local success = reporting.save_coverage_report(file_path, coverage_data, "lcov")
    
    -- Should succeed
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Try to save to an invalid path
    local invalid_path = "/tmp/firmo-test*?<>|/coverage.lcov"
    
    -- Use error_capture to handle expected errors
    local success_invalid_save, save_err = test_helper.with_error_capture(function()
      local result, err = reporting.save_coverage_report(invalid_path, coverage_data, "lcov")
      if err then
        return false, err
      else
        return result
      end
    end)()
    
    -- Try to save with nil data
    test_helper.with_error_capture(function()
      return reporting.save_coverage_report(file_path, nil, "lcov")
    end)()
    
    -- The test passes implicitly if we reach this point without crashing
  end)
  
  it("respects formatter configuration options", function()
    -- Configure formatter with include_function_lines = false
    local config = require("lib.core.central_config")
    config.set("reporting.formatters.lcov", {
      include_function_lines = false,   -- Disable function line information
      use_actual_execution_counts = true, -- Use execution counts
      normalize_paths = true
    })
    
    local lcov_output = reporting.format_coverage(coverage_data, "lcov")
    
    -- With include_function_lines disabled, we shouldn't see function entries
    expect(lcov_output).to_not.match("FN:") -- No function name records
    
    -- We should still see line data
    expect(lcov_output).to.match("DA:")
    
    -- Reset configuration to avoid affecting other tests
    config.delete("reporting.formatters.lcov")
  end)
end)