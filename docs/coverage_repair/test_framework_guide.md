# Test Framework Guide for lust-next

## Introduction

This guide provides a comprehensive overview of the lust-next test framework, including its architecture, components, and usage patterns. It serves as both a reference for contributors and a guide for users writing tests.

## Framework Architecture

lust-next is a behavior-driven development (BDD) test framework for Lua, featuring a rich set of testing capabilities:

1. **Core Testing Functionality**:
   - Nested test blocks with `describe` and `it`
   - Setup and teardown hooks with `before` and `after`
   - Rich assertion library with chainable syntax

2. **Advanced Features**:
   - Comprehensive mocking system
   - Asynchronous testing support
   - Test tagging and filtering
   - Code coverage analysis
   - Test quality validation

3. **Output and Reporting**:
   - Multiple output formats (TAP, CSV, XML, JSON)
   - HTML coverage reports
   - Test result summaries
   - Custom formatter support

### Component Overview

The test framework consists of several key components:

1. **Test Runner** (`test.lua`):
   - Entry point for executing tests
   - Processes command-line options
   - Manages test discovery and execution

2. **Test Discovery System**:
   - Finds test files in specified directories
   - Supports pattern-based filtering
   - Detects test functions and blocks

3. **Core Framework** (`lust-next.lua`):
   - Defines core testing functions
   - Manages test state and lifecycle
   - Provides assertion functions

4. **Coverage System**:
   - Tracks code execution during tests
   - Identifies executable vs. non-executable lines
   - Generates coverage reports

5. **Output System**:
   - Formats test results for various outputs
   - Supports console and file-based reporting
   - Integrates with continuous integration systems

## Using the Framework

### Running Tests

All tests are executed through the unified `test.lua` interface:

```bash
lua test.lua [options] [path]
```

Where:
- `[options]` are command-line flags that modify test behavior
- `[path]` is a file or directory to test (automatically detected)

Common options include:

| Option | Description |
|--------|-------------|
| `--coverage` | Enable code coverage tracking |
| `--quality` | Enable test quality validation |
| `--pattern=<pattern>` | Filter test files by pattern |
| `--watch` | Enable continuous testing on file changes |
| `--format=<format>` | Specify output format (tap, csv, json, etc.) |
| `--verbose` | Show more detailed output |
| `--help` | Show all available options |

Examples:

```bash
# Run all tests
lua test.lua tests/

# Run a specific test file
lua test.lua tests/reporting_test.lua

# Run tests with coverage tracking
lua test.lua --coverage tests/

# Run tests with a specific pattern
lua test.lua --pattern=coverage tests/

# Run tests with continuous testing
lua test.lua --watch tests/

# Run tests with quality validation
lua test.lua --quality tests/
```

### Writing Tests

#### Basic Test Structure

```lua
-- Import lust-next
local lust = require "lust-next"

-- Import test functions
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Optional: import test lifecycle hooks
local before, after = lust.before, lust.after

-- Import module to test
local module_to_test = require "path.to.module"

-- Top-level test suite
describe("ModuleName", function()
  -- Test case
  it("should perform a specific function", function()
    local result = module_to_test.function()
    expect(result).to.equal(expected_value)
  end)
  
  -- Nested test group
  describe("SubComponent", function()
    -- More specific tests
    it("should handle specific case", function()
      expect(module_to_test.sub_function()).to.be_truthy()
    end)
  end)
end)
```

#### Test Lifecycle Hooks

```lua
describe("Module with state", function()
  local instance
  
  -- Runs before each test in this describe block
  before(function()
    instance = module.create()
  end)
  
  -- Runs after each test in this describe block
  after(function()
    instance:cleanup()
    instance = nil
  end)
  
  it("should perform operation", function()
    -- instance is available here
    local result = instance:operation()
    expect(result).to.equal(expected)
  end)
end)
```

#### Assertions

lust-next uses expect-style assertions with a chainable syntax:

```lua
-- Basic assertions
expect(value).to.exist()              -- value is not nil
expect(actual).to.equal(expected)     -- equality check
expect(value).to.be.a("string")       -- type check
expect(value).to.be_truthy()          -- truthy check
expect(string_value).to.match(pattern) -- pattern matching
expect(function_that_errors).to.fail() -- error check

-- Negated assertions
expect(value).to_not.exist()          -- value is nil
expect(a).to_not.equal(b)             -- inequality check
expect(value).to_not.be_truthy()      -- falsey check
```

For detailed assertion patterns and examples, see [Assertion Pattern Mapping](assertion_pattern_mapping.md).

### Test Organization

#### File Structure

Test files should follow a consistent structure:

```
tests/                      # Main test directory
├── module_name_test.lua    # Tests for a specific module
├── another_module_test.lua # Tests for another module
├── fixtures/               # Test fixtures directory
│   ├── test_data.lua       # Test data
│   └── mocks/              # Mock implementations
│       └── dependency.lua  # Mock of a dependency
└── ...
```

