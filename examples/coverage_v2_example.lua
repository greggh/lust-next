--[[
  Coverage V2 Example
  
  This example demonstrates how to use the new v2 coverage system to track
  code coverage and generate reports in multiple formats.
]]

-- Import the coverage module
local coverage = require("lib.coverage")

-- Start coverage tracking
print("Starting coverage tracking...")
coverage.start()

-- Import a module to track
local calculator = require("lib.samples.calculator")

-- Execute some code from the module
print("Executing calculator functions...")
local sum = calculator.add(10, 5)
print("10 + 5 =", sum)

local product = calculator.multiply(7, 3)
print("7 * 3 =", product)

-- We intentionally don't call subtract to demonstrate partial coverage

-- Stop coverage tracking
print("Stopping coverage tracking...")
coverage.stop()

-- Get a list of available report formats
local formats = coverage.get_available_formats()
print("Available report formats:", table.concat(formats, ", "))

-- Create a directory for reports
local reports_dir = "./coverage-reports/"
os.execute("mkdir -p " .. reports_dir)

-- Generate reports in all available formats
print("Generating coverage reports...")
local success, err = coverage.generate_reports(reports_dir, formats)

if not success then
  print("Error generating reports:", err)
  os.exit(1)
end

-- Print a summary of the coverage data
local coverage_data = coverage.get_report_data()
local summary = coverage_data.summary

print("\nCoverage Summary:")
print("  Total Files:", summary.total_files)
print("  Line Coverage:", summary.line_coverage_percent .. "%")
print("  Function Coverage:", summary.function_coverage_percent .. "%")

print("\nReports have been generated in:", reports_dir)
print("Report files:")
for _, format in ipairs(formats) do
  print("  coverage-report." .. format)
end

print("\nOpen the HTML report in your browser to view detailed coverage information.")