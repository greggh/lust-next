-- Example demonstrating Cobertura XML coverage report generation
local lust = require('../lust-next')

-- Mock coverage data for the example
local mock_coverage_data = {
  files = {
    ["src/calculator.lua"] = {
      lines = {
        [1] = true,  -- This line was covered
        [2] = true,  -- This line was covered
        [3] = true,  -- This line was covered
        [5] = false, -- This line was not covered
        [6] = true,  -- This line was covered
        [8] = false, -- This line was not covered
        [9] = false  -- This line was not covered
      },
      functions = {
        ["add"] = true,      -- This function was covered
        ["subtract"] = true, -- This function was covered
        ["multiply"] = false, -- This function was not covered
        ["divide"] = false   -- This function was not covered
      },
      total_lines = 10,
      covered_lines = 4,
      total_functions = 4,
      covered_functions = 2
    },
    ["src/utils.lua"] = {
      lines = {
        [1] = true,  -- This line was covered
        [2] = true,  -- This line was covered
        [4] = true,  -- This line was covered
        [5] = true,  -- This line was covered
        [7] = false  -- This line was not covered
      },
      functions = {
        ["validate"] = true,  -- This function was covered
        ["format"] = false    -- This function was not covered
      },
      total_lines = 8,
      covered_lines = 4,
      total_functions = 2,
      covered_functions = 1
    }
  },
  summary = {
    total_files = 2,
    covered_files = 2,
    total_lines = 18,
    covered_lines = 8,
    total_functions = 6,
    covered_functions = 3,
    line_coverage_percent = 44.4, -- 8/18
    function_coverage_percent = 50.0, -- 3/6
    overall_percent = 47.2 -- (44.4 + 50.0) / 2
  }
}

-- Get the reporting module
local reporting = require('lib.reporting')

-- Generate and display Cobertura XML report
print("Generating Cobertura XML report...")
local xml_report = reporting.format_coverage(mock_coverage_data, "cobertura")
print(xml_report)

-- Save the report to a file
print("\nSaving report to coverage-reports/coverage-report.cobertura...")
local success, err = reporting.save_coverage_report(
  "coverage-reports/coverage-report.cobertura",
  mock_coverage_data,
  "cobertura"
)

if success then
  print("Report saved successfully!")
else
  print("Failed to save report: " .. tostring(err))
end

-- Demonstrating auto_save_reports with all formats
print("\nSaving reports in all formats using auto_save_reports...")
local results = reporting.auto_save_reports(mock_coverage_data)

print("\nReport Generation Results:")
for format, result in pairs(results) do
  print(string.format("- %s: %s (%s)", 
    format,
    result.success and "Success" or "Failed",
    result.path
  ))
end

print("\nCobertura XML report is now saved and can be used with CI/CD systems that support this format.")
print("Common systems that use Cobertura XML include:")
print("- Jenkins with the Cobertura Plugin")
print("- GitHub Actions with the codecov action")
print("- GitLab CI with the coverage functionality")
print("- Azure DevOps with the Publish Code Coverage task")

print("\nExample complete!")