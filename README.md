# Lust - Enhanced Lua Testing Framework

[![CI](https://github.com/greggh/lust/actions/workflows/ci.yml/badge.svg)](https://github.com/greggh/lust/actions/workflows/ci.yml)
[![Documentation](https://github.com/greggh/lust/actions/workflows/docs.yml/badge.svg)](https://github.com/greggh/lust/actions/workflows/docs.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Lust is a lightweight, powerful testing library for Lua projects. This enhanced fork adds significant new functionality while maintaining the simplicity and elegance of the original.

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
lust.tags("unit", "math")
it("adds numbers correctly", function()
  expect(1 + 1).to.equal(2)
end)

-- In your test runner:
lust.only_tags("unit")()
```

#### Async Testing

Test asynchronous code with await/async:

```lua
it("tests async code", lust.async(function()
  local result = callAsyncFunction()
  lust.await(100) -- Wait 100ms
  expect(result).to.equal("expected result")
end))
```

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
