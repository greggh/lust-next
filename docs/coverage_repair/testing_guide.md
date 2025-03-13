# Testing Guide for lust-next

## Introduction

This guide provides comprehensive information about writing and running tests for the lust-next project. It covers the standardized testing approach, best practices for writing tests, and specific considerations for testing different components of the framework.

## Standardized Testing Approach

### Universal Command Interface

All tests in lust-next are run through a standardized command interface using `test.lua` in the project root:

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
lua test.lua tests/reporting_test.lua

# Run tests with coverage
lua test.lua --coverage tests/

# Run tests with a specific pattern
lua test.lua --pattern=coverage tests/

# Run tests with watch mode
lua test.lua --watch tests/

# Run tests with quality validation
lua test.lua --quality tests/
```

### Test Directory Structure

Tests are organized in a logical directory structure by component:
```
tests/
├── assertions_test.lua       # Basic assertions tests
├── async_test.lua            # Async functionality tests
├── codefix_test.lua          # Code quality tool tests
├── config_test.lua           # Configuration system tests
├── coverage_module_test.lua  # Coverage module tests
├── discovery_test.lua        # Test discovery system tests
├── filesystem_test.lua       # Filesystem module tests
├── mocking_test.lua          # Mocking system tests
├── module_reset_test.lua     # Module reset functionality tests
├── reporting_test.lua        # Report generation tests
├── fixtures/                 # Test fixtures directory
│   ├── common_errors.lua     # Error test fixtures
│   └── modules/              # Test module fixtures
└── ...
```

## Writing Tests

### Basic Test Structure

All test files follow this basic structure:

```lua
-- Import lust-next
local lust = require "lust-next"

-- Import test functions
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Import test lifecycle hooks (optional)
local before, after = lust.before, lust.after

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

### Assertion Basics

lust-next uses expect-style assertions:

```lua
-- Basic assertions
expect(value).to.exist()                -- checks value is not nil
expect(actual).to.equal(expected)       -- checks equality
expect(value).to.be.a("string")         -- checks type
expect(value).to.be_truthy()            -- checks boolean truthiness
expect(function_to_test).to.fail()      -- checks function throws error

-- Negated assertions
expect(value).to_not.equal(other_value) -- checks inequality
expect(value).to_not.be_truthy()        -- checks falsiness
expect(fn).to_not.fail()                -- checks function doesn't error
```

For detailed assertion patterns, see [Assertion Pattern Mapping](assertion_pattern_mapping.md).

## Testing Specific Components

### Testing with Mocks

Use the lust mocking system for isolation:

```lua
local mock = lust.mock
local spy = lust.spy

describe("Module with dependencies", function()
  local original_dependency
  
  before(function()
    -- Store original dependency
    original_dependency = package.loaded["module.dependency"]
    
    -- Create a mock
    package.loaded["module.dependency"] = mock({
      some_function = function() return "mocked_value" end
    })
  end)
  
  after(function()
    -- Restore original dependency
    package.loaded["module.dependency"] = original_dependency
  end)
  
  it("should use the dependency", function()
    local result = module_under_test.function_that_uses_dependency()
    expect(result).to.equal("processed_mocked_value")
  end)
end)
```

### Testing Asynchronous Code

For testing async code, use lust's async capabilities:

```lua
local async = lust.async

describe("Async functions", function()
  it("should handle asynchronous operations", async(function(done)
    async_function(function(result)
      expect(result).to.equal(expected_value)
      done() -- Signal test completion
    end)
  end))
end)
```

### Testing Coverage Module

When testing the coverage module, special considerations apply:

1. **Isolation from Self-Coverage**: Prevent the coverage module from tracking itself during tests

   ```lua
   describe("Coverage module", function()
     local original_tracking_state
     
     before(function()
       -- Disable tracking for tests
       original_tracking_state = coverage.is_tracking()
       coverage.stop_tracking()
     end)
     
     after(function()
       -- Restore original tracking state
       if original_tracking_state then
         coverage.start_tracking()
       end
     end)
     
     -- Tests here
   end)
   ```

2. **Testing with Real Files**: Create temporary test files when needed

   ```lua
   describe("Coverage file tracking", function()
     local temp_file_path
     
     before(function()
       -- Create a temp file with known content
       temp_file_path = os.tmpname()
       local file = io.open(temp_file_path, "w")
       file:write("local function test() return true end\ntest()\n")
       file:close()
     end)
     
     after(function()
       -- Clean up
       os.remove(temp_file_path)
     end)
     
     it("should track file execution", function()
       coverage.start_tracking()
       dofile(temp_file_path)
       coverage.stop_tracking()
       
       local stats = coverage.get_stats()
       expect(stats[temp_file_path]).to.exist()
       expect(stats[temp_file_path].executed_lines[1]).to.exist()
     end)
   end)
   ```

3. **Mocking Static Analyzer**: When testing modules that depend on the static analyzer

   ```lua
   describe("Module using static analyzer", function()
     local original_static_analyzer
     
     before(function()
       -- Store original module
       original_static_analyzer = package.loaded["lib.coverage.static_analyzer"]
       
       -- Create mock
       package.loaded["lib.coverage.static_analyzer"] = {
         analyze_source = function(source, filename)
           return {
             executable_lines = {1, 2, 3},
             functions = {
               {name = "test", line = 1, last_line = 3}
             },
             version = "mock-1.0.0"
           }
         end
       }
     end)
     
     after(function()
       -- Restore original
       package.loaded["lib.coverage.static_analyzer"] = original_static_analyzer
     end)
     
     -- Tests here
   end)
   ```

### Testing with Filesystem

For tests involving the filesystem module:

```lua
describe("Filesystem operations", function()
  local test_dir = os.tmpname() .. "_dir"
  local fs = require "lib.tools.filesystem"
  
  before(function()
    -- Create test directory
    fs.mkdir(test_dir)
  end)
  
  after(function()
    -- Remove test directory and contents
    for _, file in ipairs(fs.list_files(test_dir)) do
      fs.remove_file(file)
    end
    fs.remove_dir(test_dir)
  end)
  
  it("should write and read files", function()
    local file_path = test_dir .. "/test.txt"
    local content = "Test content"
    
    fs.write_file(file_path, content)
    local read_content = fs.read_file(file_path)
    
    expect(read_content).to.equal(content)
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

## Conclusion

Writing effective tests is crucial for maintaining the quality and reliability of the lust-next framework. By following the standardized approach and best practices outlined in this guide, you'll create tests that are easy to understand, maintain, and extend.

For more detailed information on assertions, see the [Assertion Pattern Mapping](assertion_pattern_mapping.md) document.

## Last Updated

2025-03-13