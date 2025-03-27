# Coverage Examples

This document provides practical examples of using Firmo's code coverage features.

## Basic Coverage Examples

### Running Tests with Coverage

```lua
-- basic_coverage.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Define a simple calculator module to test
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then error("Cannot divide by zero") end
    return a / b
  end
}

-- Test the calculator module
describe("Calculator", function()
  it("adds two numbers", function()
    expect(calculator.add(2, 3)).to.equal(5)
  end)
  
  it("subtracts two numbers", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
  end)
  
  it("multiplies two numbers", function()
    expect(calculator.multiply(2, 3)).to.equal(6)
  end)
  
  it("divides two numbers", function()
    expect(calculator.divide(6, 2)).to.equal(3)
  end)
  
  -- Note: Missing test for division by zero case
end)
```

Run with coverage:
```bash
lua test.lua --coverage basic_coverage.lua
```

This will run the tests and generate a coverage report showing that the error path in the `divide` function is not tested.

### Generating Different Report Formats

```bash
# Generate HTML report
lua test.lua --coverage --format html basic_coverage.lua

# Generate JSON report
lua test.lua --coverage --format json basic_coverage.lua

# Generate LCOV report
lua test.lua --coverage --format lcov basic_coverage.lua
```

### Complete Test Coverage

```lua
-- complete_coverage.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Define a simple calculator module to test
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then error("Cannot divide by zero") end
    return a / b
  end
}

-- Test the calculator module with complete coverage
describe("Calculator", function()
  it("adds two numbers", function()
    expect(calculator.add(2, 3)).to.equal(5)
  end)
  
  it("subtracts two numbers", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
  end)
  
  it("multiplies two numbers", function()
    expect(calculator.multiply(2, 3)).to.equal(6)
  end)
  
  it("divides two numbers", function()
    expect(calculator.divide(6, 2)).to.equal(3)
  end)
  
  -- Adding test for division by zero case
  it("throws error when dividing by zero", function()
    expect(function() calculator.divide(5, 0) end).to.fail()
  end)
end)
```

Run with coverage:
```bash
lua test.lua --coverage complete_coverage.lua
```

This will show 100% coverage because all code paths are now tested.

## Configuration Examples

### Including and Excluding Files

```lua
-- src/core/utils.lua
local Utils = {}

function Utils.capitalize(str)
  if type(str) ~= "string" then
    return nil
  end
  return str:sub(1, 1):upper() .. str:sub(2)
end

function Utils.truncate(str, length)
  if type(str) ~= "string" then
    return nil
  end
  length = length or 10
  if #str <= length then
    return str
  end
  return str:sub(1, length) .. "..."
end

return Utils

-- src/vendor/external.lua
local External = {}

function External.doSomething()
  -- Some third-party code we don't want to track
  return true
end

return External

-- tests/utils_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local Utils = require("src.core.utils")

describe("Utils", function()
  describe("capitalize", function()
    it("capitalizes the first letter", function()
      expect(Utils.capitalize("hello")).to.equal("Hello")
    end)
    
    it("returns nil for non-strings", function()
      expect(Utils.capitalize(123)).to.equal(nil)
    end)
  end)
  
  describe("truncate", function()
    it("truncates strings longer than the limit", function()
      expect(Utils.truncate("This is a long string", 10)).to.equal("This is a ...")
    end)
    
    it("leaves short strings unchanged", function()
      expect(Utils.truncate("Short", 10)).to.equal("Short")
    end)
    
    -- Missing test for non-string input
  end)
end)
```

Run with specific include/exclude patterns:
```bash
# Include only core files, exclude vendor files
lua test.lua --coverage --include "src/core/**/*.lua" --exclude "src/vendor/**/*.lua" tests/utils_test.lua
```

### Setting Coverage Threshold

```bash
# Require at least 90% coverage
lua test.lua --coverage --threshold 90 tests/utils_test.lua
```

This will fail because the truncate function's non-string input case isn't tested.

