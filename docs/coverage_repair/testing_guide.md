# Testing Guide for firmo

## Introduction

This guide provides comprehensive information about writing and running tests for the firmo project. It covers the standardized testing approach, best practices for writing tests, and specific considerations for testing different components of the framework.

## Standardized Testing Approach

### Universal Command Interface

All tests in firmo are run through a standardized command interface using `test.lua` in the project root:

```bash
lua test.lua [options] [path]
```

Where:
- `[options]` are command-line flags like `--coverage`, `--watch`, `--pattern=coverage`
- `[path]` is a file or directory path (the system automatically detects which)

Common options include:
- `--coverage`: Enable coverage tracking
- `--quality`: Enable quality validation
- `--pattern=<pattern>`: Filter test files by pattern
- `--watch`: Enable watch mode for continuous testing
- `--verbose`: Show more detailed output
- `--help`: Show all available options

### Examples

```bash
# Run all tests
lua test.lua tests/

# Run a specific test file
lua test.lua tests/reporting/formatters/html_test.lua

# Run all tests in a directory
lua test.lua tests/coverage/

# Run tests with coverage
lua test.lua --coverage tests/

# Run tests with a specific pattern
lua test.lua --pattern=coverage tests/

# Run tests with watch mode
lua test.lua --watch tests/

# Run tests with quality validation
lua test.lua --quality tests/
```

### Using runner.lua for Development

For development and debugging of individual test files, you can use the `scripts/runner.lua` utility:

```bash
lua scripts/runner.lua [test_file_path]
```

Benefits of using runner.lua:
- Faster execution for single test files
- More focused output for debugging
- Properly isolates test state between runs
- Doesn't require full test environment setup

Example:
```bash
# Run a specific test during development
lua scripts/runner.lua tests/coverage/debug_hook_test.lua
```

### Test Directory Structure

Tests are organized in a logical directory structure by component:
```
tests/
├── core/            # Core framework tests 
├── coverage/        # Coverage-related tests
│   ├── instrumentation/  # Instrumentation-specific tests
│   └── hooks/           # Debug hook tests
├── quality/         # Quality validation tests
├── reporting/       # Reporting framework tests
│   └── formatters/      # Formatter-specific tests
├── tools/           # Utility module tests
│   ├── filesystem/      # Filesystem module tests
│   ├── logging/         # Logging system tests
│   └── watcher/         # File watcher tests
├── assertions/      # Assertion tests
├── async/           # Async functionality tests
├── mocking/         # Mocking system tests
├── parallel/        # Parallel execution tests
├── performance/     # Performance benchmark tests
├── discovery/       # Test discovery tests
├── fixtures/        # Test fixtures directory
│   └── modules/     # Module fixtures
└── integration/     # Integration tests
```

## Writing Tests

### Basic Test Structure

All test files follow this basic structure:

```lua
-- Import firmo
local firmo = require "firmo"

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test lifecycle hooks (optional)
local before, after = firmo.before, firmo.after

-- Import module to test
local module_to_test = require "path.to.module"

-- Main test suite
describe("ModuleName", function()
  -- Test cases go here
  
  it("should do something specific", function()
    -- Test implementation
    expect(module_to_test.some_function()).to.equal(expected_value)
  end)
  
  -- More test cases...
end)
```

### Test Lifecycle

Use `before` and `after` hooks for setup and teardown:

```lua
describe("Module with state", function()
  local instance
  
  before(function()
    -- Runs before each test in this describe block
    instance = module.create()
  end)
  
  after(function()
    -- Runs after each test in this describe block
    instance = nil
  end)
  
  it("should do something", function()
    -- instance is available here
    expect(instance:method()).to.equal(expected)
  end)
end)
```

### Nested Test Blocks

Group related tests using nested `describe` blocks:

```lua
describe("Calculator", function()
  local calc
  
  before(function()
    calc = calculator.new()
  end)
  
  describe("addition", function()
    it("should add positive numbers", function()
      expect(calc:add(2, 3)).to.equal(5)
    end)
    
    it("should handle negative numbers", function()
      expect(calc:add(-2, 3)).to.equal(1)
    end)
  end)
  
  describe("subtraction", function()
    it("should subtract numbers", function()
      expect(calc:subtract(5, 3)).to.equal(2)
    end)
  end)
end)
```

### Focused and Excluded Tests

Use `fit` to focus on specific tests and `xit` to exclude tests:

```lua
describe("Subsystem", function()
  -- This test will be skipped
  xit("should do something complex that's not ready", function()
    -- Skipped test
  end)
  
  -- Only this test will run if any fit() exists in the file
  fit("should do the specific thing I'm working on", function()
    -- Only this test will run
  end)
  
  -- This test would be skipped if there's a fit() in the file
  it("should do something else", function()
    -- Normal test
  end)
end)
```

### Assertion Basics

firmo uses expect-style assertions:

```lua
-- Basic assertions
expect(value).to.exist()                -- checks value is not nil
expect(actual).to.equal(expected)       -- checks equality
expect(value).to.be.a("string")         -- checks type
expect(value).to.be_truthy()            -- checks boolean truthiness
expect(string_value).to.match(pattern)  -- checks string matches pattern
expect(function_to_test).to.fail()      -- checks function throws error

-- Negated assertions
expect(value).to_not.equal(other_value) -- checks inequality
expect(value).to_not.be_truthy()        -- checks falsiness
expect(fn).to_not.fail()                -- checks function doesn't error
```

For detailed assertion patterns, see [Assertion Pattern Mapping](assertion_pattern_mapping.md).

### Common Assertion Mistakes

1. **Incorrect negation syntax**:
   ```lua
   -- WRONG:
   expect(value).not_to.equal(other_value)  -- "not_to" is not valid
   
   -- CORRECT:
   expect(value).to_not.equal(other_value)  -- use "to_not" instead
   ```

2. **Incorrect member access syntax**:
   ```lua
   -- WRONG:
   expect(value).to_be(true)  -- "to_be" is not a valid method
   expect(number).to_be_greater_than(5)  -- underscore methods need dot access
   
   -- CORRECT:
   expect(value).to.be(true)  -- use "to.be" not "to_be"
   expect(number).to.be_greater_than(5)  -- this is correct because it's a method
   ```

3. **Inconsistent operator order**:
   ```lua
   -- WRONG:
   expect(expected).to.equal(actual)  -- parameters reversed
   
   -- CORRECT:
   expect(actual).to.equal(expected)  -- what you have, what you expect
   ```

## Testing Specific Components

### Testing with Mocks

Use the firmo mocking system for isolation:

```lua
-- Import mocking tools
local mock, spy = firmo.mock, firmo.spy

describe("Module with dependencies", function()
  local module_under_test
  local original_dependency
  
  before(function()
    -- Store original dependency
    original_dependency = package.loaded["module.dependency"]
    
    -- Create a mock
    package.loaded["module.dependency"] = mock.create({
      some_function = function() return "mocked_value" end
    })
    
    -- Load module under test (which will use our mock)
    module_under_test = require("module.under.test")
  end)
  
  after(function()
    -- Restore original dependency
    package.loaded["module.dependency"] = original_dependency
    package.loaded["module.under.test"] = nil -- Force reload next time
  end)
  
  it("should use the dependency", function()
    local result = module_under_test.function_that_uses_dependency()
    expect(result).to.equal("processed_mocked_value")
  end)
end)
```

### Testing with Spies

Use spies to track function calls without changing behavior:

```lua
describe("Function call tracking", function()
  it("should track method calls", function()
    local obj = {
      method = function(self, a, b) return a + b end
    }
    
    -- Create spy on object method
    local method_spy = spy.on(obj, "method")
    
    -- Call the method
    local result = obj.method(obj, 2, 3)
    
    -- Verify call
    expect(result).to.equal(5) -- Original behavior preserved
    expect(method_spy).to.be.called_times(1)
    expect(method_spy).to.be.called_with(obj, 2, 3)
  end)
end)
```

### Testing Asynchronous Code

For testing async code, use firmo's async capabilities:

```lua
local async = firmo.async

describe("Async functions", function()
  it("should handle asynchronous operations", async(function(done)
    async_function(function(result)
      expect(result).to.equal(expected_value)
      done() -- Signal test completion
    end)
  end))
  
  it("should timeout if operation takes too long", async(function(done)
    async.set_timeout(100) -- 100ms timeout
    
    never_completing_function(function(result)
      -- This should never be called
      expect(true).to.equal(false) -- Would fail
      done()
    end)
    
    -- Test will fail with timeout after 100ms
  end, 100))
end)
```

### Testing Coverage Module

When testing the coverage module, special considerations apply:

```lua
describe("Coverage module", function()
  local coverage = require "lib.coverage"
  local original_tracking_state
  local fs = require "lib.tools.filesystem"
  local temp_dir
  
  before(function()
    -- Create temp directory
    temp_dir = os.tmpname() .. "_dir"
    fs.create_directory(temp_dir)
    
    -- Disable tracking for tests
    original_tracking_state = coverage.is_enabled()
    if original_tracking_state then
      coverage.stop()
    end
  end)
  
  after(function()
    -- Restore original tracking state
    if original_tracking_state then
      coverage.start()
    end
    
    -- Clean up temp directory
    fs.delete_directory(temp_dir)
  end)
  
  it("should track line execution", function()
    -- Create test file
    local test_file = temp_dir .. "/test.lua"
    fs.write_file(test_file, "local x = 1\nreturn x + 1\n")
    
    -- Start tracking and run file
    coverage.start()
    dofile(test_file)
    coverage.stop()
    
    -- Get results
    local report_data = coverage.get_report_data()
    expect(report_data.files[test_file]).to.exist()
    expect(report_data.files[test_file].lines[1].executed).to.equal(true)
    expect(report_data.files[test_file].lines[2].executed).to.equal(true)
  end)
end)
```

### Testing with Filesystem

For tests involving the filesystem module:

