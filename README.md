# Lust-Next - Enhanced Lua Testing Framework

[![Version](https://img.shields.io/badge/Version-0.7.4-blue?style=flat-square)](https://github.com/greggh/lust-next/releases/tag/v0.7.4)

[![CI](https://github.com/greggh/lust-next/actions/workflows/ci.yml/badge.svg)](https://github.com/greggh/lust-next/actions/workflows/ci.yml)
[![Documentation](https://github.com/greggh/lust-next/actions/workflows/docs.yml/badge.svg)](https://github.com/greggh/lust-next/actions/workflows/docs.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Lust-Next is a lightweight, powerful testing library for Lua projects. This enhanced fork of [lust](https://github.com/bjornbytes/lust) adds significant new functionality while maintaining the simplicity and elegance of the original.

## Features

- **Minimal Dependencies**: Single file with no external requirements
- **Familiar Syntax**: BDD-style `describe`/`it` blocks for intuitive test organization  
- **Rich Assertions**: Extensive expect-style assertion library with detailed diffs
- **Function Spies**: Track function calls and arguments
- **Before/After Hooks**: For setup and teardown
- **Module Management**: Reset and reload modules with `reset_module()` for clean state
- **Automatic Test Discovery**: Find and run tests without manual configuration
- **Filtering & Tagging**: Run specific test groups or tagged tests
- **Focused Tests**: Run only specific tests with `fdescribe`/`fit`
- **Excluded Tests**: Skip specific tests with `xdescribe`/`xit`
- **Enhanced Reporting**: Clear, colorful summaries of test results
- **Output Formatting**: Multiple output styles including dot notation and compact mode
- **Async Support**: Test asynchronous code with parallel operations and conditions
- **Mocking System**: Create and manage mocks for dependencies
- **Cross-Platform**: Works in console and non-console environments

## Quick Start

Copy the `lust-next.lua` file to your project and require it:

### Option 1: Expose all functions globally (new in v0.7.1)

```lua
local lust_next = require('lust-next')
lust_next.expose_globals() -- Makes all test functions available globally

describe('my project', function()
  before_each(function()
    -- This gets run before every test.
  end)

  describe('module1', function() -- Can be nested
    it('feature1', function()
      assert.equal('expected value', 'expected value') -- New assertion helper
      assert.is_true(true) -- Another assertion helper
    end)

    it('feature2', function()
      expect(nil).to.exist() -- The standard expect API still works
    end)
  end)
end)
```

### Option 2: Import specific functions (traditional approach)

```lua
local lust = require 'lust-next'
local describe, it, expect = lust.describe, lust.it, lust.expect

describe('my project', function()
  lust.before(function()
    -- This gets run before every test.
  end)

  describe('module1', function() -- Can be nested
    it('feature1', function()
      expect(1).to.be.a('number') -- Pass
      expect('astring').to.equal('astring') -- Pass
    end)

    it('feature2', function()
      expect(nil).to.exist() -- Fail
    end)
  end)
end)
```

## Integration with hooks-util

Lust-Next is integrated with the [hooks-util](https://github.com/greggh/hooks-util) framework, providing a standardized testing experience for Lua-based Neovim projects:

```lua
-- From hooks-util, set up a project with lust-next testing
local lust_next = require("hooks-util.lust-next")
lust_next.setup_project("/path/to/your/project")
```

This integration provides:
- Automatic test discovery and setup
- Standard test directory structure
- CI workflow generation for GitHub/GitLab/Azure
- Pre-commit hook integration

See the [hooks-util documentation](https://github.com/greggh/hooks-util/blob/main/docs/api/lua-integration.md) for more details on using lust-next with hooks-util.

## Documentation

### Core Functions

#### `lust.describe(name, func)`, `lust.fdescribe(name, func)`, `lust.xdescribe(name, func)`

Used to declare a group of tests. Groups created using `describe` can be nested.

```lua
describe("math operations", function()
  -- Regular test group - runs normally
end)

fdescribe("focused group", function()
  -- Focused test group - these tests ALWAYS run even when others are focused
end)

xdescribe("excluded group", function()
  -- Excluded test group - these tests NEVER run
end)
```

#### `lust.it(name, func)`, `lust.fit(name, func)`, `lust.xit(name, func)`

Used to declare a test, which consists of a set of assertions.

```lua
it("adds two numbers correctly", function()
  -- Regular test - runs normally
  expect(2 + 2).to.equal(4)
end)

fit("important test", function()
  -- Focused test - this test ALWAYS runs even when others are focused
  expect(true).to.be.truthy()
end)

xit("work in progress", function()
  -- Excluded test - this test NEVER runs
  expect(false).to.be.truthy() -- Won't fail since it's excluded
end)
```

#### `lust.before(fn)` and `lust.after(fn)`

Set up functions that run before or after each test in a describe block.

```lua
describe("database tests", function()
  before(function()
    -- Set up database connection
  end)
  
  after(function()
    -- Close database connection
  end)
  
  it("queries data correctly", function()
    -- Test here
  end)
end)
```

### Assertions

Lust uses "expect style" assertions that can be chained for readable tests:

```lua
expect(value).to.equal(expected)
expect(value).to_not.be.nil()
```

#### Basic Assertions

- `expect(x).to.exist()` - Fails if `x` is `nil`
- `expect(x).to.equal(y, [eps])` - Strict equality test (with optional epsilon for floats)
- `expect(x).to.be(y)` - Equality using the `==` operator
- `expect(x).to.be.truthy()` - Fails if `x` is `nil` or `false`
- `expect(x).to.be.a(y)` - Type checking
- `expect(x).to.have(y)` - Check if table contains value
- `expect(f).to.fail()` - Ensures function throws an error
- `expect(f).to.fail.with(pattern)` - Ensures function throws an error matching pattern
- `expect(x).to.match(p)` - Matches string against pattern
- `expect(x).to_not.*` - Negates any assertion

#### Enhanced Assertions

##### Table Assertions
```lua
-- Check for specific keys
expect(table).to.contain.key("id")
expect(table).to.contain.keys({"id", "name", "email"})

-- Check for values
expect(table).to.contain.value("example")
expect(table).to.contain.values({"one", "two"})

-- Check for subset/superset relationships
expect(small_table).to.contain.subset(big_table)

-- Check for exact key set
expect(table).to.contain.exactly({"only", "these", "keys"})
```

##### String Assertions
```lua
-- Check string prefix/suffix
expect(str).to.start_with("hello")
expect(str).to.end_with("world")
```

##### Type Assertions
```lua
-- Advanced type checking
expect(fn).to.be_type("callable")  -- Function or callable table
expect(num).to.be_type("comparable")  -- Can use < operator
expect(table).to.be_type("iterable")  -- Can iterate with pairs()
```

##### Numeric Assertions
```lua
-- Numeric comparisons
expect(value).to.be_greater_than(minimum)
expect(value).to.be_less_than(maximum)
expect(value).to.be_between(min, max)  -- Inclusive
expect(value).to.be_approximately(target, delta)
```

##### Error Assertions
```lua
-- Enhanced error checking
expect(function_that_throws).to.throw.error()  
expect(function_that_throws).to.throw.error_matching("pattern")
expect(function_that_throws).to.throw.error_type("string")
```

### Spies

Spies track function calls and their arguments:

```lua
local spy = lust.spy(myFunction)
spy(1, 2, 3)
expect(#spy).to.equal(1)
expect(spy[1][1]).to.equal(1)
```

### Custom Assertions

You can add custom assertions:

```lua
lust.paths.empty = {
  test = function(value)
    return #value == 0,
      'expected ' .. tostring(value) .. ' to be empty',
      'expected ' .. tostring(value) .. ' to not be empty'
  end
}

table.insert(lust.paths.be, 'empty')

expect({}).to.be.empty()
```

### New Features

#### Output Formatting

Configure the test output format to your preference:

```lua
-- Configure output format programmatically
lust.format({
  use_color = true,          -- Whether to use color codes in output
  indent_char = '  ',        -- Character to use for indentation (tab or spaces)
  indent_size = 2,           -- How many indent_chars to use per level
  show_trace = false,        -- Show stack traces for errors
  show_success_detail = true, -- Show details for successful tests
  compact = false,           -- Use compact output format (less verbose)
  dot_mode = false,          -- Use dot mode (. for pass, F for fail)
  summary_only = false       -- Show only summary, not individual tests
})

-- Or disable colors
lust.nocolor()
```

Available command-line options when running tests:

```bash
# Use different output formats
lua lust-next.lua --format dot       # Minimal output with dots (. for pass, F for fail)
lua lust-next.lua --format compact   # Compact output with minimal details
lua lust-next.lua --format summary   # Show only the final summary
lua lust-next.lua --format detailed  # Show full details including stack traces

# Control indentation
lua lust-next.lua --indent space     # Use spaces for indentation
lua lust-next.lua --indent tab       # Use tabs for indentation
lua lust-next.lua --indent 4         # Use 4 spaces for indentation

# Disable colors
lua lust-next.lua --no-color
```

#### Focused and Excluded Tests

Run only specific tests using focus and exclude features:

```lua
-- Run only focused tests
fdescribe("important module", function()
  it("does something", function()
    -- This test runs because parent is focused
  end)
  
  xit("isn't ready", function()
    -- This test is excluded even though parent is focused
  end)
end)

describe("other module", function()
  it("normal test", function()
    -- This won't run when focus mode is active
  end)
  
  fit("critical feature", function()
    -- This test runs because it's focused
  end)
})
```

When any `fdescribe` or `fit` is present, lust-next enters "focus mode" where only focused tests run. This is useful for working on a specific feature or debugging a failure.

#### Automatic Test Discovery

Automatically find and run all test files:

```lua
-- Run all test files in the current directory and subdirectories
lust.run_discovered(".")
```

#### Module Reset Utilities

Ensure clean state between tests with module reset utilities:

```lua
-- Reset a module to get a fresh instance
local fresh_module = lust.reset_module("path.to.module")

-- Ensure modules are reset between tests
describe("Database tests", function()
  local db
  
  before_each(function()
    -- Reset the module before each test to ensure clean state
    db = lust.reset_module("my.database")
  end)
  
  it("performs operations correctly", function()
    -- Test with a fresh module instance
    db.connect()
    -- ... more test code
  end)
end)

-- Run a test with a fresh module in a single call
lust.with_fresh_module("path.to.module", function(mod)
  -- Test code using the fresh module instance
  mod.function_call()
  expect(mod.result).to.equal(expected)
end)
```

The module reset utilities provide several benefits:
- Ensures each test runs with a fresh module state
- Eliminates test cross-contamination
- Reduces boilerplate with clear, consistent syntax
- Automatically available as globals with `expose_globals()`

#### Test Filtering and Tagging

Tag tests and run only specific tags:

```lua
-- Add tags to a test
lust.tags("unit", "math")
it("adds numbers correctly", function()
  expect(1 + 1).to.equal(2)
end)

-- Add tags to a group of tests
describe("Math operations", function()
  lust.tags("unit", "math")
  
  it("test1", function() end)
  it("test2", function() end)
  -- Both tests inherit the "unit" and "math" tags
end)

-- Filter by tag programmatically
lust.only_tags("unit")
lust.run_discovered("./tests")

-- Filter by test name pattern
lust.filter("math")
lust.run_discovered("./tests")

-- Reset all filters
lust.reset_filters()

-- Command line filtering (when running directly)
-- lua lust-next.lua --tags unit,math
-- lua lust-next.lua --filter "addition"
```

You can use the filtering system to run specific subsets of your tests:

```lua
-- Run tests with options
lust.run_discovered("./tests", "*_test.lua", {
  tags = {"unit", "fast"},
  filter = "calculation"
})

-- Run filtered tests from CLI
-- lua lust-next.lua --dir ./tests --tags unit,fast --filter calculation
```

#### Async Testing

Test asynchronous code with await/async:

```lua
-- Basic usage with it_async shorthand
it_async("tests async code", function()
  local result = nil
  
  -- Start async operation
  startAsyncOperation(function(data) 
    result = data
  end)
  
  -- Wait for a specific amount of time
  lust.await(100) -- Wait 100ms
  
  -- Make assertions after the wait
  expect(result).to.equal("expected result")
end)

-- Use wait_until for condition-based waiting
it_async("waits for a condition", function()
  local value = false
  
  -- Start async operation that will set value to true
  setTimeout(function() value = true end, 50)
  
  -- Wait until value becomes true or timeout after 200ms
  lust.wait_until(function() return value end, 200)
  
  -- Assert after condition is met
  expect(value).to.be.truthy()
end)

-- Custom timeouts per test
it("tests with custom timeout", lust.async(function()
  -- Test code here
  lust.await(500)
  expect(true).to.be.truthy()
end, 1000)) -- 1 second timeout

-- Set global default timeout
lust.set_timeout(5000) -- 5 seconds for all async tests

-- Run multiple async operations in parallel
it_async("handles parallel operations", function()
  -- Define multiple async operations
  local function op1()
    await(100)
    return "op1 result"
  end
  
  local function op2()
    await(200)
    return "op2 result"
  end
  
  local function op3()
    await(300)
    return "op3 result"
  end
  
  -- Run all operations in parallel and get all results
  local results = parallel_async(op1, op2, op3)
  
  -- Verify all results
  expect(#results).to.equal(3)
  expect(results[1]).to.equal("op1 result")
  expect(results[2]).to.equal("op2 result")
  expect(results[3]).to.equal("op3 result")
end)
```

Key async features:

- `lust.async(fn, timeout)` - Wraps a function to be executed asynchronously
- `lust.it_async(name, fn, timeout)` - Shorthand for async tests
- `lust.await(ms)` - Waits for the specified time in milliseconds
- `lust.wait_until(condition_fn, timeout, check_interval)` - Waits until a condition function returns true
- `lust.parallel_async(fn1, fn2, ...)` - Runs multiple async functions in parallel and returns all results
- `lust.set_timeout(ms)` - Sets the default timeout for async tests

#### Mocking

Create and manage mocks with a comprehensive mocking system:

```lua
-- Basic spy usage - track function calls while preserving behavior
local my_fn = function(a, b) return a + b end
local spy_fn = lust.spy(my_fn)

spy_fn(5, 10)  -- Call the function

expect(spy_fn.called).to.be.truthy()
expect(spy_fn.call_count).to.equal(1)
expect(spy_fn:called_with(5, 10)).to.be.truthy()

-- Spy on an object method
local calculator = { add = function(a, b) return a + b end }
local add_spy = lust.spy(calculator, "add")

calculator.add(2, 3)  -- Call the method
expect(add_spy.called).to.be.truthy()
add_spy:restore()  -- Restore original method

-- Create a simple stub that returns a value
local config_stub = lust.stub({debug = true, version = "1.0"})
local config = config_stub()  -- Returns the stubbed value

-- Create complete mocks of objects
local db_mock = lust.mock(database)

-- Stub methods with implementation functions
db_mock:stub("query", function(query_string)
  expect(query_string).to.match("SELECT")
  return {rows = {{id = 1, name = "Test"}}}
end)

-- Or stub with simple values
db_mock:stub("connect", true)

-- Use argument matchers for flexible verification
local api_mock = lust.mock(api)
api_mock:stub("get_users", {users = {{id = 1, name = "Test"}}})

api.get_users({filter = "active", limit = 10})

-- Verify with powerful argument matchers
expect(api_mock._stubs.get_users:called_with(
  lust.arg_matcher.table_containing({filter = "active"})
)).to.be.truthy()

-- Set expectations with fluent API before calls
api_mock:expect("get_users").with(lust.arg_matcher.any()).to.be.called.times(1)
api_mock:expect("get_user").with(lust.arg_matcher.number()).to.not_be.called()

-- Verify call sequence
expect(api_mock:verify_sequence({
  {method = "get_users", args = {lust.arg_matcher.table()}}
})).to.be.truthy()

-- Use with context manager for automatic cleanup
lust.with_mocks(function(mock)
  local api_mock = mock(api)
  api_mock:stub("get_data", {success = true, items = {}})
  
  -- Test code that uses api.get_data()
  
  -- Verify all expectations
  api_mock:verify_expectations()
  
  -- No need to restore - happens automatically
end)
```

The enhanced mocking system includes:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with test implementations
- **Mocks**: Create complete test doubles with verification
- **Argument Matchers**: Flexible argument matching (`string()`, `number()`, `table_containing()`, etc.)
- **Call Sequence Verification**: Check specific order of method calls
- **Expectation API**: Fluent interface for setting up expectations
- **Call Tracking**: Verify arguments, call counts, and call order
- **Automatic Cleanup**: Restore original functionality after tests

## Installation

### Method 1: Copy the file

Just copy `lust.lua` into your project and require it.

### Method 2: LuaRocks

```bash
luarocks install lust
```

## Usage with Non-Console Environments

If Lua is embedded in an application without ANSI color support:

```lua
local lust = require('lust').nocolor()
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT, see [LICENSE](LICENSE) for details.

## Acknowledgments

Lust-Next builds on the original [lust](https://github.com/bjornbytes/lust) testing framework and takes inspiration from several excellent Lua testing libraries:

- [lunarmodules/busted](https://github.com/lunarmodules/busted) - A powerful, flexible testing framework with rich features
- [lunarmodules/luassert](https://github.com/lunarmodules/luassert) - An extensible assertion library with advanced matching capabilities

We're grateful to these projects for advancing the state of Lua testing and providing inspiration for Lust-Next's enhanced features.
