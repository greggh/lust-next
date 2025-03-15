#!/usr/bin/env lua
-- Example demonstrating custom formatters in firmo
-- This example creates a module with custom formatters and loads it at runtime

-- Set up package path so we can run this from the examples directory
package.path = "../?.lua;" .. package.path

-- Load firmo and required modules
local firmo = require("firmo")
local reporting = require("src.reporting")

-- Example Module: Custom formatters for firmo
local custom_formatters = {}

-- Define a structure for our formatters
custom_formatters.coverage = {}
custom_formatters.quality = {}
custom_formatters.results = {}

-- Custom Coverage Formatter: Markdown
custom_formatters.coverage.markdown = function(coverage_data)
  local markdown = "# Coverage Report\n\n"
  markdown = markdown .. "## Summary\n\n"
  
  -- Get data from the coverage report
  local summary = coverage_data.summary or {
    total_files = 0,
    covered_files = 0,
    total_lines = 0,
    covered_lines = 0,
    total_functions = 0,
    covered_functions = 0,
    line_coverage_percent = 0,
    function_coverage_percent = 0, 
    overall_percent = 0
  }
  
  -- Add summary data
  markdown = markdown .. "- **Overall Coverage**: " .. string.format("%.2f%%", summary.overall_percent) .. "\n"
  markdown = markdown .. "- **Line Coverage**: " .. summary.covered_lines .. "/" .. summary.total_lines 
             .. " (" .. string.format("%.2f%%", summary.line_coverage_percent) .. ")\n"
  markdown = markdown .. "- **Function Coverage**: " .. summary.covered_functions .. "/" .. summary.total_functions 
             .. " (" .. string.format("%.2f%%", summary.function_coverage_percent) .. ")\n"
  markdown = markdown .. "- **Files**: " .. summary.covered_files .. "/" .. summary.total_files .. "\n\n"
  
  -- Add file table
  markdown = markdown .. "## Files\n\n"
  markdown = markdown .. "| File | Line Coverage | Function Coverage |\n"
  markdown = markdown .. "|------|--------------|-------------------|\n"
  
  -- Add each file
  for file, stats in pairs(coverage_data.files or {}) do
    -- Calculate percentages
    local line_pct = stats.total_lines > 0 and 
                    ((stats.covered_lines or 0) / stats.total_lines * 100) or 0
    local func_pct = stats.total_functions > 0 and 
                    ((stats.covered_functions or 0) / stats.total_functions * 100) or 0
    
    -- Add to table
    markdown = markdown .. "| `" .. file .. "` | " 
               .. stats.covered_lines .. "/" .. stats.total_lines 
               .. " (" .. string.format("%.2f%%", line_pct) .. ") | "
               .. stats.covered_functions .. "/" .. stats.total_functions 
               .. " (" .. string.format("%.2f%%", func_pct) .. ") |\n"
  end
  
  -- Add timestamp
  markdown = markdown .. "\n\n*Report generated on " .. os.date("%Y-%m-%d at %H:%M:%S") .. "*"
  
  return markdown
end

