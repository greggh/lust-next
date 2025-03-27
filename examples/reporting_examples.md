# Reporting Module Examples

This document provides practical examples of using the firmo reporting module.

## Basic Reporting Examples

### Generating Coverage Reports

```lua
-- Basic coverage report generation
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Run tests with coverage enabled
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

-- Get coverage data
local coverage_data = firmo.get_coverage_data()

-- Format and save HTML report
local html_report = reporting.format_coverage(coverage_data, "html")
reporting.write_file("./reports/coverage.html", html_report)

-- Save report directly with one call
reporting.save_coverage_report("./reports/coverage.html", coverage_data, "html")
```

### Using Auto-Save For Multiple Formats

```lua
-- Auto-save multiple report formats
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

-- Auto-save reports
local results = reporting.auto_save_reports(
  firmo.get_coverage_data(),  -- coverage data
  nil,                        -- quality data (none in this example)
  nil,                        -- test results data (none in this example)
  "./reports"                 -- output directory
)

-- Check results
for format, result in pairs(results) do
  if result.success then
    print("Successfully saved " .. format .. " report to " .. result.path)
  else
    print("Failed to save " .. format .. " report: " .. result.error.message)
  end
end
```

### Test Results Reporting

```lua
-- Generate test results reports
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Run tests
firmo.run_discovered('./tests')

-- Get test results
local results_data = firmo.get_test_results()

-- Generate and save JUnit XML report
local junit_report = reporting.format_results(results_data, "junit")
reporting.write_file("./reports/test-results.xml", junit_report)

-- Also generate TAP and CSV formats
local tap_report = reporting.format_results(results_data, "tap")
local csv_report = reporting.format_results(results_data, "csv")

reporting.write_file("./reports/test-results.tap", tap_report)
reporting.write_file("./reports/test-results.csv", csv_report)
```

### Combined Coverage and Quality Reporting

```lua
-- Generate both coverage and quality reports
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Enable coverage and quality validation
firmo.coverage_options.enabled = true
firmo.quality_options.enabled = true
firmo.quality_options.level = 3  -- Comprehensive quality level

-- Run tests
firmo.run_discovered('./tests')

-- Get data
local coverage_data = firmo.get_coverage_data()
local quality_data = firmo.get_quality_data()

-- Auto-save all reports
reporting.auto_save_reports(coverage_data, quality_data, nil, {
  report_dir = "./reports",
  report_suffix = "-complete"
})
```

## Advanced Examples

### Custom Report Templates

```lua
-- Using path templates for report organization
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Run tests with coverage and quality validation
firmo.coverage_options.enabled = true
firmo.quality_options.enabled = true
firmo.run_discovered('./tests')

-- Get all data
local coverage_data = firmo.get_coverage_data()
local quality_data = firmo.get_quality_data()
local results_data = firmo.get_test_results()

-- Save with custom templates
reporting.auto_save_reports(
  coverage_data,
  quality_data,
  results_data,
  {
    report_dir = "./reports",
    report_suffix = "-v1.0",
    coverage_path_template = "coverage/{date}/coverage.{format}",
    quality_path_template = "quality/{date}/quality.{format}",
    results_path_template = "results/{datetime}/results.{format}",
    timestamp_format = "%Y-%m-%d",
    verbose = true
  }
)
```

### Custom Formatter Registration

```lua
-- Creating and registering a custom CSV formatter
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Register a custom CSV formatter for coverage data
reporting.register_coverage_formatter("simple-csv", function(coverage_data)
  local output = "File,Lines,Covered,Coverage %\n"
  
  -- Add a row for each file
  for path, file_data in pairs(coverage_data.files) do
    local coverage_pct = 0
    if file_data.executable_lines > 0 then
      coverage_pct = (file_data.covered_lines / file_data.executable_lines) * 100
    end
    
    -- Format as CSV row
    output = output .. string.format(
      "%s,%d,%d,%.2f\n",
      path,
      file_data.executable_lines,
      file_data.covered_lines,
      coverage_pct
    )
  end
  
  -- Add summary row
  local total_pct = 0
  if coverage_data.summary.total_lines > 0 then
    total_pct = (coverage_data.summary.covered_lines / coverage_data.summary.total_lines) * 100
  end
  
  output = output .. string.format(
    "TOTAL,%d,%d,%.2f\n",
    coverage_data.summary.total_lines,
    coverage_data.summary.covered_lines,
    total_pct
  )
  
  return output
end)

-- Use the custom formatter
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

local csv_report = reporting.format_coverage(firmo.get_coverage_data(), "simple-csv")
reporting.write_file("./reports/coverage-simple.csv", csv_report)
```

