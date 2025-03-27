# Test Runner Examples

This document provides practical examples of using firmo's test runner system in different scenarios.

> **Note**: This file contains comprehensive code examples for documentation purposes. For a simple executable demonstration, you can run the firmo test runner directly with `lua test.lua`.

## Basic Test Running Examples

### Example 1: Running a Single Test File

This example demonstrates running a single test file:

```bash
# Run a specific test file
lua test.lua tests/unit/calculator_test.lua
```

The corresponding test file might look like:

```lua
-- tests/unit/calculator_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Calculator", function()
  local calculator = require("lib.calculator")
  
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
    expect(calculator.divide(6, 3)).to.equal(2)
  end)
  
  it("returns nil when dividing by zero", function()
    expect(calculator.divide(5, 0)).to_not.exist()
  end)
end)
```

Output:
```
Running test file: tests/unit/calculator_test.lua
PASS adds two numbers
PASS subtracts two numbers
PASS multiplies two numbers
PASS divides two numbers
PASS returns nil when dividing by zero

Test Results:
- Passes:  5
- Failures: 0
- Skipped:  0
- Total:    5
All tests passed!
```

### Example 2: Running All Tests in a Directory

This example shows running all tests in a directory:

```bash
# Run all tests in the tests/unit directory
lua test.lua tests/unit
```

Output:
```
Found 5 test files in tests/unit matching *_test.lua
Running test file: tests/unit/calculator_test.lua
...
Running test file: tests/unit/string_utils_test.lua
...
(output for all 5 test files)

Test Results:
- Passes:  27
- Failures: 0
- Skipped:  3
- Total:    30
All tests passed!
```

### Example 3: Running Tests with Pattern Matching

This example demonstrates running tests that match a specific pattern:

```bash
# Run only math-related test files
lua test.lua --pattern="math_*_test.lua" tests/
```

This will run only test files whose names start with "math_" and end with "_test.lua".

Output:
```
Found 2 test files in tests/ matching math_*_test.lua
Running test file: tests/math_calculator_test.lua
...
Running test file: tests/math_statistics_test.lua
...

Test Results:
- Passes:  12
- Failures: 0
- Skipped:  1
- Total:    13
All tests passed!
```

## Watch Mode Examples

### Example 4: Basic Watch Mode

This example shows using watch mode to automatically rerun tests when code changes:

```bash
# Run tests in watch mode
lua test.lua --watch tests/unit/calculator_test.lua
```

Output:
```
Running test file: tests/unit/calculator_test.lua
...
All tests passed!

--- WATCHING FOR CHANGES ---

File changes detected:
- lib/calculator.lua

Running test file: tests/unit/calculator_test.lua
...
All tests passed!

--- WATCHING FOR CHANGES ---
```

### Example 5: Configuring Watch Mode

This example demonstrates customizing watch mode behavior:

```bash
# Custom watch mode configuration
lua test.lua --watch --watch-interval=0.5 --watch-dir=lib --watch-dir=src tests/
```

This configures watch mode to:
- Check for changes every 0.5 seconds
- Monitor both the lib and src directories for changes
- Run all tests in the tests directory when changes are detected

### Example 6: TDD Workflow with Watch Mode

This example shows a test-driven development workflow using watch mode:

1. First, write a failing test:

```lua
-- tests/unit/new_feature_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("StringUtils", function()
  local string_utils = require("lib.string_utils")
  
  it("capitalizes each word in a string", function()
    expect(string_utils.capitalize_words("hello world")).to.equal("Hello World")
  end)
end)
```

2. Start watch mode:

```bash
lua test.lua --watch tests/unit/new_feature_test.lua
```

Initial output:
```
Running test file: tests/unit/new_feature_test.lua
FAIL capitalizes each word in a string - expected "Hello World" but got nil
  string_utils.capitalize_words is not a function

Test Results:
- Passes:  0
- Failures: 1
- Skipped:  0
- Total:    1
There were test failures!

--- WATCHING FOR CHANGES ---
```

