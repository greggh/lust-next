-- Enhanced Configuration System Example for lust-next
--
-- This comprehensive example demonstrates the centralized configuration system
-- including report validation, formatter configuration, and more.
-- Run with: lua examples/enhanced_config_example.lua

local lust = require("lust-next")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Create a logger for this example
local logger = logging.get_logger("ConfigExample")
logging.configure({level = "info"})

print("lust-next Enhanced Configuration System Example")
print("===============================================")
print("")

-- Step 1: Create a comprehensive configuration file
print("Step 1: Creating a comprehensive configuration file")
local temp_config_path = "temp_enhanced_config.lua"

local config_content = [[
-- Comprehensive lust-next configuration file
return {
  -- Core options
  debug = false,
  verbose = false,
  
  -- Test execution options
  test = {
    filter = ".*test$",
    tag = "focus",
    timeout = 10
  },
  
  -- Coverage options
  coverage = {
    enabled = true,
    threshold = 85,
    include = { "lib/", "src/" },
    exclude = { "tests/", "examples/" },
    control_flow_keywords_executable = "mixed",
    block_tracking = true
  },
  
  -- Reporting options
  reporting = {
    report_dir = "./enhanced-reports",
    report_suffix = "-demo",
    timestamp_format = "%Y%m%d-%H%M",
    
    -- Formats for different report types
    formats = {
      coverage = {
        default = "html"
      },
      quality = {
        default = "summary"
      }
    },
    
    -- Formatter configurations
    formatters = {
      html = {
        theme = "dark",
        show_line_numbers = true,
        collapsible_sections = true,
        highlight_syntax = true,
        include_legend = true,
        display_execution_counts = true,
        enhance_tooltips = true
      },
      json = {
        pretty = true,
        schema_version = "1.1"
      },
      summary = {
        detailed = true,
        show_files = true,
        colorize = true
      }
    },
    
    -- Validation configuration
    validation = {
      validate_reports = true,
      validate_line_counts = true,
      validate_percentages = true,
      validate_file_paths = true,
      validation_threshold = 0.5,
      warn_on_validation_failure = true
    }
  },
  
  -- Parallel execution options
  parallel = {
    workers = 2,
    timeout = 30
  },
  
  -- Watch mode options
  watch = {
    enabled = false,
    include = { "lib/", "tests/" },
    exclude = { "node_modules/", ".git/" },
    debounce = 500
  }
}
]]

-- Write configuration file
local success, err = fs.write_file(temp_config_path, config_content)
if success then
  print("Created comprehensive config file at " .. temp_config_path)
else
  print("Failed to create config file: " .. (err or "unknown error"))
  os.exit(1)
end

-- Step 2: Load the configuration through the central_config system
print("\nStep 2: Loading configuration through central_config")
local central_config = require("lib.core.central_config")

local load_success, load_err = central_config.load_from_file(temp_config_path)
if load_success then
  print("Successfully loaded configuration from " .. temp_config_path)
else
  print("Failed to load configuration: " .. tostring(load_err))
  os.exit(1)
end

-- Step 3: Access configuration using the central_config system
print("\nStep 3: Accessing configuration values")

-- Access simple values
local debug_mode = central_config.get("debug")
print("Debug mode: " .. tostring(debug_mode))

-- Access nested values
local coverage_threshold = central_config.get("coverage.threshold")
print("Coverage threshold: " .. tostring(coverage_threshold) .. "%")

-- Access formatter configuration
local html_theme = central_config.get("reporting.formatters.html.theme")
print("HTML formatter theme: " .. tostring(html_theme))

-- Access with fallback values
local unknown_value = central_config.get("unknown.value", "default")
print("Unknown value with fallback: " .. tostring(unknown_value))

-- Step 4: Update configuration programmatically
print("\nStep 4: Updating configuration programmatically")

-- Update a simple value
central_config.set("debug", true)
print("Updated debug mode: " .. tostring(central_config.get("debug")))