### Markdown Report Formatter

```lua
-- Custom Markdown formatter for coverage reports
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Register a Markdown formatter
reporting.register_coverage_formatter("markdown", function(coverage_data)
  local md = "# Coverage Report\n\n"
  md = md .. "## Summary\n\n"
  
  -- Add summary table
  md = md .. "| Metric | Value |\n"
  md = md .. "|--------|------|\n"
  md = md .. string.format("| Files | %d |\n", coverage_data.summary.total_files)
  md = md .. string.format("| Lines | %d |\n", coverage_data.summary.total_lines)
  md = md .. string.format("| Covered Lines | %d |\n", coverage_data.summary.covered_lines)
  
  local total_pct = 0
  if coverage_data.summary.total_lines > 0 then
    total_pct = (coverage_data.summary.covered_lines / coverage_data.summary.total_lines) * 100
  end
  md = md .. string.format("| Coverage | %.2f%% |\n", total_pct)
  
  -- Add file details section
  md = md .. "\n## Files\n\n"
  md = md .. "| File | Lines | Covered | Coverage |\n"
  md = md .. "|------|-------|---------|----------|\n"
  
  -- Sort files by path
  local sorted_files = {}
  for path in pairs(coverage_data.files) do
    table.insert(sorted_files, path)
  end
  table.sort(sorted_files)
  
  -- Add a row for each file
  for _, path in ipairs(sorted_files) do
    local file_data = coverage_data.files[path]
    local coverage_pct = 0
    if file_data.executable_lines > 0 then
      coverage_pct = (file_data.covered_lines / file_data.executable_lines) * 100
    end
    
    md = md .. string.format(
      "| `%s` | %d | %d | %.2f%% |\n",
      path,
      file_data.executable_lines,
      file_data.covered_lines,
      coverage_pct
    )
  end
  
  -- Add footer
  md = md .. "\n*Generated on " .. os.date() .. "*\n"
  
  return md
end)

-- Use the Markdown formatter
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

local md_report = reporting.format_coverage(firmo.get_coverage_data(), "markdown")
reporting.write_file("./reports/coverage.md", md_report)
```

### Custom HTML Report Theme

```lua
-- Creating a custom HTML report theme
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Configure the HTML formatter with custom theme options
reporting.configure_formatter("html", {
  theme = "light",                   -- Use light theme as base
  show_line_numbers = true,          -- Show line numbers 
  collapsible_sections = true,       -- Enable collapsible sections
  highlight_syntax = true,           -- Enable syntax highlighting
  include_legend = true,             -- Include legend section
  custom_css = [[
    /* Custom CSS to override the default theme */
    :root {
      --high-color: #28a745;        /* Green for high coverage */
      --medium-color: #ffc107;      /* Yellow for medium coverage */
      --low-color: #dc3545;         /* Red for low coverage */
      
      /* Light theme customization */
      --bg-color-light: #f8f9fa;
      --header-bg-light: #e9ecef;
      --card-bg-light: #ffffff;
    }
    
    /* Custom header */
    header {
      padding: 20px 0;
      margin-bottom: 30px;
      background: linear-gradient(135deg, var(--header-bg-light), #d6dee5);
    }
    
    /* Custom file headers */
    .file-header {
      border-radius: 4px 4px 0 0;
      background: linear-gradient(90deg, var(--stat-box-bg-light), #e9ecef);
    }
  ]]
})

-- Generate a report with the custom theme
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

reporting.save_coverage_report(
  "./reports/custom-theme-report.html", 
  firmo.get_coverage_data(), 
  "html"
)
```

### Report Validation

```lua
-- Validating coverage data before reporting
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

-- Get coverage data
local coverage_data = firmo.get_coverage_data()

-- Validate the coverage data
local is_valid, issues = reporting.validate_coverage_data(coverage_data)

if not is_valid then
  print("Coverage data validation failed:")
  for _, issue in ipairs(issues) do
    print(" - " .. issue.message)
  end
else
  -- Generate and save reports only if data is valid
  local html_report = reporting.format_coverage(coverage_data, "html")
  
  -- Validate the HTML output
  local format_valid, error_message = reporting.validate_report_format(html_report, "html")
  
  if format_valid then
    reporting.write_file("./reports/validated-coverage.html", html_report)
    print("Valid report saved successfully")
  else
    print("HTML validation failed: " .. error_message)
  end
end
```

