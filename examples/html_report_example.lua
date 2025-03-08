--[[
  html_report_example.lua
  
  Example demonstrating HTML output format for test results
  in lust-next, including syntax highlighting and detailed statistics.
]]

package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect
local reporting = require("src.reporting")

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

-- Run a simple test for demonstration
describe("HTML Report Generator", function()
  it("generates JUnit XML for test results", function()
    -- Generate JUnit XML
    local junit_xml = reporting.format_results(test_results, "junit")
    
    -- Save the generated JUnit XML to a file
    local xml_file_path = "test-results.xml"
    reporting.write_file(xml_file_path, junit_xml)
    
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
    
    -- Save the TAP output to a file
    local tap_file_path = "test-results.tap"
    reporting.write_file(tap_file_path, tap_output)
    
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
    
    -- Save the CSV output to a file
    local csv_file_path = "test-results.csv"
    reporting.write_file(csv_file_path, csv_output)
    
    -- Display a preview of the CSV output
    print("\n=== CSV Output Preview ===\n")
    print(csv_output:sub(1, 500) .. "...\n")
    
    -- Verify that the file was created successfully
    expect(csv_output).to.match("test_id,test_suite,test_name,status")
    expect(csv_output).to.match("Calculator.BasicMath")
    
    print("CSV report saved to: " .. csv_file_path)
  end)
  
  it("demonstrates auto_save_reports for all formats", function()
    -- Save all report formats using auto_save_reports
    local reports_dir = "test-reports"
    local results = reporting.auto_save_reports(nil, nil, test_results, reports_dir)
    
    -- Verify that all the reports were created successfully
    expect(results.junit.success).to.be.truthy()
    expect(results.tap.success).to.be.truthy()
    expect(results.csv.success).to.be.truthy()
    
    print("\n=== All Reports Generated ===")
    print("Reports saved to directory: " .. reports_dir)
    print("Reports generated: JUnit XML, TAP, CSV")
  end)
end)