## Advanced Coverage Examples

### Custom Coverage Configuration

```lua
-- custom_coverage_config.lua
local firmo = require("firmo")
local central_config = require("lib.core.central_config")

-- Configure coverage settings
central_config.set("coverage", {
  include = function(file_path)
    return file_path:match("^src/core/") ~= nil
  end,
  exclude = function(file_path)
    return file_path:match("^src/vendor/") ~= nil
  end,
  track_all_executed = true,
  threshold = 85,
  output_dir = "./custom-coverage-reports"
})

-- Run tests with this configuration
require("tests.utils_test")
```

Run with custom configuration:
```bash
lua test.lua --coverage custom_coverage_config.lua
```

### Programmatic Coverage Access

```lua
-- programmatic_coverage.lua
local firmo = require("firmo")
local coverage = require("lib.coverage")
local Utils = require("src.core.utils")

-- Start coverage tracking
coverage.start()

-- Run some code
Utils.capitalize("hello")
Utils.truncate("This is a test string", 8)

-- Stop coverage
coverage.stop()

-- Get coverage data
local data = coverage.get_data()

-- Display coverage information
print("Coverage Results:")
print("----------------")

for file_path, file_data in pairs(data.files) do
  print(string.format("File: %s", file_path))
  print(string.format("  Lines: %d total, %d executed, %d covered", 
    file_data.total_lines or 0,
    file_data.executed_lines or 0,
    file_data.covered_lines or 0))
  print(string.format("  Coverage: %.2f%%", file_data.percentage or 0))
  
  -- Show uncovered lines
  if file_data.uncovered_lines and #file_data.uncovered_lines > 0 then
    print("  Uncovered lines:")
    for _, line_no in ipairs(file_data.uncovered_lines) do
      print("    " .. line_no)
    end
  end
  
  print()
end

-- Check if we meet threshold
local meets_threshold = coverage.meets_threshold(80)
print("Meets 80% threshold: " .. (meets_threshold and "Yes" or "No"))
```

### Custom HTML Report

```lua
-- custom_html_report.lua
local firmo = require("firmo")
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")
local Utils = require("src.core.utils")

-- Run some code with coverage
coverage.start()
Utils.capitalize("hello")
Utils.truncate("This is a test string", 8)
coverage.stop()

-- Configure HTML formatter
reporting.configure_formatter("html", {
  theme = "dark",
  show_line_numbers = true,
  include_source = true,
  collapsible_sections = true,
  highlight_syntax = true,
  include_legend = true,
  timestamp = true,
  project_name = "My Utils Library"
})

-- Generate the report
local success, err = reporting.generate_coverage_report("html", "./custom-report.html")
if success then
  print("Custom HTML report generated successfully: ./custom-report.html")
else
  print("Failed to generate report: " .. tostring(err))
end
```

## Complex Examples

### Measuring Test Suite Coverage