### Automated CI Report Generation

```lua
-- Example CI reporting script
local firmo = require('firmo')
local reporting = require('lib.reporting')
local fs = require('lib.tools.filesystem')

-- Create build info for reports
local build_info = {
  build_id = os.getenv("CI_BUILD_ID") or "local",
  timestamp = os.date("%Y-%m-%d %H:%M:%S"),
  branch = os.getenv("CI_BRANCH") or "unknown",
  commit = os.getenv("CI_COMMIT") or "unknown"
}

-- Configure reporting with build info
reporting.configure({
  report_dir = "./ci-reports",
  report_suffix = "-" .. build_info.build_id
})

-- Run tests with coverage
firmo.coverage_options = {
  enabled = true,
  include = os.getenv("COVERAGE_INCLUDE") and os.getenv("COVERAGE_INCLUDE"):split(",") or nil,
  exclude = os.getenv("COVERAGE_EXCLUDE") and os.getenv("COVERAGE_EXCLUDE"):split(",") or nil,
  threshold = tonumber(os.getenv("COVERAGE_THRESHOLD") or "80")
}

-- Setup quality validation
firmo.quality_options = {
  enabled = true,
  level = tonumber(os.getenv("QUALITY_LEVEL") or "3")
}

-- Run all discovered tests
local success = firmo.run_discovered(os.getenv("TEST_DIR") or "./tests")

-- Generate all reports
local report_results = reporting.auto_save_reports(
  firmo.get_coverage_data(), 
  firmo.get_quality_data(),
  firmo.get_test_results(),
  {
    report_dir = "./ci-reports/" .. build_info.build_id,
    verbose = true,
    validate = true,
    coverage_path_template = "coverage/coverage-report.{format}",
    quality_path_template = "quality/quality-report.{format}",
    results_path_template = "results/test-results.{format}"
  }
)

-- Generate summary file for CI
local summary = {
  build_info = build_info,
  test_result = success,
  reports = {}
}

-- Add reports to summary
for format, result in pairs(report_results) do
  summary.reports[format] = {
    success = result.success,
    path = result.path,
    error = result.error and result.error.message or nil
  }
end

-- Save summary as JSON
reporting.write_file(
  "./ci-reports/" .. build_info.build_id .. "/summary.json", 
  require('lib.tools.json').encode(summary, {pretty = true})
)

-- Exit with appropriate code for CI
os.exit(success and 0 or 1)
```

### Creating a Report Dashboard

