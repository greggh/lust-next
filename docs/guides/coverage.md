# Code Coverage Guide

This guide explains how to use Firmo's code coverage features to identify which parts of your code are being exercised by your tests.

## Introduction

Code coverage is a measure of how much of your source code is executed when your tests run. It helps you:

- Identify untested code sections
- Understand test effectiveness
- Ensure critical paths are tested
- Monitor coverage trends

Firmo provides an instrumentation-based coverage system that tracks:

- Executed lines (lines that ran during tests)
- Covered lines (lines that were verified by assertions)
- Uncovered lines (lines that never executed)

## Basic Usage

### Running Tests with Coverage

The simplest way to enable coverage is through the command line:

```bash
lua test.lua --coverage tests/
```

This runs your tests with coverage tracking enabled and generates a summary report.

### Generating Coverage Reports

You can specify the report format:

```bash
# Generate HTML report
lua test.lua --coverage --format html tests/

# Generate JSON report
lua test.lua --coverage --format json tests/

# Generate LCOV report
lua test.lua --coverage --format lcov tests/
```

### Viewing Coverage Reports

After running tests with HTML coverage:

1. Open the generated file (e.g., `coverage-reports/coverage-report.html`) in a browser
2. Navigate through files to see coverage details
3. Use the color-coding to identify covered, executed, and uncovered code

## Understanding Coverage States

Firmo's coverage system distinguishes between three states:

1. **Covered Lines (Green)**: Code that is both executed AND verified by assertions
2. **Executed Lines (Orange)**: Code that executes during tests but is NOT verified by assertions
3. **Not Covered Lines (Red)**: Code that does not execute at all

This three-state model provides valuable insight beyond simple executed/not-executed tracking.

## Configuring Coverage

### Command Line Options

| Option | Description |
|--------|-------------|
| `--coverage` | Enable coverage tracking |
| `--format FORMAT` | Set report format (html, json, lcov, summary) |
| `--output-file FILE` | Specify output file for report |
| `--include PATTERNS` | Comma-separated patterns of files to include |
| `--exclude PATTERNS` | Comma-separated patterns of files to exclude |
| `--threshold PERCENT` | Minimum coverage percentage to require |

### Through Central Configuration

You can also configure coverage through the central configuration system:

```lua
local central_config = require("lib.core.central_config")

central_config.set("coverage", {
  include = function(file_path)
    return file_path:match("^src/") ~= nil
  end,
  exclude = function(file_path)
    return file_path:match("^src/vendor/") ~= nil
  end,
  track_all_executed = true,
  threshold = 80,
  output_dir = "./coverage-reports"
})
```

## Include and Exclude Patterns

Coverage tracking can be focused on specific code by including or excluding files:

### Include Patterns

Include patterns determine which files to track:

```bash
# Only track files in the src directory
lua test.lua --coverage --include "src/**/*.lua" tests/
```

### Exclude Patterns

Exclude patterns determine which files to ignore:

```bash
# Ignore vendor files
lua test.lua --coverage --exclude "src/vendor/**/*.lua" tests/
```

### Combining Patterns

You can combine include and exclude patterns:

```bash
# Track src files except for vendor files
lua test.lua --coverage --include "src/**/*.lua" --exclude "src/vendor/**/*.lua" tests/
```

## Coverage Thresholds

Set minimum coverage requirements:

```bash
# Require at least 80% coverage
lua test.lua --coverage --threshold 80 tests/
```

When a threshold is set, the test run will fail if coverage falls below that percentage.

## Integrating with CI Systems

Coverage reports can be integrated into CI workflows:

```yaml
# GitHub Actions example
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Run tests with coverage
        run: lua test.lua --coverage --format lcov tests/
      - name: Upload coverage report
        uses: coverallsapp/github-action@v1
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          path-to-lcov: ./coverage-reports/coverage-report.lcov
```

## Best Practices

### Coverage Goals

1. **Start with achievable goals**: Begin with a modest target (e.g., 70%)
2. **Increase coverage gradually**: Incrementally raise your threshold as coverage improves
3. **Focus on critical code**: Prioritize coverage of core functionality and error-prone code

### Test Quality

1. **Coverage isn't everything**: High coverage with weak assertions can miss bugs
2. **Assertions matter**: Use `expect` assertions to actually verify results
3. **Combine with quality metrics**: Use Firmo's `--quality` flag alongside coverage

### File Organization

1. **Group related code**: Group related functionality to make coverage patterns easier
2. **Consistent file locations**: Use consistent directory structures
3. **Separate test utilities**: Put test helpers outside of core code to avoid skewing metrics

## Advanced Usage

### Programmatic Access

You can access coverage data programmatically:

```lua
local central_config = require("lib.core.central_config")
local coverage = require("lib.coverage")

-- Configure coverage
central_config.set("coverage.include", function(file_path)
  return file_path:match("^src/") ~= nil
end)

-- Start coverage
coverage.start()

-- Run your code/tests here
-- ...

-- Stop coverage and get data
coverage.stop()
local data = coverage.get_data()

-- Process coverage data
for file_path, file_data in pairs(data.files) do
  print(string.format("File: %s - %.2f%% covered", 
    file_path, file_data.percentage or 0))
end
```

### Custom Reporting

You can create custom coverage reports:

```lua
local coverage = require("lib.coverage")
local reporting = require("lib.reporting")

-- Customize HTML report options
reporting.configure_formatter("html", {
  theme = "dark",
  show_line_numbers = true,
  include_source = true,
  collapsible_sections = true
})

-- Generate the report
reporting.generate_coverage_report("html", "./coverage-reports/custom-report.html")
```

### Advanced Configuration

For detailed configuration of specific reporting components, see:

- [Coverage Report Formatters](./configuration-details/formatters.md) - Comprehensive documentation of all formatter options
- [Report Validation Configuration](./configuration-details/report_validation.md) - Ensure accuracy of coverage reports
- [File Watcher Configuration](./configuration-details/watcher.md) - Configure continuous testing with file watching

## Troubleshooting

### Low Coverage Issues

If you have unexpectedly low coverage:

1. **Check include/exclude patterns**: Ensure your patterns match the expected files
2. **Verify assertions**: Make sure your tests include assertions that verify results
3. **Look for dead code**: Unreachable code won't be covered no matter what
4. **Check test execution**: Ensure all your tests are actually running

### Report Problems

If your coverage reports don't look right:

1. **Check file paths**: Ensure paths are consistent between coverage tracking and report generation
2. **Verify central configuration**: Check your central_config settings
3. **Look for conflicts**: Other tools or instrumentation might interfere with coverage tracking

## Understanding Report Data

### HTML Report Structure

The HTML report contains:

1. **Summary page**: Overall statistics and file listing
2. **File views**: Line-by-line coverage visualization
3. **Legend**: Color key for covered, executed, and uncovered lines
4. **Navigation**: File tree navigation

### Coverage Metrics

Important metrics in reports:

1. **Line coverage**: Percentage of lines executed
2. **Assertion coverage**: Percentage of lines verified by assertions
3. **Function coverage**: Percentage of functions executed
4. **Branch coverage**: Coverage of logical branches (if available)

## Conclusion

Firmo's coverage features provide deep insight into test effectiveness. By regularly tracking coverage and working to improve it, you can build more reliable code with fewer defects.

Remember that coverage is just one aspect of test quality. Combine it with thoughtful test design, effective assertions, and good development practices for the best results.

For practical examples, see the [coverage examples](/examples/coverage_examples.md) file.