3. Implement the function in the source file:

```lua
-- lib/string_utils.lua
local string_utils = {}

-- Other functions...

function string_utils.capitalize_words(str)
  return str:gsub("(%w)(%w*)", function(first, rest)
    return first:upper() .. rest
  end)
end

return string_utils
```

4. Watch mode automatically reruns the test:

```
File changes detected:
- lib/string_utils.lua

Running test file: tests/unit/new_feature_test.lua
PASS capitalizes each word in a string

Test Results:
- Passes:  1
- Failures: 0
- Skipped:  0
- Total:    1
All tests passed!

--- WATCHING FOR CHANGES ---
```

## Coverage Examples

### Example 7: Basic Coverage Tracking

This example demonstrates basic coverage tracking:

```bash
# Run tests with coverage
lua test.lua --coverage tests/unit/calculator_test.lua
```

Output:
```
Running test file: tests/unit/calculator_test.lua
...
All tests passed!

Coverage summary:
- Overall: 92.50%
- Lines: 90.00%
- Functions: 100.00%
- Files: 87.50%
```

### Example 8: Analyzing Coverage Reports

This example shows how to analyze coverage reports:

1. Run tests with coverage and specify report directory:

```bash
lua test.lua --coverage --report-dir=coverage-reports tests/
```

2. Open the generated HTML report to view detailed coverage information:

```bash
open coverage-reports/coverage-report.html
```

The HTML report displays:
- Overall coverage statistics
- File-by-file breakdown
- Line-by-line highlighting (green for covered, orange for executed, red for not covered)
- Function coverage statistics

### Example 9: Improving Coverage Based on Reports

This example demonstrates improving test coverage based on coverage reports:

1. Identify uncovered code paths in the coverage report
2. Add tests for those paths:

```lua
-- tests/unit/calculator_test.lua
-- Add a new test for an uncovered code path
it("handles errors gracefully", function()
  -- Exercise previously untested error handling
  expect(calculator.parse_and_calculate("2 + invalid")).to_not.exist()
  expect(calculator.get_last_error()).to.match("Invalid operand")
end)
```

3. Rerun tests with coverage:

```bash
lua test.lua --coverage tests/unit/calculator_test.lua
```

4. Verify improved coverage:

```
Coverage summary:
- Overall: 96.25%
- Lines: 95.00%
- Functions: 100.00%
- Files: 93.75%
```

## Advanced Usage Examples

### Example 10: Running Tests in Parallel

This example demonstrates running tests in parallel for faster execution:

```bash
# Run tests in parallel
lua test.lua --parallel tests/
```

Output:
```
Running 12 test files in parallel...
[parallel] Running 4 batches with 3 files each
[batch 1] tests/unit/calculator_test.lua ✓
[batch 1] tests/unit/string_utils_test.lua ✓
[batch 1] tests/unit/validation_test.lua ✓
[batch 2] tests/integration/api_test.lua ✓
...

Test Results:
- Passes:  87
- Failures: 0
- Skipped:  5
- Total:    92
All tests passed!
```

### Example 11: Quality Validation

This example shows using quality validation to analyze test completeness:

```bash
# Run tests with quality validation
lua test.lua --quality --quality-level=3 tests/
```

Output:
```
Running 12 test files...
...
All tests passed!

Quality summary:
- Score: 86.75%
- Tests analyzed: 92
- Level: 3
- Level name: Comprehensive

Quality issues:
- 3 tests missing assertions
- 5 tests with insufficient assertions
- 2 modules with under 80% test coverage
```

### Example 12: Custom Test Filtering

This example demonstrates filtering tests by description:

```bash
# Run only tests containing "error handling" in their description
lua test.lua --filter="error handling" tests/
```