-- Update a nested value
central_config.set("reporting.formatters.html.theme", "light")
print("Updated HTML theme: " .. tostring(central_config.get("reporting.formatters.html.theme")))

-- Update multiple values at once
central_config.set_multiple({
  ["coverage.threshold"] = 90,
  ["reporting.report_suffix"] = "-updated"
})
print("Updated coverage threshold: " .. tostring(central_config.get("coverage.threshold")) .. "%")
print("Updated report suffix: " .. tostring(central_config.get("reporting.report_suffix")))

-- Step 5: Register change listeners
print("\nStep 5: Registering change listeners")

-- Register a simple listener
local change_count = 0
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  change_count = change_count + 1
  print("Notification " .. change_count .. ": Coverage threshold changed from " .. 
        tostring(old_value) .. " to " .. tostring(new_value))
end)

-- Make changes to trigger listeners
central_config.set("coverage.threshold", 95)
central_config.set("coverage.threshold", 80)

-- Step 6: Create mock coverage data for demonstration
print("\nStep 6: Creating mock coverage data")

local function create_mock_coverage_data()
  return {
    summary = {
      total_files = 2,
      covered_files = 2,
      total_lines = 150,
      covered_lines = 120,
      total_functions = 15,
      covered_functions = 12,
      line_coverage_percent = 80.0,
      function_coverage_percent = 80.0,
      overall_percent = 80.0
    },
    files = {
      ["/path/to/example.lua"] = {
        total_lines = 100,
        covered_lines = 80,
        total_functions = 10,
        covered_functions = 8,
        line_coverage_percent = 80.0,
        function_coverage_percent = 80.0
      },
      ["/path/to/another.lua"] = {
        total_lines = 50,
        covered_lines = 40,
        total_functions = 5,
        covered_functions = 4,
        line_coverage_percent = 80.0,
        function_coverage_percent = 80.0
      }
    },
    original_files = {
      ["/path/to/example.lua"] = {
        source = "function example() return 1 end",
        executable_lines = { [1] = true },
        lines = { [1] = true }
      },
      ["/path/to/another.lua"] = {
        source = "function another() return 2 end",
        executable_lines = { [1] = true },
        lines = { [1] = true }
      }
    }
  }
end

local coverage_data = create_mock_coverage_data()
print("Created mock coverage data with " .. coverage_data.summary.total_files .. " files and " ..
      coverage_data.summary.total_lines .. " lines")

-- Step 7: Validate coverage data using the reporting module
print("\nStep 7: Validating coverage data")

local reporting = require("lib.reporting")

-- First, configure reporting with our configuration
reporting.configure({
  debug = central_config.get("debug"),
  verbose = central_config.get("verbose"),
  report_dir = central_config.get("reporting.report_dir"),
  report_suffix = central_config.get("reporting.report_suffix")
})

-- Basic validation
local is_valid, issues = reporting.validate_coverage_data(coverage_data)
if is_valid then
  print("Basic validation passed")