-- Custom Test Results Formatter: Markdown
custom_formatters.results.markdown = function(results_data)
  local markdown = "# Test Results\n\n"
  
  -- Create timestamp and summary info
  local timestamp = results_data.timestamp or os.date("!%Y-%m-%dT%H:%M:%S")
  local tests = results_data.tests or 0
  local failures = results_data.failures or 0
  local errors = results_data.errors or 0
  local skipped = results_data.skipped or 0
  local success_rate = tests > 0 and ((tests - failures - errors) / tests * 100) or 0
  
  -- Add summary data
  markdown = markdown .. "## Summary\n\n"
  markdown = markdown .. "- **Test Suite**: " .. (results_data.name or "Unnamed Test Suite") .. "\n"
  markdown = markdown .. "- **Timestamp**: " .. timestamp .. "\n"
  markdown = markdown .. "- **Total Tests**: " .. tests .. "\n"
  markdown = markdown .. "- **Passed**: " .. (tests - failures - errors - skipped) .. "\n"
  markdown = markdown .. "- **Failed**: " .. failures .. "\n"
  markdown = markdown .. "- **Errors**: " .. errors .. "\n"
  markdown = markdown .. "- **Skipped**: " .. skipped .. "\n"
  markdown = markdown .. "- **Success Rate**: " .. string.format("%.2f%%", success_rate) .. "\n\n"
  
  -- Add test results table
  markdown = markdown .. "## Test Results\n\n"
  markdown = markdown .. "| Test | Status | Duration | Message |\n"
  markdown = markdown .. "|------|--------|----------|--------|\n"
  
  -- Add each test case
  for _, test_case in ipairs(results_data.test_cases or {}) do
    local name = test_case.name or "Unnamed Test"
    local status = test_case.status or "unknown"
    local duration = string.format("%.3fs", test_case.time or 0)
    local message = ""
    
    -- Format status with emojis
    local status_emoji
    if status == "pass" then
      status_emoji = "✅ Pass"
    elseif status == "fail" then
      status_emoji = "❌ Fail"
      message = test_case.failure and test_case.failure.message or ""
    elseif status == "error" then
      status_emoji = "⚠️ Error"
      message = test_case.error and test_case.error.message or ""
    elseif status == "skipped" or status == "pending" then
      status_emoji = "⏭️ Skip"
      message = test_case.skip_message or ""
    else
      status_emoji = "❓ " .. status
    end
    
    -- Sanitize message for markdown table
    message = message:gsub("|", "\\|"):gsub("\n", " ")
    
    -- Add to table
    markdown = markdown .. "| " .. name .. " | " .. status_emoji .. " | " .. duration .. " | " .. message .. " |\n"
  end
  
  -- Add timestamp
  markdown = markdown .. "\n\n*Report generated on " .. os.date("%Y-%m-%d at %H:%M:%S") .. "*"
  
  return markdown
end

-- Register our custom formatters
print("Registering custom formatters...")
reporting.register_coverage_formatter("markdown", custom_formatters.coverage.markdown)
reporting.register_results_formatter("markdown", custom_formatters.results.markdown)

-- Show available formatters
local available = reporting.get_available_formatters()
print("\nAvailable formatters:")
print("  Coverage: " .. table.concat(available.coverage, ", "))
print("  Quality: " .. table.concat(available.quality, ", "))
print("  Results: " .. table.concat(available.results, ", "))

-- Run some simple tests
firmo.describe("Custom Formatter Example", function()
  firmo.it("demonstrates successful tests", function()
    firmo.expect(1 + 1).to.equal(2)
    firmo.expect("test").to.be.a("string")
    firmo.expect({1, 2, 3}).to.contain(2)
  end)
  
  firmo.it("demonstrates a failing test", function()
    -- This test will fail
    firmo.expect(2 + 2).to.equal(5) -- Incorrect expectation
  end)
end)

-- Generate some test data
local results_data = {
  name = "Custom Formatter Example",
  timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
  tests = 2,
  failures = 1,
  errors = 0,
  skipped = 0,
  time = 0.002,
  test_cases = {
    {
      name = "demonstrates successful tests",
      classname = "Custom Formatter Example",
      time = 0.001,
      status = "pass"
    },
    {
      name = "demonstrates a failing test",
      classname = "Custom Formatter Example",
      time = 0.001,
      status = "fail",
      failure = {
        message = "Expected 4 to equal 5",
        type = "Assertion",
        details = "Expected 4 to equal 5"
      }
    }
  }
}

-- Generate and save a markdown report
local markdown_report = reporting.format_results(results_data, "markdown")
reporting.write_file("./custom-report.md", markdown_report)

-- Show output path
print("\nGenerated custom markdown report: ./custom-report.md")
print("\nUsage with command line arguments:")
print("lua run_tests.lua --formatter-module 'custom_formatters_module' --results-format 'markdown'")

-- Return the module so we can be loaded as a formatter module
return custom_formatters
