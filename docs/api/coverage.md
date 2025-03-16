# Coverage Module API
The coverage module in firmo provides comprehensive code coverage tracking and reporting capabilities.

## Overview
The coverage module uses Lua's debug hooks to track line execution and function calls, providing detailed information about which parts of your code are being executed during tests. It supports multiple output formats and can be configured to focus on specific files or exclude certain patterns.

## Basic Usage

```lua
-- Enable coverage tracking in a test file
local firmo = require('firmo')
firmo.coverage_options.enabled = true
-- Run tests with coverage tracking
firmo.run_discovered('./tests')
-- Generate a coverage report
local report = firmo.generate_coverage_report('html', './coverage-report.html')

```
From the command line:

```bash

# Run tests with coverage enabled
lua firmo.lua --coverage tests/

```

## Configuration Options
The coverage module can be configured through the `firmo.coverage_options` table:

```lua
firmo.coverage_options = {
  enabled = true,                         -- Enable coverage tracking (default: false)
  source_dirs = {".", "src", "lib"},      -- Directories to scan for source files
  use_default_patterns = true,            -- Whether to use default include/exclude patterns
  discover_uncovered = true,              -- Discover files not executed by tests
  format = "html",                        -- Default format for reports (html, json, lcov, summary)
  threshold = 80,                         -- Minimum coverage percentage required (default: 80)
  output = "./coverage",                  -- Default output location for reports
  include = {"src/**/*.lua", "lib/**/*.lua"}, -- Patterns of files to include in coverage
  exclude = {"tests/**/*.lua"},           -- Patterns of files to exclude from coverage
  debug = false                           -- Enable debug output (default: false)
}

```

## API Reference

### `firmo.coverage_options`
Configuration table for coverage options:
| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | boolean | `false` | Enable coverage tracking |
| `source_dirs` | table | `{".", "src", "lib"}` | Directories to scan for source files |
| `use_default_patterns` | boolean | `true` | Whether to use default include/exclude patterns |
| `discover_uncovered` | boolean | `true` | Discover files not executed by tests |
| `format` | string | `"summary"` | Default format for reports (html, json, lcov, summary) |
| `threshold` | number | `90` | Minimum coverage percentage required (0-100) |
| `output` | string | `nil` | Default output location for reports |
| `include` | table | `{"*.lua", "**/*.lua", "src/**/*.lua", "lib/**/*.lua"}` | Patterns of files to include |
| `exclude` | table | `{"*_test.lua", "test_*.lua", "tests/**/*.lua", etc.}` | Patterns to exclude |
| `debug` | boolean | `false` | Enable debug output |
| `track_blocks` | boolean | `false` | Enable tracking of code blocks (if/else, loops) |
| `use_static_analysis` | boolean | `false` | Use static analysis for improved accuracy |
| `control_flow_keywords_executable` | boolean | `true` | Treat control flow keywords (`end`, `else`, etc.) as executable lines |

### `firmo.with_coverage(options, fn)`
Run a function with coverage tracking:

```lua
firmo.with_coverage({
  include = {"src/*.lua"},
  exclude = {"src/vendor/*.lua"}
}, function()
  -- Run tests here
  firmo.run_discovered('./tests')
end)

```

### `firmo.start_coverage(options)`
Start coverage tracking with the given options:

```lua
firmo.start_coverage({
  include = {"src/*.lua"},
  exclude = {"tests/*.lua"}
})
-- Run tests
firmo.run_discovered('./tests')
-- Stop coverage
firmo.stop_coverage()

```

### `firmo.stop_coverage()`
Stop coverage tracking and finalize data collection.

### `firmo.get_coverage_data()`
Get the collected coverage data as a structured table:

```lua
local coverage_data = firmo.get_coverage_data()

```

### `firmo.generate_coverage_report(format, output_path)`
Generate a coverage report:

```lua
-- Generate an HTML report
firmo.generate_coverage_report("html", "./coverage-report.html")
-- Generate a JSON report
firmo.generate_coverage_report("json", "./coverage-report.json")
-- Generate an LCOV report
firmo.generate_coverage_report("lcov", "./coverage-report.lcov")
-- Generate a summary report (returns text, doesn't write to file)
local summary = firmo.generate_coverage_report("summary")

```
Parameters:

- `format` (string): Output format (html, json, lcov, summary)
- `output_path` (string): Path to save the report (optional for summary format)

### `firmo.coverage_meets_threshold(threshold)`
Check if coverage meets the specified threshold:

```lua
if firmo.coverage_meets_threshold(80) then
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
1. **Data Collection Fallbacks**:
   - Manual dataset creation when debug hooks fail
   - Comprehensive debugging output for troubleshooting
   - Automatic resolution of relative paths to absolute paths
1. **Module Loading Fallbacks**:
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
local firmo = require('firmo')
-- Enable coverage
firmo.coverage_options.enabled = true
firmo.coverage_options.include = {"src/*.lua"}
firmo.coverage_options.exclude = {"tests/*.lua", "vendor/*.lua"}
-- Run tests
firmo.run_discovered('./tests')
-- Generate report
firmo.generate_coverage_report("html", "./coverage-report.html")

```

### Custom Coverage Configuration

```lua
local firmo = require('firmo')
-- Start coverage with custom configuration
firmo.start_coverage({
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
firmo.run_file("tests/core_tests.lua")
-- Stop coverage
firmo.stop_coverage()
-- Check if coverage meets threshold
if firmo.coverage_meets_threshold(90) then
  print("Meets threshold!")
else
  print("Below threshold!")
end
-- Generate reports in different formats
firmo.generate_coverage_report("html", "./coverage/report.html")
firmo.generate_coverage_report("json", "./coverage/report.json")
firmo.generate_coverage_report("lcov", "./coverage/report.lcov")

```

### Command Line Usage

```bash

# Run tests with basic coverage
lua firmo.lua --coverage tests/

# Specify report format
lua firmo.lua --coverage --coverage-format html tests/

# Set custom threshold
lua firmo.lua --coverage --coverage-threshold 90 tests/

# Specify include/exclude patterns
lua firmo.lua --coverage --coverage-include "src/*.lua,lib/*.lua" --coverage-exclude "vendor/*" tests/

# Set custom output file
lua firmo.lua --coverage --coverage-format html --coverage-output ./reports/coverage.html tests/

# Enable debug mode
lua firmo.lua --coverage --debug tests/

```

