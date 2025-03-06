# Lust-Next API Reference

This section contains detailed API documentation for all Lust-Next functionality.

## Table of Contents

- [Core Functions](core.md) - Essential test functions (`describe`, `it`, etc.)
- [Assertions](assertions.md) - Assertion functions for test verification
- [Async Testing](async.md) - APIs for testing asynchronous code
- [Mocking](mocking.md) - Mocking, spying, and stubbing capabilities
- [Module Reset](module_reset.md) - Module management utilities for clean test state
- [Coverage](coverage.md) - Code coverage tracking and reporting
- [Quality](quality.md) - Test quality validation
- [Reporting](reporting.md) - Report generation and file operations
- [Test Filtering](filtering.md) - Test filtering and tagging support
- [CLI](cli.md) - Command-line interface and options
- [Test Discovery](discovery.md) - Automatic test discovery capabilities

## API Overview

Lust-Next provides a comprehensive API for testing Lua code. The API is designed to be simple, intuitive, and powerful.

### Core Functions

```lua
-- Define a test group
lust.describe("Group name", function()
  -- Define a test
  lust.it("Test name", function()
    -- Test code here
  end)
end)

-- Setup and teardown
lust.before(function() -- Run before each test end)
lust.after(function() -- Run after each test end)
```

### Assertions

```lua
-- Basic assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()

-- Table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.values({"a", "b"})

-- String assertions
expect(str).to.start_with("prefix")
```

### Async Testing

```lua
-- Async test
lust.it_async("Async test", function()
  local result = nil
  lust.await(100) -- Wait 100ms
  expect(result).to.exist()
end)

-- Run async operations in parallel
local results = lust.parallel_async(
  function() lust.await(100); return "first" end,
  function() lust.await(200); return "second" end
)
```

### Module Reset

```lua
-- Reset and reload a module
local fresh_module = lust.reset_module("app.module")

-- Run test with a fresh module
lust.with_fresh_module("app.module", function(mod)
  -- Test using the fresh module
end)
```

### Mocking

```lua
-- Create a mock
local mock_obj = lust.mock(dependencies)
mock_obj:stub("method", function() return "mocked" end)

-- Create a spy
local spy = lust.spy(function() end)
```

### Coverage and Quality

```lua
-- Enable coverage tracking
lust.coverage_options.enabled = true
lust.coverage_options.include = {"src/*.lua"}
lust.coverage_options.exclude = {"tests/*.lua"}

-- Run tests with coverage
lust.run_discovered("./tests")

-- Generate a coverage report
lust.generate_coverage_report("html", "./coverage-report.html")

-- Enable quality validation
lust.quality_options.enabled = true
lust.quality_options.level = 3 -- Comprehensive quality level

-- Generate a quality report
lust.generate_quality_report("html", "./quality-report.html")
```

### Reporting

```lua
-- Get the reporting module
local reporting = require("src.reporting")

-- Format and save reports
local coverage_data = lust.get_coverage_data()
local quality_data = lust.get_quality_data()

-- Auto-save all report formats
reporting.auto_save_reports(coverage_data, quality_data, "./reports")
```

See the individual sections for detailed documentation on each API area.