```lua
-- test_suite_coverage.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local central_config = require("lib.core.central_config")
local coverage = require("lib.coverage")

-- String utility module
local StringUtils = {}

function StringUtils.trim(str)
  if type(str) ~= "string" then return nil end
  return str:match("^%s*(.-)%s*$")
end

function StringUtils.split(str, sep)
  if type(str) ~= "string" then return {} end
  sep = sep or "%s"
  local result = {}
  for part in string.gmatch(str, "[^" .. sep .. "]+") do
    table.insert(result, part)
  end
  return result
end

function StringUtils.join(tbl, sep)
  if type(tbl) ~= "table" then return "" end
  sep = sep or ""
  return table.concat(tbl, sep)
end

-- Configure coverage
central_config.set("coverage", {
  track_all_executed = true,
  threshold = 90
})

-- Start coverage
coverage.start()

-- Run tests
describe("StringUtils", function()
  describe("trim", function()
    it("removes leading and trailing whitespace", function()
      expect(StringUtils.trim("  hello  ")).to.equal("hello")
    end)
    
    it("returns nil for non-strings", function()
      expect(StringUtils.trim(123)).to.equal(nil)
    end)
  end)
  
  describe("split", function()
    it("splits string on whitespace by default", function()
      local result = StringUtils.split("hello world test")
      expect(#result).to.equal(3)
      expect(result[1]).to.equal("hello")
      expect(result[2]).to.equal("world")
      expect(result[3]).to.equal("test")
    end)
    
    it("splits string on custom separator", function()
      local result = StringUtils.split("hello,world,test", ",")
      expect(#result).to.equal(3)
      expect(result[1]).to.equal("hello")
      expect(result[2]).to.equal("world")
      expect(result[3]).to.equal("test")
    end)
    
    it("returns empty table for non-strings", function()
      local result = StringUtils.split(123)
      expect(#result).to.equal(0)
    end)
  end)
  
  -- Missing tests for join function
end)

-- Stop coverage
coverage.stop()

-- Get coverage data
local data = coverage.get_data()

-- Calculate function coverage
local functions_total = 3  -- trim, split, join
local functions_tested = 2  -- trim, split
local function_coverage = (functions_tested / functions_total) * 100

-- Display coverage stats
print("Coverage Results")
print("----------------")
print(string.format("Line coverage: %.2f%%", data.summary.line_coverage_percent or 0))
print(string.format("Function coverage: %.2f%%", function_coverage))

-- Check if we meet threshold
local threshold = central_config.get("coverage.threshold")
local meets_threshold = coverage.meets_threshold(threshold)
print(string.format("Meets %d%% threshold: %s", threshold, meets_threshold and "Yes" or "No"))
```

### Integration with CI Pipeline

```lua
-- ci_coverage.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local central_config = require("lib.core.central_config")
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")

-- Determine if running in CI
local in_ci = os.getenv("CI") == "true"

-- Configure coverage differently for CI
if in_ci then
  central_config.set("coverage", {
    include = function(file_path)
      return file_path:match("^src/") ~= nil
    end,
    exclude = function(file_path)
      return file_path:match("^src/vendor/") ~= nil
    end,
    threshold = 90,
    output_dir = "./ci-coverage-reports",
    format = "lcov"  -- Format suitable for CI coverage tools
  })
else
  central_config.set("coverage", {
    include = function(file_path)
      return file_path:match("^src/") ~= nil
    end,
    exclude = function(file_path)
      return file_path:match("^src/vendor/") ~= nil or
             file_path:match("^src/deprecated/") ~= nil
    end,
    threshold = 80,  -- Lower threshold for local development
    output_dir = "./coverage-reports",
    format = "html"  -- More readable format for local development
  })
end

-- Start coverage
coverage.start()

-- Import and run tests
require("tests.all_tests")

-- Stop coverage
coverage.stop()

-- Generate appropriate report
local format = central_config.get("coverage.format")
local output_dir = central_config.get("coverage.output_dir")
local output_file = output_dir .. "/coverage-report." .. format

local success, err = reporting.generate_coverage_report(format, output_file)
if not success then
  print("Failed to generate coverage report: " .. tostring(err))
  os.exit(1)
end

-- Check if we meet threshold
local threshold = central_config.get("coverage.threshold")
if not coverage.meets_threshold(threshold) then
  print(string.format("Coverage below required threshold of %d%%", threshold))
  os.exit(1)
else
  print("Coverage meets required threshold!")
  os.exit(0)
end
```

## Conclusion

These examples demonstrate various approaches to using Firmo's coverage features. From basic tracking to advanced configurations, coverage tools can help ensure your tests are effectively verifying your code.

Key takeaways:
1. Enable coverage with the `--coverage` flag for quick usage
2. Use include/exclude patterns to focus on specific code
3. Set thresholds to enforce coverage standards
4. Customize reports for different environments
5. Analyze both line and function coverage for complete understanding

Remember that coverage is just one metric of test quality. High coverage with weak assertions won't catch all bugs, so combine coverage analysis with thorough test design for the best results.