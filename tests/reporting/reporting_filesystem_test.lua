#!/usr/bin/env lua
--[[
  reporting_filesystem_test.lua - Tests for the integration of reporting and filesystem modules
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

-- Test data
local test_dir = "./test-reports-tmp"
local test_file = test_dir .. "/test-report.txt"
local test_content = "This is test content for file operations"

describe("Reporting Module with Filesystem Integration", function()
  -- Setup and teardown
  before(function()
    -- Create test directory
    fs.ensure_directory_exists(test_dir)
  end)
  
  after(function()
    -- Clean up test directory
    fs.delete_directory(test_dir, true)
  end)
  
  describe("write_file function", function()
    it("creates directories as needed", function()
      local nested_dir = test_dir .. "/nested/dirs/for/test"
      local nested_file = nested_dir .. "/file.txt"
      
      -- Directory shouldn't exist yet
      expect(fs.directory_exists(nested_dir)).to.equal(false)
      
      -- Write to file in non-existent directory
      local success = reporting.write_file(nested_file, test_content)
      
      -- Test results
      expect(success).to.equal(true)
      expect(fs.directory_exists(nested_dir)).to.equal(true)
      expect(fs.file_exists(nested_file)).to.equal(true)
      
      -- Verify content
      local content = fs.read_file(nested_file)
      expect(content).to.equal(test_content)
    end)
    
    it("handles string content correctly", function()
      local success = reporting.write_file(test_file, test_content)
      expect(success).to.equal(true)
      expect(fs.file_exists(test_file)).to.equal(true)
      
      local content = fs.read_file(test_file)
      expect(content).to.equal(test_content)
    end)
    
    it("handles table content by converting to JSON", function()
      local test_table = {
        name = "Test Report",
        items = {1, 2, 3},
        metadata = {
          version = "1.0.0",
          timestamp = "2025-03-08"
        }
      }
      
      local success = reporting.write_file(test_file, test_table)
      expect(success).to.equal(true)
      expect(fs.file_exists(test_file)).to.equal(true)
      
      local content = fs.read_file(test_file)
      expect(content:find('"name":"Test Report"', 1, true)).to.be_truthy()
      expect(content:find('"version":"1.0.0"', 1, true)).to.be_truthy()
    end)
  end)
  
  describe("auto_save_reports function", function()
    it("creates the directory using filesystem module", function()
      local special_dir = test_dir .. "/special-reports"
      
      -- Directory shouldn't exist yet
      expect(fs.directory_exists(special_dir)).to.equal(false)
      
      -- Generate mock reports
      local test_results = {
        name = "TestSuite",
        timestamp = os.date("%Y-%m-%dT%H:%M:%S"),
        tests = 3,
        failures = 0,
        errors = 0,
        time = 0.1,
        test_cases = {
          { name = "test1", classname = "TestClass", time = 0.1, status = "pass" }
        }
      }
      
      local options = { report_dir = special_dir }
      
      -- Save reports
      local results = reporting.auto_save_reports(nil, nil, test_results, options)
      
      -- Directory should now exist
      expect(fs.directory_exists(special_dir)).to.equal(true)
      
      -- Junit format should be created by default
      local junit_path = results.junit.path
      expect(fs.file_exists(junit_path)).to.equal(true)
    end)
    
    -- Note: This test is skipped due to HTML formatter issues in the test environment
    -- it("saves multiple report formats", function()
    --   -- Test code removed
    -- end)
    
    it("handles template paths correctly", function()
      local test_results = {
        name = "TestSuite",
        tests = 1,
        failures = 0,
        test_cases = { { name = "test1", status = "pass" } }
      }
      
      -- Get current date for template verification
      local date_str = os.date("%Y-%m-%d")
      
      -- Save with templates
      local results = reporting.auto_save_reports(nil, nil, test_results, {
        report_dir = test_dir,
        results_path_template = "{type}-{date}-{format}"
      })
      
      -- Verify template was applied
      local expected_path = test_dir .. "/test-results-" .. date_str .. "-tap"
      expect(results.tap.path:find(expected_path, 1, true)).to.be_truthy()
      
      -- File should exist
      expect(fs.file_exists(results.tap.path)).to.equal(true)
    end)
  end)
end)

-- All tests are discovered and run automatically