```lua
describe("Filesystem operations", function()
  local test_dir
  local fs = require "lib.tools.filesystem"
  
  before(function()
    -- Create test directory
    test_dir = os.tmpname() .. "_dir"
    fs.create_directory(test_dir)
  end)
  
  after(function()
    -- Remove test directory recursively
    fs.delete_directory(test_dir)
  end)
  
  it("should write and read files", function()
    local file_path = fs.join_paths(test_dir, "test.txt")
    local content = "Test content"
    
    fs.write_file(file_path, content)
    local read_content = fs.read_file(file_path)
    
    expect(read_content).to.equal(content)
  end)
end)
```

### Testing Error Handling

Test both success and error paths:

```lua
describe("Error handling", function()
  local function divide(a, b)
    if type(a) ~= "number" or type(b) ~= "number" then
      return nil, "Both arguments must be numbers"
    end
    
    if b == 0 then
      return nil, "Division by zero"
    end
    
    return a / b
  end
  
  it("should handle valid inputs", function()
    local result, err = divide(10, 2)
    expect(result).to.equal(5)
    expect(err).to_not.exist()
  end)
  
  it("should handle invalid types", function()
    local result, err = divide("10", 2)
    expect(result).to_not.exist()
    expect(err).to.equal("Both arguments must be numbers")
  end)
  
  it("should handle division by zero", function()
    local result, err = divide(10, 0)
    expect(result).to_not.exist()
    expect(err).to.equal("Division by zero")
  end)
end)
```

## Best Practices

### Test Independence

1. **Isolate Each Test**: Each test should run independently from others
2. **Clean Up After Tests**: Use `after` hooks to clean up resources
3. **Don't Share State**: Avoid using shared variables across test cases

### Test Naming

1. **Be Descriptive**: Describe what the test is checking
2. **Follow Patterns**: Use "should" statements (e.g., "should validate input")
3. **Be Specific**: Mention the expected outcome

### Test Organization

1. **Group Related Tests**: Use nested `describe` blocks for logical grouping
2. **Order Tests Logically**: From simple to complex, following user workflow
3. **Separate Setup Code**: Use `before` hooks for repeated setup

### Error Testing

1. **Be Specific**: Test for specific error messages when possible
2. **Test Edge Cases**: Include tests for boundary conditions
3. **Test Error Recovery**: Verify the system recovers properly after errors

### Test Coverage

1. **Cover All Paths**: Test success paths, error paths, and edge cases
2. **Test Public Interface**: Focus on testing the public API
3. **Don't Test Implementation Details**: Tests should be resilient to refactoring

## Troubleshooting Common Test Issues

### Test Not Running

1. **Check Import Statements**: Ensure you're importing test functions correctly
2. **Check File Path**: Verify the file path when running tests
3. **Check for Syntax Errors**: Run `luac -p your_test_file.lua` to check for syntax errors

### Assertion Failures

1. **Check Parameter Order**: Remember, it's `expect(actual).to.equal(expected)`
2. **Check Assertion Syntax**: Verify you're using the correct method (e.g., `.to.be.a()` not `.to_be_a()`)
3. **Check for Deep Equality**: Tables are compared using deep equality

### Setup/Teardown Issues

1. **Check Hook Scope**: Hooks are local to their `describe` block
2. **Check Variable Initialization**: Make sure variables are properly initialized
3. **Check Cleanup**: Verify resources are properly released

## Advanced Testing Techniques

### Table-Driven Tests

For testing multiple input/output combinations:

```lua
describe("String utility", function()
  local test_cases = {
    { input = "hello", expected = "HELLO" },
    { input = "Hello", expected = "HELLO" },
    { input = "123", expected = "123" },
    { input = "", expected = "" },
  }
  
  for _, test in ipairs(test_cases) do
    it("should uppercase '" .. test.input .. "'", function()
      expect(string.upper(test.input)).to.equal(test.expected)
    end)
  end
end)
```

### Module Reset Testing

When testing modules that need state reset:

```lua
describe("Module with global state", function()
  local module_with_state = require("lib.module_with_state")
  local module_reset = require("lib.core.module_reset")
  
  before(function()
    -- Register module for resetting
    module_reset.register(module_with_state)
  end)
  
  after(function()
    -- Reset after each test
    module_reset.reset(module_with_state)
  end)
  
  it("should initialize with default state", function()
    expect(module_with_state.get_count()).to.equal(0)
  end)
  
  it("should increment counter", function()
    module_with_state.increment()
    expect(module_with_state.get_count()).to.equal(1)
  end)
  
  -- Because of the reset, this test will still see count=0
  it("should still have default state in next test", function()
    expect(module_with_state.get_count()).to.equal(0)
  end)
end)
```

## Conclusion

Writing effective tests is crucial for maintaining the quality and reliability of the firmo framework. By following the standardized approach and best practices outlined in this guide, you'll create tests that are easy to understand, maintain, and extend.

For more detailed information on assertions, see the [Assertion Pattern Mapping](assertion_pattern_mapping.md) document.

## Last Updated

2025-03-13