else
  print("Basic validation failed with " .. #issues .. " issues")
  for i, issue in ipairs(issues) do
    print("  - " .. issue.category .. ": " .. issue.message)
  end
end

-- Comprehensive validation
local result = reporting.validate_report(coverage_data)
if result.validation.is_valid then
  print("Comprehensive validation passed")
  
  -- Show statistics
  print("Statistical analysis:")
  print("  - Mean coverage: " .. string.format("%.2f", result.statistics.mean_line_coverage) .. "%")
  print("  - Median coverage: " .. string.format("%.2f", result.statistics.median_line_coverage) .. "%")
  
  -- Show outliers if any
  if result.statistics.outliers and #result.statistics.outliers > 0 then
    print("  - Found " .. #result.statistics.outliers .. " statistical outliers")
  end
  
  -- Show anomalies if any
  if result.statistics.anomalies and #result.statistics.anomalies > 0 then
    print("  - Found " .. #result.statistics.anomalies .. " anomalies")
  end
else
  print("Comprehensive validation failed with " .. #result.validation.issues .. " issues")
end

-- Step 8: Format coverage data with different formatters
print("\nStep 8: Formatting coverage data")

-- Get HTML formatter configuration from central_config
local html_config = central_config.get("reporting.formatters.html")
reporting.configure_formatter("html", html_config)

-- Format with HTML (result is truncated for display)
local html_report = reporting.format_coverage(coverage_data, "html")
print("HTML report generated (" .. #html_report .. " bytes)")

-- Get JSON formatter configuration from central_config
local json_config = central_config.get("reporting.formatters.json")
reporting.configure_formatter("json", json_config)

-- Format with JSON
local json_report = reporting.format_coverage(coverage_data, "json")
print("JSON report generated (" .. #json_report .. " bytes)")

-- Step 9: Save reports with validation
print("\nStep 9: Saving reports with validation")

-- Create temporary directory for reports
local temp_report_dir = "./temp_reports"
local dir_success, dir_err = fs.ensure_directory_exists(temp_report_dir)
if not dir_success then
  print("Failed to create report directory: " .. (dir_err or "unknown error"))
else
  print("Created report directory: " .. temp_report_dir)
  
  -- Save with validation options
  local report_path = temp_report_dir .. "/coverage-report.html"
  local save_success, save_err = reporting.save_coverage_report(report_path, coverage_data, "html", {
    validate = true,
    strict_validation = false
  })
  
  if save_success then
    print("Successfully saved HTML report to " .. report_path)
  else
    print("Failed to save HTML report: " .. (save_err or "unknown error"))
  end
  
  -- Save with validation report
  local json_path = temp_report_dir .. "/coverage-report.json"
  local json_success, json_err = reporting.save_coverage_report(json_path, coverage_data, "json")
  
  if json_success then
    print("Successfully saved JSON report to " .. json_path)
  else
    print("Failed to save JSON report: " .. (json_err or "unknown error"))
  end
  
  -- Auto-save reports with validation
  local auto_save_results = reporting.auto_save_reports(coverage_data, nil, nil, {
    report_dir = temp_report_dir,
    report_suffix = "-auto",
    validate = true,
    validation_report = true
  })
  
  print("Auto-saved reports to " .. temp_report_dir)
  print("  - HTML: " .. (auto_save_results.html and "Success" or "Failed"))
  print("  - JSON: " .. (auto_save_results.json and "Success" or "Failed"))
  print("  - LCOV: " .. (auto_save_results.lcov and "Success" or "Failed"))
  print("  - Cobertura: " .. (auto_save_results.cobertura and "Success" or "Failed"))
  
  if auto_save_results.validation then
    print("  - Validation report: Success")
  end
end

-- Step 10: Use configuration with lust API
print("\nStep 10: Using configuration with lust API")

-- Apply configuration to lust
lust.config.set_centralized_config(central_config)

-- Run a simple test with the configuration
print("Running a simple test with applied configuration:")

lust.describe("Configuration Example", function()
  lust.it("should pass", function()
    lust.expect(central_config.get("coverage.threshold")).to.be(80)
  end)
end)

-- Step 11: Clean up
print("\nStep 11: Cleaning up")

-- Delete the temporary config file
local delete_success, delete_err = fs.delete_file(temp_config_path)
if delete_success then
  print("Removed temporary config file: " .. temp_config_path)
else
  print("Failed to remove temporary config file: " .. (delete_err or "unknown error"))
end

print("\nThis example demonstrated the centralized configuration system in lust-next.")
print("In a real project, create a .lust-next-config.lua file in your project root.")
print("Use 'lua lust-next.lua --create-config' to generate a template configuration file.")

print("\nFor more information, see the configuration documentation:")
print("- docs/configuration/central_config_guide.md")
print("- docs/configuration/report_validation.md")
print("- docs/configuration/html_formatter.md")
print("- docs/guides/coverage_configuration.md")