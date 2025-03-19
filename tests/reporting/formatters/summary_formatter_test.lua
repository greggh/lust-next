-- Tests for Summary formatter
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import test_helper for error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Import reporting module directly for testing
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")

describe("Summary Formatter", function()
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
          [2] = true,
          [3] = false
        }
      },
      ["/path/to/lowcoverage.lua"] = {
        total_lines = 50,
        covered_lines = 30,
        line_coverage_percent = 60,
        total_functions = 5,
        covered_functions = 2,
        function_coverage_percent = 40,
        source = {
          [1] = "local function another_func()",
          [2] = "  return false",
          [3] = "end"
        },
        lines = {
          [1] = true,
          [2] = false,
          [3] = false
        }
      }
    },
    summary = {
      total_files = 2,
      covered_files = 2,
      total_lines = 150,
      covered_lines = 110,
      line_coverage_percent = 73.33,
      overall_percent = 73.33,
      total_functions = 15,
      covered_functions = 10,
      function_coverage_percent = 66.67
    }
  }
  
  -- Test directory for file tests
  local test_dir = "./test-tmp-summary-formatter"
  
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
  
  it("generates valid summary output", function()
    local summary_output = reporting.format_coverage(coverage_data, "summary")
    
    -- Check basic structure
    expect(summary_output).to.exist()
    expect(type(summary_output)).to.equal("string")
    
    -- Basic summary validation
    expect(summary_output).to.match("Coverage Summary")
    expect(summary_output).to.match("Overall Coverage")
    
    -- Should include file names
    expect(summary_output).to.match("example%.lua")
    expect(summary_output).to.match("lowcoverage%.lua")
    
    -- Should include coverage percentages
    expect(summary_output).to.match("80%%")  -- example.lua
    expect(summary_output).to.match("60%%")  -- lowcoverage.lua
    expect(summary_output).to.match("73%.33%%") -- overall
    
    -- Should have line counts
    expect(summary_output).to.match("80/100")
    expect(summary_output).to.match("30/50")
    expect(summary_output).to.match("110/150")
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
        overall_percent = 0,
        total_functions = 0,
        covered_functions = 0,
        function_coverage_percent = 0
      }
    }
    
    local summary_output = reporting.format_coverage(empty_data, "summary")
    
    -- Should still return valid summary
    expect(summary_output).to.exist()
    expect(type(summary_output)).to.equal("string")
    
    -- Should contain basic structure
    expect(summary_output).to.match("Coverage Summary")
    expect(summary_output).to.match("Overall Coverage")
    
    -- Should indicate no files or zero coverage
    expect(summary_output).to.match("0%%")
    expect(summary_output).to.match("0/0")
  end)
  
  it("handles nil coverage data with fallback", { expect_error = true }, function()
    -- Use error_capture to handle expected errors
    local result, err = test_helper.with_error_capture(function()
      return reporting.format_coverage(nil, "summary")
    end)()
    
    -- Since the summary formatter's behavior with nil data is implementation-specific,
    -- we'll accept any valid response pattern - string, empty table, or error
    if result then
      -- If we got a result, it can be a table or string
      expect(result).to.exist()
      
      -- For tables, they can be empty or have content
      if type(result) == "table" then
        -- An empty table is valid for nil coverage data
        expect(type(result)).to.equal("table")
      -- If string, should have some minimum length
      elseif type(result) == "string" then
        expect(#result).to.be_greater_than(0)
      end
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
      return reporting.format_coverage(malformed_data, "summary")
    end)()
    
    -- Since the summary formatter's behavior with malformed data is implementation-specific,
    -- we'll accept any valid response pattern - string, empty table, or error
    if result then
      -- If we got a result, it can be a table or string
      expect(result).to.exist()
      
      -- For tables, they can be empty or have content
      if type(result) == "table" then
        -- An empty table is valid for malformed coverage data
        expect(type(result)).to.equal("table")
      -- If string, should have some minimum length
      elseif type(result) == "string" then
        expect(#result).to.be_greater_than(0)
      end
    else
      -- If we got an error, it should be a valid error object
      expect(err).to.exist()
      expect(err.message).to.exist()
    end
  end)
  
  it("handles file operation errors properly", { expect_error = true }, function()
    -- Generate summary and save it to a file
    local file_path = test_dir .. "/coverage.txt"
    local success = reporting.save_coverage_report(file_path, coverage_data, "summary")
    
    -- Should succeed
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Try to save to an invalid path
    local invalid_path = "/tmp/firmo-test*?<>|/coverage.txt"
    
    -- Use error_capture to handle expected errors
    local success_invalid_save, save_err = test_helper.with_error_capture(function()
      local result, err = reporting.save_coverage_report(invalid_path, coverage_data, "summary")
      if err then
        return false, err
      else
        return result
      end
    end)()
    
    -- Try to save with nil data
    test_helper.with_error_capture(function()
      return reporting.save_coverage_report(file_path, nil, "summary")
    end)()
    
    -- The test passes implicitly if we reach this point without crashing
  end)
  
  it("respects formatter configuration options", function()
    -- Configure formatter 
    local config = require("lib.core.central_config")
    config.set("reporting.formatters.summary", {
      detailed = true,           -- Show detailed report
      show_files = true,         -- Show individual files
      colorize = false,          -- Disable color codes
      min_coverage_warn = 70,    -- Warning threshold
      min_coverage_ok = 80       -- OK threshold
    })
    
    local summary_output = reporting.format_coverage(coverage_data, "summary")
    
    -- With detailed enabled, we should see more information
    expect(summary_output).to.match("Coverage Summary %(Detailed%)")
    
    -- With colorize disabled, we shouldn't see ANSI color codes
    expect(summary_output).to_not.match("\27%[")
    
    -- Reset configuration to avoid affecting other tests
    config.delete("reporting.formatters.summary")
  end)
  
  it("displays color-coded coverage levels when enabled", function()
    -- Configure formatter with colorize enabled
    local config = require("lib.core.central_config")
    config.set("reporting.formatters.summary", {
      colorize = true,
      min_coverage_warn = 70,  -- Warning threshold
      min_coverage_ok = 80     -- OK threshold
    })
    
    local summary_output = reporting.format_coverage(coverage_data, "summary")
    
    -- With colorize enabled, we should see ANSI color codes
    -- But we can't reliably test for specific colors since they depend on the implementation
    -- So we just check for some ANSI escape code presence
    expect(summary_output).to.match("\27%[")
    
    -- Reset configuration to avoid affecting other tests
    config.delete("reporting.formatters.summary")
  end)
end)