Output:
```
Running tests matching filter: error handling
Found 5 matching tests in 3 files
...

Test Results:
- Passes:  5
- Failures: 0
- Skipped:  0
- Total:    5
All tests passed!
```

## Integration Examples

### Example 13: CI/CD Integration

This example shows integrating the test runner with a CI/CD pipeline:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Set up Lua
        uses: leafo/gh-actions-lua@v8
        with:
          luaVersion: "5.3"
          
      - name: Install dependencies
        run: |
          luarocks install luafilesystem
          
      - name: Run tests
        run: lua test.lua --coverage --parallel tests/
        
      - name: Upload coverage reports
        uses: actions/upload-artifact@v2
        with:
          name: coverage-reports
          path: ./coverage-reports
```

### Example 14: Makefile Integration

This example demonstrates integrating the test runner with a Makefile:

```makefile
.PHONY: test test-unit test-integration test-coverage test-watch

test:
	lua test.lua tests/

test-unit:
	lua test.lua tests/unit/

test-integration:
	lua test.lua tests/integration/

test-coverage:
	lua test.lua --coverage --report-dir=coverage-reports tests/

test-watch:
	lua test.lua --watch tests/

ci-test:
	lua test.lua --coverage --parallel --report-dir=reports tests/
```

Usage:
```bash
# Run unit tests
make test-unit

# Run tests with coverage
make test-coverage
```

## Custom Runner Examples

### Example 15: Custom Test Runner Script

This example demonstrates creating a custom test runner script:

```lua
-- custom_runner.lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Parse command line arguments
local args = {...}
local options = {
  coverage = true,
  verbose = true,
  report_dir = "custom-reports"
}

-- Load configuration
local config_file = args[1] or ".test-config.lua"
local config = {}

if fs.file_exists(config_file) then
  local loaded_config = dofile(config_file)
  if type(loaded_config) == "table" then
    config = loaded_config
  end
end

-- Apply configuration
for k, v in pairs(config) do
  options[k] = v
end

-- Initialize modules
local module_reset = require("lib.core.module_reset")
module_reset.register_with_firmo(firmo)
module_reset.configure({ reset_modules = true })

-- Run tests
local test_path = args[2] or "tests/"
local success = runner.run_all(test_path, firmo, options)

-- Exit with appropriate status code
os.exit(success and 0 or 1)
```

Usage:
```bash
# Run with default configuration
lua custom_runner.lua

# Run with specific configuration file and test path
lua custom_runner.lua my-config.lua tests/unit/
```

### Example 16: Environment-specific Test Runner

This example shows creating environment-specific test runners:

```lua
-- dev_tests.lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Development environment configuration
local options = {
  coverage = true,
  watch = true,
  watch_interval = 0.5,
  report_dir = "dev-reports"
}

-- Set environment variables
os.setenv("APP_ENV", "development")
os.setenv("DB_CONNECTION", "sqlite::memory:")

-- Run tests
return runner.run_all("tests/", firmo, options)
```

```lua
-- prod_tests.lua
local firmo = require("firmo")
local runner = require("scripts.runner")

-- Production environment configuration
local options = {
  coverage = true,
  parallel = true,
  report_dir = "prod-reports"
}

-- Set environment variables
os.setenv("APP_ENV", "production")
os.setenv("DB_CONNECTION", "sqlite:test_db.sqlite")

-- Run tests
return runner.run_all("tests/", firmo, options)
```

Usage:
```bash
# Run development tests
lua dev_tests.lua

# Run production tests
lua prod_tests.lua
```

## Testing Patterns Examples

### Example 17: Test Suite Organization

This example demonstrates organizing tests in a structured hierarchy:

```
tests/
├── unit/                   # Fast, isolated unit tests
│   ├── calculator_test.lua
│   ├── string_utils_test.lua
│   └── validation_test.lua
├── integration/            # Tests that interact with external systems
│   ├── api_test.lua
│   ├── database_test.lua
│   └── file_system_test.lua
├── performance/            # Performance benchmarks
│   ├── api_benchmark_test.lua
│   └── database_benchmark_test.lua
└── fixtures/               # Test fixtures and data
    ├── test_data.lua
    └── mock_responses.lua
