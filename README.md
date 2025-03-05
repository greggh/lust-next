# Lust-Next - Enhanced Lua Testing Framework

[![CI](https://github.com/greggh/lust-next/actions/workflows/ci.yml/badge.svg)](https://github.com/greggh/lust-next/actions/workflows/ci.yml)
[![Documentation](https://github.com/greggh/lust-next/actions/workflows/docs.yml/badge.svg)](https://github.com/greggh/lust-next/actions/workflows/docs.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Lust-Next is a lightweight, powerful testing library for Lua projects. This enhanced fork of [lust](https://github.com/bjornbytes/lust) adds significant new functionality while maintaining the simplicity and elegance of the original.

## Features

- **Minimal Dependencies**: Single file with no external requirements
- **Familiar Syntax**: BDD-style `describe`/`it` blocks for intuitive test organization  
- **Rich Assertions**: Extensive expect-style assertion library
- **Function Spies**: Track function calls and arguments
- **Before/After Hooks**: For setup and teardown
- **Automatic Test Discovery**: Find and run tests without manual configuration
- **Filtering & Tagging**: Run specific test groups or tagged tests
- **Enhanced Reporting**: Clear, colorful summaries of test results
- **Async Support**: Test asynchronous code with ease
- **Mocking System**: Create and manage mocks for dependencies
- **Cross-Platform**: Works in console and non-console environments

## Quick Start

Copy the `lust.lua` file to your project and require it:

```lua
local lust = require 'lust'
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

## Documentation

### Core Functions

#### `lust.describe(name, func)`

Used to declare a group of tests. Groups created using `describe` can be nested.

```lua
describe("math operations", function()
  -- Tests go here
end)
```

#### `lust.it(name, func)`

Used to declare a test, which consists of a set of assertions.

```lua
it("adds two numbers correctly", function()
  expect(2 + 2).to.equal(4)
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

#### Automatic Test Discovery

Automatically find and run all test files:

```lua
-- Run all test files in the current directory and subdirectories
lust.run_discovered(".")
```

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
```

Key async features:

- `lust.async(fn, timeout)` - Wraps a function to be executed asynchronously
- `lust.it_async(name, fn, timeout)` - Shorthand for async tests
- `lust.await(ms)` - Waits for the specified time in milliseconds
- `lust.wait_until(condition_fn, timeout, check_interval)` - Waits until a condition function returns true
- `lust.set_timeout(ms)` - Sets the default timeout for async tests

#### Mocking

Create and manage mocks:

```lua
lust.with_mocks(function(mock)
  local db = mock(database, "query", function() return {rows = {}} end)
  local result = myFunction()
  expect(db:called()).to.be.truthy()
  expect(db:called_with("SELECT * FROM users")).to.be.truthy()
end)
```

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
