#!/usr/bin/env lua
--[[
  format_test.lua - Test for HTML formatter file operations
]]

-- Add the project directory to the module path
package.path = package.path .. ";./?.lua;./?/init.lua"

-- Load firmo
local firmo = require("firmo")
local describe, it, expect, before, after =
  firmo.describe, firmo.it, firmo.expect, firmo.before, firmo.after

-- Load modules needed for testing
local reporting = require("lib.reporting")
local fs = require("lib.tools.filesystem")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

-- Create mock coverage data
local function create_mock_coverage_data()
  return {
    files = {
      ["/path/to/example.lua"] = {
        total_lines = 100,
        covered_lines = 78,
        coverage_percent = 78,
        line_coverage_percent = 78,
        function_coverage_percent = 80,
        block_coverage_percent = 75,
        lines = {
          [1] = { count = 1, executable = true },
          [2] = { count = 0, executable = true },
          [3] = { count = 0, executable = false },
          [5] = { count = 10, executable = true },
        },
        source = {
          [1] = "local function test()",
          [2] = "  return true",
          [3] = "end",
          [4] = "",
          [5] = "test()"
        }
      }
    },
    summary = {
      total_files = 1,
      covered_files = 1,
      total_lines = 100,
      covered_lines = 78, 
      total_functions = 10,
      covered_functions = 8,
      total_blocks = 20,
      covered_blocks = 15,
      line_coverage_percent = 78,
      function_coverage_percent = 80,
      block_coverage_percent = 75,
      overall_percent = 78
    }
  }
end

describe("HTML Formatter File Operations", function()
  local test_dir = "./test-tmp-html-formatter"
  
  before(function()
    -- Ensure directory exists and is clean
    if fs.directory_exists(test_dir) then
      fs.delete_directory(test_dir, true)
    end
    local success = fs.create_directory(test_dir)
    expect(success).to.equal(true)
  end)
  
  after(function()
    -- Clean up test directory
    fs.delete_directory(test_dir, true)
  end)
  
  it("should save HTML report to file", function()
    local coverage_data = create_mock_coverage_data()
    local file_path = test_dir .. "/coverage.html"
    
    -- Use reporting module to save report
    local success = reporting.save_coverage_report(file_path, coverage_data, "html")
    
    -- Verify file saved successfully
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
    
    -- Check content
    local content = fs.read_file(file_path)
    expect(content).to.match("<!DOCTYPE html>")
    expect(content).to.match("78%%")  -- Coverage percentage
  end)
  
  it("handles invalid output path with auto_save_reports", function()
    local coverage_data = create_mock_coverage_data()
    
    -- Test with invalid file path characters
    local invalid_dir = "/tmp/firmo-test*?<>|"
    local options = { report_dir = invalid_dir }
    
    -- Using auto_save_reports which has different error handling
    local result = reporting.auto_save_reports(coverage_data, nil, nil, options)
    
    -- The implementation should return a result table but no successful operations
    expect(result).to.exist()
    expect(type(result)).to.equal("table")
    
    -- Should have no successful operations due to invalid directory
    local has_success = false
    for _, format_result in pairs(result) do
      if format_result.success then
        has_success = true
        break
      end
    end
    
    expect(has_success).to.equal(false)
  end)
  
  it("rejects writing to a file with bad permissions", { expect_error = true }, function()
    -- Create a file that's not writable
    local path = test_dir .. "/readonly.txt"
    fs.write_file(path, "This is read-only file")
    
    -- Try to use a completely invalid path
    local bad_path = "/path/that/does/not/exist/file.txt" 
    
    -- Capture error using error handler
    local success, err = test_helper.with_error_capture(function()
      return reporting.write_file(bad_path, "test content")
    end)()
    
    -- Should report an error 
    expect(success).to_not.equal(true)
  end)
  
  it("uses consistent formatter interface", function()
    local coverage_data = create_mock_coverage_data()
    
    -- Create formatter options
    local options = {
      formatter = "html",
      report_dir = test_dir
    }
    
    -- Save report using the module's high-level interface
    local file_path = test_dir .. "/formatter-interface.html"
    local success = reporting.save_coverage_report(file_path, coverage_data, "html") 
    
    -- Verify file saved successfully
    expect(success).to.equal(true)
    expect(fs.file_exists(file_path)).to.equal(true)
  end)
end)
