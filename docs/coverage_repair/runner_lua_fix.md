# Fix for HTML Report Generation in runner.lua

This document details the crucial fix made to `scripts/runner.lua` to enable HTML report generation for single file tests.

## Problem

When running tests with the `--coverage` and `--format=html` flags using the test.lua interface, HTML reports would only be generated when running all tests in a directory, but not when running a single test file.

The issue was located in `scripts/runner.lua`, where report generation logic was implemented in the `run_all` function but missing from the `run_file` function. This meant that single file tests would track coverage data but never generate the final HTML report.

## Solution

The fix involved adding report generation logic to the `run_file` function in `scripts/runner.lua`. The key code addition was:

```lua
-- In the run_file function, after test execution
if options.coverage then
  local coverage = require("lib.coverage")
  
  -- Stop coverage tracking if it's still active
  logger.info("Stopping coverage tracking")
  coverage.stop()
  
  -- Generate reports
  logger.info("Generating coverage report for single file run")
  
  -- Get report data
  local report_data = coverage.get_report_data()
  
  if report_data then
    -- Get file count safely with manual counting
    local file_count = 0
    if report_data.files then
      for _ in pairs(report_data.files) do
        file_count = file_count + 1
      end
    end
    
    logger.info("Successfully got coverage report data", {
      has_summary = report_data.summary ~= nil,
      has_files = report_data.files ~= nil,
      files_count = file_count
    })
    
    -- Try to load the reporting module
    local reporting_loaded, reporting = pcall(require, "lib.reporting")
    
    if reporting_loaded and reporting then
      logger.info("Reporting module loaded, generating reports")
      
      -- Create reports directory
      local report_dir = options.report_dir or "./coverage-reports"
      fs.ensure_directory_exists(report_dir)
      
      -- Determine which formats to generate
      local formats
      if options.formats and #options.formats > 0 then
        formats = options.formats
      else
        formats = { "html", "json", "lcov", "cobertura" }
      end
      
      -- Generate reports in specified formats
      for _, format in ipairs(formats) do
        local report_path = fs.join_paths(report_dir, "coverage-report." .. format)
        logger.info("Generating report", { format = format, path = report_path })
        
        local success, err = reporting.save_coverage_report(report_path, report_data, format)
        if success then
          logger.info("Generated coverage report", { format = format, path = report_path })
        else
          logger.error("Failed to generate coverage report", { 
            format = format, 
            error = err and error_handler.format_error(err) or "Unknown error" 
          })
        end
      end
    else
      logger.error("Reporting module not available for generating reports")
    end
  else
    logger.error("Failed to get coverage report data")
  end
}
```

## Format Parameter Handling

Another key fix involved correctly processing the `--format` parameter to respect user-specified formats:

```lua
-- In the parse_arguments function
elseif arg:match("^%-%-format=(.+)$") then
  options.formats = { arg:match("^%-%-format=(.+)$") }
```

And in the report generation logic:

```lua
-- Determine which formats to generate
local formats
if options.formats and #options.formats > 0 then
  formats = options.formats
  logger.info("Using user-specified formats", { formats = table.concat(formats, ", ") })
else
  formats = { "html", "json", "lcov", "cobertura" }
  logger.info("Using default formats", { formats = "html, json, lcov, cobertura" })
end
```

## Benefits of the Fix

1. **Consistent Behavior**: Now both directory and single-file test runs generate HTML reports as expected
2. **User Control**: The `--format` flag correctly limits output to just the specified format
3. **Better Feedback**: Improved logging shows what format is being generated and the final report path
4. **Error Handling**: Proper error reporting if something goes wrong during report generation

## Testing the Fix

The fix was verified by running these commands:

```bash
# Test with a directory - should generate HTML report
env -C /home/gregg/Projects/lua-library/firmo lua test.lua --coverage --format=html examples/

# Test with a single file - should also generate HTML report
env -C /home/gregg/Projects/lua-library/firmo lua test.lua --coverage --format=html examples/comprehensive_coverage_example.lua
```

Both commands now successfully generate HTML reports in the `coverage-reports` directory.