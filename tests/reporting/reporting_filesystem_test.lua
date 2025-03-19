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
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

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
    
    it("handles invalid file paths", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return reporting.write_file("", test_content)
      end)()
      
      -- The implementation returns nil, but we might get an error
      expect(result).to_not.exist()
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
    
    it("handles invalid report directory", { expect_error = true }, function()
      -- Set options with an invalid directory
      local invalid_path = "/tmp/firmo-test-invalid-dir-with-chars*?<>|"
      local options = { report_dir = invalid_path }
      
      local result, err = test_helper.with_error_capture(function()
        return reporting.auto_save_reports(nil, nil, nil, options)
      end)()
      
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
    
    it("saves multiple report formats", { expect_error = true }, function()
      local coverage_data = {
        files = {
          ["/path/to/example.lua"] = {
            total_lines = 100,
            covered_lines = 80,
            total_functions = 10,
            covered_functions = 8,
            line_coverage_percent = 80,
            function_coverage_percent = 80,
            lines = { [5] = true, [10] = true, [15] = true },
            functions = { ["test_func"] = true }
          }
        },
        summary = {
          total_files = 1,
          covered_files = 1,
          total_lines = 100,
          covered_lines = 80,
          total_functions = 10,
          covered_functions = 8,
          line_coverage_percent = 80,
          function_coverage_percent = 80,
          overall_percent = 80
        }
      }
      
      local quality_data = {
        level = 3,
        level_name = "comprehensive",
        tests = {
          ["test1"] = {
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
      
      -- Save reports
      local multiple_formats_dir = test_dir .. "/multiple-formats"
      local results = reporting.auto_save_reports(
        coverage_data, 
        quality_data,
        nil, -- No test results
        { report_dir = multiple_formats_dir }
      )
      
      -- Verify directory was created
      expect(fs.directory_exists(multiple_formats_dir)).to.equal(true)
      
      -- Check that multiple formats were generated
      local has_html = results.html and results.html.success
      local has_json = results.json and results.json.success
      local has_lcov = results.lcov and results.lcov.success
      
      -- At least one report format should have succeeded
      expect(has_html or has_json or has_lcov).to.equal(true)
      
      -- Verify that files exist for successful formats
      if has_html then
        expect(fs.file_exists(results.html.path)).to.equal(true)
      end
      
      if has_json then
        expect(fs.file_exists(results.json.path)).to.equal(true)
      end
      
      if has_lcov then
        expect(fs.file_exists(results.lcov.path)).to.equal(true)
      end
      
      -- Quality reports should also have been generated
      local has_quality_html = results.quality_html and results.quality_html.success
      local has_quality_json = results.quality_json and results.quality_json.success
      
      -- At least one quality report format should have succeeded
      expect(has_quality_html or has_quality_json).to.equal(true)
    end)
    
    it("handles template paths correctly", { expect_error = true }, function()
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
