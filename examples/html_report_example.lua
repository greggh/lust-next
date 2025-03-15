--[[
  html_report_example.lua
  
  Example demonstrating HTML output format for test results
  in firmo, including syntax highlighting and detailed statistics.
]]

package.path = "../?.lua;" .. package.path
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import the filesystem module
local fs = require("lib.tools.filesystem")
local reporting = require("lib.reporting")

-- Mock test results data
local test_results = {
  name = "HTML Report Example",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
  tests = 8,
  failures = 1,
  errors = 1,
  skipped = 1,
  time = 0.15, -- Execution time in seconds
  test_cases = {
    {
      name = "addition works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass"
    },
    {
      name = "subtraction works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass"
    },
    {
      name = "multiplication works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass"
    },
    {
      name = "division works correctly",
      classname = "Calculator.BasicMath",
      time = 0.001,
      status = "pass"
    },
    {
      name = "division by zero throws error",
      classname = "Calculator.ErrorHandling",
      time = 0.002,
      status = "fail",
      failure = {
        message = "Expected error not thrown",
        type = "AssertionError",
        details = "Expected function to throw 'Division by zero' error\nBut no error was thrown"
      }
    },
    {
      name = "square root of negative numbers",
      classname = "Calculator.AdvancedMath",
      time = 0.001,
      status = "error",
      error = {
        message = "Runtime error in test",
        type = "Error",
        details = "attempt to call nil value (method 'sqrt')"
      }
    },
    {
      name = "logarithm calculations",
      classname = "Calculator.AdvancedMath",
      time = 0.000,
      status = "skipped",
      skip_message = "Advanced math module not implemented"
    },
    {
      name = "rounding behavior",
      classname = "Calculator.AdvancedMath",
      time = 0.001,
      status = "pass"
    }
  }
}

-- Use the existing reports directory structure
local reports_base_dir = "examples/reports/html-report-examples"
fs.ensure_directory_exists(reports_base_dir)

-- Run a simple test for demonstration
describe("HTML Report Generator", function()
  it("generates JUnit XML for test results", function()
    -- Generate JUnit XML
    local junit_xml = reporting.format_results(test_results, "junit")
    
    -- Save the generated JUnit XML to a file using filesystem module
    local xml_file_path = fs.join_paths(reports_base_dir, "test-results.xml")
    fs.write_file(xml_file_path, junit_xml)
    
    -- Display a preview of the XML
    print("\n=== JUnit XML Preview ===\n")
    print(junit_xml:sub(1, 500) .. "...\n")
    
    -- Verify that the file was created successfully
    expect(junit_xml).to.match("<testsuite")
    expect(junit_xml).to.match("HTML Report Example")
    expect(junit_xml).to.match("<testcase")
    
    print("JUnit XML report saved to: " .. xml_file_path)
  end)
  
  it("generates TAP format for test results", function()
    -- Generate TAP output
    local tap_output = reporting.format_results(test_results, "tap")
    
    -- Save the TAP output to a file using filesystem module
    local tap_file_path = fs.join_paths(reports_base_dir, "test-results.tap")
    fs.write_file(tap_file_path, tap_output)
    
    -- Display a preview of the TAP output
    print("\n=== TAP Output Preview ===\n")
    print(tap_output:sub(1, 500) .. "...\n")
    
    -- Verify that the file was created successfully
    expect(tap_output).to.match("TAP version 13")
    expect(tap_output).to.match("1..8")
    expect(tap_output).to.match("ok 1 -")
    
    print("TAP report saved to: " .. tap_file_path)
  end)
  
  it("generates CSV format for test results", function()
    -- Generate CSV output
    local csv_output = reporting.format_results(test_results, "csv")
    
    -- Save the CSV output to a file using filesystem module
    local csv_file_path = fs.join_paths(reports_base_dir, "test-results.csv")
    fs.write_file(csv_file_path, csv_output)
    
    -- Display a preview of the CSV output
    print("\n=== CSV Output Preview ===\n")
    print(csv_output:sub(1, 500) .. "...\n")
    
    -- Verify that the file was created successfully
    expect(csv_output).to.match("test_id,test_suite,test_name,status")
    expect(csv_output).to.match("Calculator.BasicMath")
    
    print("CSV report saved to: " .. csv_file_path)
  end)
  
  it("demonstrates auto_save_reports with filesystem integration", function()
    -- Create a structured reports directory using filesystem module
    local reports_dir = fs.join_paths(reports_base_dir, "auto-generated")
    fs.ensure_directory_exists(reports_dir)
    
    -- Create a timestamp directory for better organization
    local timestamp = os.date("%Y-%m-%d_%H-%M-%S")
    local timestamped_dir = fs.join_paths(reports_dir, timestamp)
    fs.ensure_directory_exists(timestamped_dir)
    
    -- Advanced configuration with templates
    local config = {
      report_dir = timestamped_dir,
      report_suffix = "-v1.0",
      timestamp_format = "%Y-%m-%d",
      results_path_template = "results-{format}{suffix}",
      verbose = true
    }
    
    -- Save all report formats using auto_save_reports
    local results = reporting.auto_save_reports(nil, nil, test_results, config)
    
    -- Verify that all the reports were created successfully
    expect(results.junit.success).to.be.truthy()
    expect(results.tap.success).to.be.truthy()
    expect(results.csv.success).to.be.truthy()
    
    print("\n=== All Reports Generated Using Filesystem Module ===")
    print("Reports saved to directory: " .. timestamped_dir)
    print("Reports generated: JUnit XML, TAP, CSV")
    
    -- Print the normalized paths to demonstrate filesystem module usage
    print("Normalized path example: " .. fs.normalize_path(timestamped_dir))
  end)
  
  it("demonstrates HTML report generation with stylesheet customization", function()
    -- Generate HTML output for test results
    -- HTML formatter is coming from lib/reporting/formatters/html.lua and uses the filesystem module internally
    local html_results = reporting.format_results(test_results, "html")
    
    -- Create a directory for HTML reports using filesystem module
    local html_dir = fs.join_paths(reports_base_dir, "html")
    fs.ensure_directory_exists(html_dir)
    
    -- Save the HTML output to a file
    local html_file_path = fs.join_paths(html_dir, "test-results.html")
    fs.write_file(html_file_path, html_results)
    
    print("\n=== HTML Report Generated ===")
    print("HTML report saved to: " .. html_file_path)
    print("HTML length: " .. #html_results .. " bytes")
  end)
end)
