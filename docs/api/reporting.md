
# Reporting Module API

The reporting module in lust-next provides a centralized system for generating and saving reports from test data.

## Overview

The reporting module handles report formatting and file operations, providing a clean separation of concerns between data collection and output generation. It supports multiple output formats, robust file operations, and fallback mechanisms to ensure reliable report generation.

## Basic Usage

```lua
local lust = require('lust-next')
local reporting = require('src.reporting')

-- Get coverage data
local coverage_data = lust.get_coverage_data()

-- Format coverage data as HTML
local html_report = reporting.format_coverage(coverage_data, "html")

-- Save the report to a file
reporting.write_file("./coverage-report.html", html_report)

-- Or use the auto-save function for multiple formats
reporting.auto_save_reports(coverage_data, nil, "./reports")

```text

## Configuration

The reporting module doesn't require explicit configuration, as it receives its configuration from the modules that call it.

## API Reference

### Report Formatting Functions

#### `reporting.format_coverage(coverage_data, format)`

Format coverage data into the specified output format:

```lua
local coverage_data = lust.get_coverage_data()
local html_report = reporting.format_coverage(coverage_data, "html")

```text

Parameters:

- `coverage_data` (table): Coverage data structure from the coverage module
- `format` (string): Output format (html, json, lcov, summary)

Returns:

- The formatted report content (string)

#### `reporting.format_quality(quality_data, format)`

Format quality data into the specified output format:

```lua
local quality_data = lust.get_quality_data()
local html_report = reporting.format_quality(quality_data, "html")

```text

Parameters:

- `quality_data` (table): Quality data structure from the quality module
- `format` (string): Output format (html, json, summary)

Returns:

- The formatted report content (string)

### File I/O Functions

#### `reporting.write_file(file_path, content)`

Write content to a file, creating directories as needed:

```lua
reporting.write_file("./reports/coverage-report.html", html_report)

```text

Parameters:

- `file_path` (string): Path to the file to write
- `content` (string): Content to write to the file

Returns:

- `success` (boolean): True if the file was written successfully
- `error` (string, optional): Error message if the operation failed

#### `reporting.save_coverage_report(file_path, coverage_data, format)`

Format and save a coverage report:

```lua
local coverage_data = lust.get_coverage_data()
reporting.save_coverage_report("./coverage-report.html", coverage_data, "html")

```text

Parameters:

- `file_path` (string): Path to save the report
- `coverage_data` (table): Coverage data structure
- `format` (string): Output format (html, json, lcov, summary)

Returns:

- `success` (boolean): True if the report was saved successfully
- `error` (string, optional): Error message if the operation failed

#### `reporting.save_quality_report(file_path, quality_data, format)`

Format and save a quality report:

```lua
local quality_data = lust.get_quality_data()
reporting.save_quality_report("./quality-report.html", quality_data, "html")

```text

Parameters:

- `file_path` (string): Path to save the report
- `quality_data` (table): Quality data structure
- `format` (string): Output format (html, json, summary)

Returns:

- `success` (boolean): True if the report was saved successfully
- `error` (string, optional): Error message if the operation failed

#### `reporting.auto_save_reports(coverage_data, quality_data, base_dir)`

Automatically save multiple report formats to a directory:

```lua
-- Save coverage reports (HTML, JSON, LCOV)
reporting.auto_save_reports(coverage_data, nil, "./reports")

-- Save both coverage and quality reports
reporting.auto_save_reports(coverage_data, quality_data, "./reports")

```text

Parameters:

- `coverage_data` (table, optional): Coverage data structure
- `quality_data` (table, optional): Quality data structure
- `base_dir` (string): Base directory to save reports (default: ./coverage-reports)

Returns:

- `results` (table): Table of results for each saved report with success/error information

## Robust Fallback Mechanisms

The reporting module includes several fallback mechanisms to ensure reliable operation:

### Directory Creation

The module employs multiple approaches to ensure directories exist:

```lua
-- First attempt with Lua's standard functions
local success, err = ensure_directory(path)

if not success then
  -- Fallback with direct operating system command
  os.execute('mkdir -p "' .. path .. '"')

  -- Verify creation
  local test_cmd = 'test -d "' .. path .. '"'
  local exists = os.execute(test_cmd)
end

```text

### Input Validation

The module validates input data and provides defaults:

```lua
-- Check if coverage data is valid
if not coverage_data then
  coverage_data = {
    files = {},
    summary = {
      total_files = 0,
      covered_files = 0,
      -- ...other defaults
    }
  }
end

```text

### File Writing

The module uses protected calls for file writing:

```lua
-- Use pcall for reliable error handling
local write_ok, write_err = pcall(function()
  file:write(content)
  file:close()
end)

if not write_ok then
  return false, "Error writing to file: " .. tostring(write_err)
end

```text

## Report Formats

### Coverage Report Formats

- **HTML**: Visual reports with color-coded coverage information
- **JSON**: Machine-readable format for CI integration
- **LCOV**: Industry-standard format for coverage tools
- **Summary**: Text-based overview of results

### Quality Report Formats

- **HTML**: Visual quality assessment with detailed analysis
- **JSON**: Machine-readable format for CI integration
- **Summary**: Text-based quality evaluation

## Examples

### Coverage Report Generation

```lua
local lust = require('lust-next')
local reporting = require('src.reporting')

-- Run tests with coverage
lust.coverage_options.enabled = true
lust.run_discovered('./tests')

-- Get coverage data
local coverage_data = lust.get_coverage_data()

-- Generate different report formats
local html_report = reporting.format_coverage(coverage_data, "html")
local json_report = reporting.format_coverage(coverage_data, "json")
local lcov_report = reporting.format_coverage(coverage_data, "lcov")
local summary_report = reporting.format_coverage(coverage_data, "summary")

-- Save reports to files
reporting.write_file("./reports/coverage.html", html_report)
reporting.write_file("./reports/coverage.json", json_report)
reporting.write_file("./reports/coverage.lcov", lcov_report)

-- Or use the auto-save function for all formats
reporting.auto_save_reports(coverage_data, nil, "./reports")

```text

### Combined Coverage and Quality Reporting

```lua
local lust = require('lust-next')
local reporting = require('src.reporting')

-- Enable both coverage and quality
lust.coverage_options.enabled = true
lust.quality_options.enabled = true
lust.quality_options.level = 3

-- Run tests
lust.run_discovered('./tests')

-- Get both data sets
local coverage_data = lust.get_coverage_data()
local quality_data = lust.get_quality_data()

-- Save all reports
reporting.auto_save_reports(coverage_data, quality_data, "./reports")

```text

### Custom Report Directory Structure

```lua
local lust = require('lust-next')
local reporting = require('src.reporting')

-- Run tests with coverage
lust.coverage_options.enabled = true
lust.run_discovered('./tests')

-- Get coverage data
local coverage_data = lust.get_coverage_data()

-- Create custom directory structure
reporting.write_file("./reports/coverage/html/index.html", 
                    reporting.format_coverage(coverage_data, "html"))
reporting.write_file("./reports/coverage/json/data.json", 
                    reporting.format_coverage(coverage_data, "json"))
reporting.write_file("./reports/coverage/lcov/coverage.lcov", 
                    reporting.format_coverage(coverage_data, "lcov"))

```text