```

Running specific test categories:
```bash
# Run just unit tests
lua test.lua tests/unit/

# Run integration tests with coverage
lua test.lua --coverage tests/integration/

# Run performance tests with long timeout
lua test.lua --timeout=30000 tests/performance/
```

### Example 18: Test Setup and Teardown

This example shows using setup and teardown for test isolation:

```lua
-- tests/integration/database_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Database operations", function()
  local db
  local test_data = {
    { id = 1, name = "Alice" },
    { id = 2, name = "Bob" },
    { id = 3, name = "Charlie" }
  }
  
  before_each(function()
    -- Create a fresh database connection for each test
    db = firmo.reset_module("app.database")
    db.connect({in_memory = true})
    
    -- Set up test data
    for _, record in ipairs(test_data) do
      db.insert("users", record)
    end
  end)
  
  after_each(function()
    -- Clean up after each test
    db.disconnect()
  end)
  
  it("retrieves all users", function()
    local users = db.query("SELECT * FROM users")
    expect(#users).to.equal(3)
  end)
  
  it("finds a user by id", function()
    local user = db.query_one("SELECT * FROM users WHERE id = ?", 2)
    expect(user).to.exist()
    expect(user.name).to.equal("Bob")
  end)
  
  it("updates a user", function()
    db.execute("UPDATE users SET name = ? WHERE id = ?", "Robert", 2)
    local user = db.query_one("SELECT * FROM users WHERE id = ?", 2)
    expect(user.name).to.equal("Robert")
  end)
  
  it("deletes a user", function()
    db.execute("DELETE FROM users WHERE id = ?", 3)
    local count = db.query_value("SELECT COUNT(*) FROM users")
    expect(count).to.equal(2)
    
    local user = db.query_one("SELECT * FROM users WHERE id = ?", 3)
    expect(user).to_not.exist()
  end)
end)
```

### Example 19: Testing Asynchronous Code

This example demonstrates testing asynchronous code:

```lua
-- tests/async/api_client_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local await = firmo.await

describe("API Client", function()
  local api_client = require("app.api_client")
  
  it("fetches user data asynchronously", function()
    local result = await(api_client.fetch_user(1))
    expect(result).to.exist()
    expect(result.name).to.equal("John Doe")
  end)
  
  it("handles API errors gracefully", function()
    local result, err = await(api_client.fetch_user(999))
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.code).to.equal(404)
  end)
  
  it("processes multiple requests in parallel", function()
    local results = await(api_client.batch_fetch({1, 2, 3}))
    expect(#results).to.equal(3)
    expect(results[1].name).to.equal("John Doe")
    expect(results[2].name).to.equal("Jane Smith")
    expect(results[3].name).to.equal("Bob Johnson")
  end)
  
  it("caches results for subsequent calls", function()
    -- First call
    local start_time = os.time()
    local result1 = await(api_client.fetch_user(1))
    local first_duration = os.time() - start_time
    
    -- Second call (should be cached)
    start_time = os.time()
    local result2 = await(api_client.fetch_user(1))
    local second_duration = os.time() - start_time
    
    -- Verify cache works
    expect(result1).to.deep_equal(result2)
    expect(second_duration).to.be_less_than(first_duration)
  end)
end)
```

## Conclusion

These examples demonstrate the versatility and power of firmo's test runner system. From basic test execution to advanced features like parallel testing, coverage tracking, and quality validation, the test runner provides a comprehensive solution for testing Lua applications.

For more information, refer to:

- [Test Runner API Reference](../docs/api/test_runner.md): Complete technical documentation
- [Test Runner Guide](../docs/guides/test_runner.md): Practical guide for using the test runner