```lua
-- Generate a dashboard HTML file linking to all reports
local firmo = require('firmo')
local reporting = require('lib.reporting')
local fs = require('lib.tools.filesystem')

-- Run tests with all reporting enabled
firmo.coverage_options.enabled = true
firmo.quality_options.enabled = true
firmo.quality_options.level = 3

-- Generate test data
firmo.run_discovered('./tests')

-- Save all reports
local results = reporting.auto_save_reports(
  firmo.get_coverage_data(),
  firmo.get_quality_data(),
  firmo.get_test_results(),
  "./reports"
)

-- Create dashboard HTML
local dashboard_html = [[
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Test Report Dashboard</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      line-height: 1.5;
      max-width: 800px;
      margin: 0 auto;
      padding: 20px;
      color: #333;
    }
    h1 { color: #2c3e50; }
    .card {
      border: 1px solid #e1e1e1;
      border-radius: 4px;
      padding: 15px;
      margin-bottom: 20px;
      background-color: #fff;
    }
    .success { color: green; }
    .error { color: red; }
    a { color: #3498db; }
    table {
      width: 100%;
      border-collapse: collapse;
    }
    td, th {
      padding: 8px;
      border-bottom: 1px solid #e1e1e1;
      text-align: left;
    }
  </style>
</head>
<body>
  <h1>Test Report Dashboard</h1>
  <div class="card">
    <h2>Generated on ]] .. os.date("%Y-%m-%d %H:%M:%S") .. [[</h2>
    <p>Find all test reports below</p>
  </div>
  
  <div class="card">
    <h2>Coverage Reports</h2>
    <table>
      <tr>
        <th>Format</th>
        <th>Status</th>
        <th>Location</th>
      </tr>
]]

-- Add coverage report links
for format, result in pairs(results) do
  if format:match("^html$") or format:match("^json$") or format:match("^lcov$") or format:match("^cobertura$") then
    local status = result.success and '<span class="success">Success</span>' or '<span class="error">Failed</span>'
    local location = result.success and '<a href="' .. result.path .. '">View Report</a>' or "Not available"
    
    dashboard_html = dashboard_html .. [[
      <tr>
        <td>]] .. format .. [[</td>
        <td>]] .. status .. [[</td>
        <td>]] .. location .. [[</td>
      </tr>]]
  end
end

dashboard_html = dashboard_html .. [[
    </table>
  </div>
  
  <div class="card">
    <h2>Quality Reports</h2>
    <table>
      <tr>
        <th>Format</th>
        <th>Status</th>
        <th>Location</th>
      </tr>
]]

-- Add quality report links
for format, result in pairs(results) do
  if format:match("^quality_") then
    local status = result.success and '<span class="success">Success</span>' or '<span class="error">Failed</span>'
    local location = result.success and '<a href="' .. result.path .. '">View Report</a>' or "Not available"
    local format_name = format:gsub("^quality_", "")
    
    dashboard_html = dashboard_html .. [[
      <tr>
        <td>]] .. format_name .. [[</td>
        <td>]] .. status .. [[</td>
        <td>]] .. location .. [[</td>
      </tr>]]
  end
end

dashboard_html = dashboard_html .. [[
    </table>
  </div>
  
  <div class="card">
    <h2>Test Results</h2>
    <table>
      <tr>
        <th>Format</th>
        <th>Status</th>
        <th>Location</th>
      </tr>
]]

-- Add test results links
for format, result in pairs(results) do
  if format:match("^junit$") or format:match("^tap$") or format:match("^csv$") then
    local status = result.success and '<span class="success">Success</span>' or '<span class="error">Failed</span>'
    local location = result.success and '<a href="' .. result.path .. '">View Report</a>' or "Not available"
    
    dashboard_html = dashboard_html .. [[
      <tr>
        <td>]] .. format .. [[</td>
        <td>]] .. status .. [[</td>
        <td>]] .. location .. [[</td>
      </tr>]]
  end
end

dashboard_html = dashboard_html .. [[
    </table>
  </div>
</body>
</html>
]]

-- Write dashboard file
reporting.write_file("./reports/dashboard.html", dashboard_html)
print("Dashboard generated: ./reports/dashboard.html")
```

## Command Line Examples

### Basic Command Line Usage

```bash
# Run tests with coverage and generate HTML report
lua test.lua --coverage --format=html tests/

# Run tests with coverage and generate multiple formats
lua test.lua --coverage --format=html,json,lcov tests/

# Run tests with quality validation and coverage
lua test.lua --coverage --quality --quality-level=3 tests/

# Set custom output directory
lua test.lua --coverage --output-dir=./reports tests/

# Add timestamp to report filenames
lua test.lua --coverage --report-suffix="-$(date +%Y%m%d)" tests/
```

### Advanced Command Line Usage

```bash
# Run specific tests with coverage and validation
lua test.lua --coverage --quality --pattern="api" tests/

# Run with custom thresholds
lua test.lua --coverage --coverage-threshold=90 --quality --quality-threshold=85 tests/

# Include and exclude specific files from coverage
lua test.lua --coverage --coverage-include="src/*.lua,lib/*.lua" --coverage-exclude="vendor/*" tests/

# Generate only JSON reports
lua test.lua --coverage --format=json --quality --quality-format=json tests/

# Enable verbose output
lua test.lua --coverage --verbose-reports tests/

# Use custom path templates
lua test.lua --coverage --coverage-path="coverage/report-{date}.{format}" tests/
```

## Advanced Integration Examples

### Integrating with CI Systems

```bash
#!/bin/bash
# Example CI script for GitHub Actions

# Set up environment
LUA_VERSION="5.3"
PROJECT_ROOT="$(pwd)"
REPORT_DIR="${PROJECT_ROOT}/ci-reports"
BUILD_ID="${GITHUB_RUN_ID:-local}-${GITHUB_RUN_NUMBER:-0}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Install dependencies if needed
luarocks install luacov
luarocks install dkjson

# Run tests with coverage
echo "Running tests with coverage..."
lua test.lua --coverage \
  --format=html,json,lcov,cobertura \
  --output-dir="${REPORT_DIR}/${BUILD_ID}" \
  --coverage-threshold=85 \
  --report-suffix="-${TIMESTAMP}" \
  tests/

# Check exit code
if [ $? -ne 0 ]; then
  echo "Tests failed or coverage below threshold"
  exit 1
fi

# Upload coverage to Codecov
echo "Uploading coverage to Codecov..."
curl -s https://codecov.io/bash | bash -s -- \
  -f "${REPORT_DIR}/${BUILD_ID}/coverage-report-${TIMESTAMP}.lcov" \
  -t "${CODECOV_TOKEN}"

# Generate HTML report URL for GitHub Actions summary
echo "::set-output name=coverage_report::${REPORT_URL}/coverage-report-${TIMESTAMP}.html"

echo "Test run complete!"
exit 0
```

