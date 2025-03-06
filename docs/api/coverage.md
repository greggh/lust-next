# Coverage Module API

The coverage module in lust-next provides comprehensive code coverage tracking and reporting capabilities.

## Overview

The coverage module uses Lua's debug hooks to track line execution and function calls, providing detailed information about which parts of your code are being executed during tests. It supports multiple output formats and can be configured to focus on specific files or exclude certain patterns.

## Basic Usage

```lua
-- Enable coverage tracking in a test file
local lust = require('lust-next')
lust.coverage_options.enabled = true

-- Run tests with coverage tracking
lust.run_discovered('./tests')

-- Generate a coverage report
local report = lust.generate_coverage_report('html', './coverage-report.html')
```

From the command line:

```bash
# Run tests with coverage enabled
lua lust-next.lua --coverage tests/
```

## Configuration Options

The coverage module can be configured through the `lust.coverage_options` table:

```lua
lust.coverage_options = {
  enabled = true,          -- Enable coverage tracking (default: false)
  format = "html",         -- Default format for reports (html, json, lcov, summary)
  threshold = 80,          -- Minimum coverage percentage required (default: 80)
  output = "./coverage",   -- Default output location for reports
  include = {"src/*.lua"}, -- Patterns of files to include in coverage
  exclude = {"test/*.lua"} -- Patterns of files to exclude from coverage
  debug = false            -- Enable debug output (default: false)
}
```

## API Reference

### `lust.coverage_options`

Configuration table for coverage options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable coverage tracking |
| `format` | string | `"summary"` | Default format for reports (html, json, lcov, summary) |
| `threshold` | number | `80` | Minimum coverage percentage required (0-100) |
| `output` | string | `nil` | Default output location for reports |
| `include` | table | `{"*.lua"}` | Patterns of files to include in coverage |
| `exclude` | table | `{"*_test.lua", "*_spec.lua", "tests/**/*.lua"}` | Patterns to exclude |
| `debug` | boolean | `false` | Enable debug output |

### `lust.with_coverage(options, fn)`

Run a function with coverage tracking:

```lua
lust.with_coverage({
  include = {"src/*.lua"},
  exclude = {"src/vendor/*.lua"}
}, function()
  -- Run tests here
  lust.run_discovered('./tests')
end)
```

### `lust.start_coverage(options)`

Start coverage tracking with the given options:

```lua
lust.start_coverage({
  include = {"src/*.lua"},
  exclude = {"tests/*.lua"}
})

-- Run tests
lust.run_discovered('./tests')

-- Stop coverage
lust.stop_coverage()
```

### `lust.stop_coverage()`

Stop coverage tracking and finalize data collection.

### `lust.get_coverage_data()`

Get the collected coverage data as a structured table:

```lua
local coverage_data = lust.get_coverage_data()
```

### `lust.generate_coverage_report(format, output_path)`

Generate a coverage report:

```lua
-- Generate an HTML report
lust.generate_coverage_report("html", "./coverage-report.html")

-- Generate a JSON report
lust.generate_coverage_report("json", "./coverage-report.json")

-- Generate an LCOV report
lust.generate_coverage_report("lcov", "./coverage-report.lcov")

-- Generate a summary report (returns text, doesn't write to file)
local summary = lust.generate_coverage_report("summary")
```

Parameters:
- `format` (string): Output format (html, json, lcov, summary)
- `output_path` (string): Path to save the report (optional for summary format)

### `lust.coverage_meets_threshold(threshold)`

Check if coverage meets the specified threshold:

```lua
if lust.coverage_meets_threshold(80) then
  print("Coverage is good!")
else
  print("Coverage is below threshold!")
end
```

Parameters:
- `threshold` (number): Coverage percentage threshold (0-100)

## Robust Fallback Mechanisms

The coverage module includes several fallback mechanisms to ensure reliable operation:

1. **Source Tracking Fallbacks**:
   - Multiple file detection mechanisms
   - Pattern-based source file detection
   - Automatic path normalization for consistent matching

2. **Data Collection Fallbacks**:
   - Manual dataset creation when debug hooks fail
   - Comprehensive debugging output for troubleshooting
   - Automatic resolution of relative paths to absolute paths

3. **Module Loading Fallbacks**:
   - Multiple search paths for finding modules
   - Direct file loading when module resolution fails
   - Graceful degradation with partial functionality

## Pattern Matching

The coverage module supports glob-style patterns for include and exclude options:

- `*` - Matches any sequence of characters in a single path segment
- `**` - Matches any sequence of characters across multiple path segments
- `?` - Matches any single character

Examples:
- `src/*.lua` - All Lua files in the src directory
- `src/**/*.lua` - All Lua files in the src directory and subdirectories
- `src/module?.lua` - Matches module1.lua, module2.lua, etc.

## Examples

### Basic Coverage Tracking

```lua
local lust = require('lust-next')

-- Enable coverage
lust.coverage_options.enabled = true
lust.coverage_options.include = {"src/*.lua"}
lust.coverage_options.exclude = {"tests/*.lua", "vendor/*.lua"}

-- Run tests
lust.run_discovered('./tests')

-- Generate report
lust.generate_coverage_report("html", "./coverage-report.html")
```

### Custom Coverage Configuration

```lua
local lust = require('lust-next')

-- Start coverage with custom configuration
lust.start_coverage({
  include = {
    "src/core/*.lua",
    "src/utils/*.lua"
  },
  exclude = {
    "src/core/vendor/*.lua",
    "src/core/legacy/*.lua"
  },
  threshold = 90,
  debug = true
})

-- Run specific tests
lust.run_file("tests/core_tests.lua")

-- Stop coverage
lust.stop_coverage()

-- Check if coverage meets threshold
if lust.coverage_meets_threshold(90) then
  print("Meets threshold!")
else
  print("Below threshold!")
end

-- Generate reports in different formats
lust.generate_coverage_report("html", "./coverage/report.html")
lust.generate_coverage_report("json", "./coverage/report.json")
lust.generate_coverage_report("lcov", "./coverage/report.lcov")
```

### Command Line Usage

```bash
# Run tests with basic coverage
lua lust-next.lua --coverage tests/

# Specify report format
lua lust-next.lua --coverage --coverage-format html tests/

# Set custom threshold
lua lust-next.lua --coverage --coverage-threshold 90 tests/

# Specify include/exclude patterns
lua lust-next.lua --coverage --coverage-include "src/*.lua,lib/*.lua" --coverage-exclude "vendor/*" tests/

# Set custom output file
lua lust-next.lua --coverage --coverage-format html --coverage-output ./reports/coverage.html tests/

# Enable debug mode
lua lust-next.lua --coverage --debug tests/
```