#### Test Naming Conventions

- Test file names: `module_name_test.lua`
- Test suite names: Descriptive of the module being tested
- Test case names: Start with "should" and describe expected behavior

#### Group Organization

Group related tests using nested `describe` blocks:

```lua
describe("Calculator", function()
  describe("basic operations", function()
    it("should add numbers", function() end)
    it("should subtract numbers", function() end)
  end)
  
  describe("advanced operations", function()
    it("should calculate square root", function() end)
    it("should handle complex expressions", function() end)
  end)
  
  describe("error handling", function()
    it("should throw on division by zero", function() end)
    it("should handle invalid input", function() end)
  end)
end)
```

## Advanced Features

### Mocking

lust-next provides a powerful mocking system:

```lua
local mock = lust.mock
local spy = lust.spy
local stub = lust.stub

describe("Module with dependencies", function()
  local original_dependency
  
  before(function()
    -- Store original and replace with mock
    original_dependency = package.loaded["module.dependency"]
    package.loaded["module.dependency"] = mock({
      function_name = function(arg) return "mocked " .. arg end
    })
  end)
  
  after(function()
    -- Restore original
    package.loaded["module.dependency"] = original_dependency
  end)
  
  it("should use dependency correctly", function()
    local result = module_under_test.function_that_uses_dependency("input")
    expect(result).to.equal("processed mocked input")
  end)
end)
```

### Async Testing

For asynchronous code, use the async testing support:

```lua
local async = lust.async

describe("Asynchronous operations", function()
  it("should complete callback operation", async(function(done)
    async_function(function(result)
      expect(result).to.equal(expected)
      done() -- Signal test completion
    end)
  end))
  
  it("should time out after specified period", async(function(done)
    -- This test will automatically fail if done() isn't called within 100ms
    async_function_that_never_calls_back(function(result)
      done()
    end)
  end, 100)) -- 100ms timeout
end)
```

### Tagging and Filtering

Tests can be tagged for selective execution:

```lua
describe("Feature A", {"feature-a", "core"}, function()
  it("should work", function() end)
end)

describe("Feature B", {"feature-b", "integration"}, function()
  it("should also work", function() end)
end)
```

Run with:
```bash
lua test.lua --tags=core tests/
```

### Code Coverage

Code coverage tracking can be enabled with the `--coverage` option:

```bash
lua test.lua --coverage tests/
```

This will track line execution and generate coverage reports.

### Quality Validation

Test quality validation helps ensure test thoroughness:

```bash
lua test.lua --quality tests/
```

This will check for:
- Assertion count
- Branch coverage
- Test specificity
- Error case coverage

## Best Practices

### Test Isolation

1. **Independent Tests**: Each test should run independently
2. **Clean Environment**: Reset state between tests with before/after hooks
3. **Mock External Systems**: Don't rely on external systems in tests

### Assertion Best Practices

1. **Be Specific**: Test precise behaviors, not implementation details
2. **One Concept Per Test**: Each test should verify one specific concept
3. **Clear Failure Messages**: Use descriptive test names and assertions

### Mocking Best Practices

1. **Mock at Boundaries**: Mock at module boundaries, not internal functions
2. **Verify Interactions**: Check that mocks were called correctly
3. **Restore Original State**: Always clean up mocks in after hooks

### Performance Considerations

1. **Focused Tests**: Run only the tests you need during development
2. **Mock Heavy Operations**: Use mocks for database/network/filesystem
3. **Use Watch Mode**: For faster feedback during development

## Troubleshooting

### Common Issues

1. **Tests Not Running**:
   - Check file path and test naming
   - Verify imports are correct
   - Check for syntax errors

2. **Assertion Failures**:
   - Check parameter order (expect(actual).to.equal(expected))
   - Verify assertion syntax (use .to.be.a() not .to_be_a())
   - Check for deep equality issues with tables

3. **Missing Functions**:
   - Ensure correct imports from lust-next
   - Check for typos in function names
   - Verify you're not using functions that don't exist (like lust.run())

### Debugging Tests

For debugging failing tests:

1. **Add Verbose Logging**:
   ```bash
   lua test.lua --verbose tests/failing_test.lua
   ```

2. **Use Print Statements**: Add temporary print statements to see variable values

3. **Isolate Test Cases**: Run a specific test to isolate the issue:
   ```bash
   lua test.lua --pattern="should handle specific case" tests/failing_test.lua
   ```

## Conclusion

The lust-next testing framework provides a comprehensive solution for testing Lua code with a focus on readability, flexibility, and power. By following the patterns and practices in this guide, you'll create tests that are easier to maintain and enhance the reliability of your code.

For detailed assertion examples and patterns, see the [Assertion Pattern Mapping](assertion_pattern_mapping.md) document.

For specific guidance on testing the coverage module and other components, see the [Testing Guide](testing_guide.md).

## Last Updated

2025-03-13