### Generating a Coverage Badge

```lua
-- Generate a coverage badge for README
local firmo = require('firmo')
local reporting = require('lib.reporting')

-- Run tests with coverage
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

-- Get coverage data
local coverage_data = firmo.get_coverage_data()

-- Calculate overall coverage percentage
local coverage_pct = 0
if coverage_data.summary.total_lines > 0 then
  coverage_pct = (coverage_data.summary.covered_lines / coverage_data.summary.total_lines) * 100
end
coverage_pct = math.floor(coverage_pct + 0.5)  -- Round to nearest integer

-- Determine badge color based on coverage
local color
if coverage_pct >= 90 then
  color = "brightgreen"
elseif coverage_pct >= 75 then
  color = "green"
elseif coverage_pct >= 50 then
  color = "yellow"
elseif coverage_pct >= 25 then
  color = "orange"
else
  color = "red"
end

-- Generate badge URL (for shields.io)
local badge_url = string.format(
  "https://img.shields.io/badge/coverage-%d%%25-%s",
  coverage_pct,
  color
)

-- Generate badge markdown
local badge_md = string.format(
  "![Coverage](%s)",
  badge_url
)

-- Print results
print("Coverage: " .. coverage_pct .. "%")
print("Badge URL: " .. badge_url)
print("Badge Markdown: " .. badge_md)

-- Save badge info to file
reporting.write_file("./reports/badge.json", [[{
  "schemaVersion": 1,
  "label": "coverage",
  "message": "]] .. coverage_pct .. [[%",
  "color": "]] .. color .. [["
}]])

print("Badge JSON saved to ./reports/badge.json")
```

### Custom Formatter: Team City Format

```lua
-- Register a TeamCity formatter for CI integration
local reporting = require('lib.reporting')

-- Register TeamCity formatter
reporting.register_coverage_formatter("teamcity", function(coverage_data)
  local output = ""
  
  -- Start message block for TeamCity
  output = output .. "##teamcity[blockOpened name='Coverage Summary']\n"
  
  -- Overall statistics
  local line_coverage = 0
  if coverage_data.summary.total_lines > 0 then
    line_coverage = (coverage_data.summary.covered_lines / coverage_data.summary.total_lines) * 100
  end
  
  -- TeamCity statistic values
  output = output .. string.format(
    "##teamcity[buildStatisticValue key='CoverageTotal' value='%.2f']\n",
    line_coverage
  )
  
  output = output .. string.format(
    "##teamcity[buildStatisticValue key='CoveredLines' value='%d']\n",
    coverage_data.summary.covered_lines
  )
  
  output = output .. string.format(
    "##teamcity[buildStatisticValue key='TotalLines' value='%d']\n",
    coverage_data.summary.total_lines
  )
  
  -- Add file-specific statistics
  for path, file_data in pairs(coverage_data.files) do
    local file_coverage = 0
    if file_data.executable_lines > 0 then
      file_coverage = (file_data.covered_lines / file_data.executable_lines) * 100
    end
    
    -- Escape special characters for TeamCity
    local escaped_path = path:gsub("'", "|'")
                             :gsub("\n", "|n")
                             :gsub("\r", "|r")
                             :gsub("\\", "|\\")
                             :gsub("]", "|]")
    
    output = output .. string.format(
      "##teamcity[buildStatisticValue key='Coverage-%s' value='%.2f']\n",
      escaped_path,
      file_coverage
    )
  end
  
  -- Close message block
  output = output .. "##teamcity[blockClosed name='Coverage Summary']\n"
  
  return output
end)

-- Use the TeamCity formatter
local firmo = require('firmo')
firmo.coverage_options.enabled = true
firmo.run_discovered('./tests')

local tc_report = reporting.format_coverage(firmo.get_coverage_data(), "teamcity")
reporting.write_file("./reports/teamcity-coverage.txt", tc_report)
```

## See Also

- [Reporting Module API](../docs/api/reporting.md) - Complete technical API reference
- [Reporting Module Guide](../docs/guides/reporting.md) - General usage guide with best practices