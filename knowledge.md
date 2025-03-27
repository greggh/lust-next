# Firmo Knowledge

## Project Overview

- Enhanced Lua testing framework with BDD-style nested test blocks
- Provides comprehensive testing capabilities including assertions, mocking, coverage analysis
- Currently in alpha state - not for production use unless helping with development

## Minimal Test Example

```lua
local firmo = require('firmo')
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe('Calculator', function()
  before(function()
    -- Setup runs before each test
  end)

  it('adds numbers correctly', function()
    expect(2 + 2).to.equal(4)
  end)

  it('handles errors properly', { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return divide(1, 0)
    end)()
    expect(err).to.exist()
    expect(err.message).to.match("divide by zero")
  end)
end)
```

## Critical Rules

### Configuration System

- ALWAYS use central_config module for settings
- NEVER create custom configuration systems
- NEVER hardcode paths or patterns
- NEVER remove existing config integration
- Use .firmo-config.lua for project-wide settings

### Special Case Code Policy

- NEVER add special case code for specific files/situations
- NO file-specific logic or hardcoded paths
- NO workarounds - fix root causes
- NO specialized handling for specific cases
- Solutions must be general purpose and work for all files

### Coverage Module Rules

- NEVER import coverage module in test files
- NEVER manually set coverage status
- NEVER create test-specific workarounds
- NEVER manipulate coverage data directly
- ALWAYS run tests properly via test.lua

## Essential Commands

- Run all tests: `lua test.lua tests/`
- Run specific test: `lua test.lua tests/reporting_test.lua`
- Run with pattern: `lua test.lua --pattern=coverage tests/`
- Run with coverage: `lua test.lua --coverage --format=html tests/`
- Run with coverage (JSON): `lua test.lua --coverage --format=json tests/`
- Run with coverage (LCOV): `lua test.lua --coverage --format=lcov tests/`
- Run with watch mode: `lua test.lua --watch tests/`

## JSDoc-Style Type Annotations

CRITICAL: Any code changes MUST include updates to affected JSDoc annotations.

Example:

```lua
---@class ModuleName
---@field function_name fun(param: type): return_type Description 
---@field another_function fun(param1: type, param2?: type): return_type|nil, error? Description
local M = {}

--- Description of what the function does
---@param name type Description of the parameter
---@param optional_param? type Description of the optional parameter
---@return type Description of what the function returns
function M.function_name(name, optional_param)
  -- Implementation
end
```

## Error Handling Diagnostic Patterns

```lua
-- pcall Pattern
---@diagnostic disable-next-line: unused-local
local ok, err = pcall(function()
  return some_operation()
end)

-- error_handler.try Pattern
---@diagnostic disable-next-line: unused-local
local success, result, err = error_handler.try(function()
  return some_operation()
end)

-- Table Access Without nil Check
---@diagnostic disable-next-line: need-check-nil
local value = table[key]
```

## Lua Compatibility

- ALWAYS use table unpacking compatibility:
  
  ```lua
  local unpack_table = table.unpack or unpack
  ```
- Use # operator for table length:
  
  ```lua
  local length = #my_table  -- Correct
  local length = table.getn(my_table)  -- Incorrect, deprecated
  ```

## Assertion Style Guide

```lua
-- CORRECT: firmo expect-style assertions
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
expect(value).to.match("pattern")
expect(fn).to.fail()

-- INCORRECT: busted-style assert assertions
assert.is_not_nil(value)         -- wrong
assert.equals(expected, actual)  -- wrong
```

## Extended Assertions

```lua
-- Collection assertions
expect("hello").to.have_length(5)
expect({1, 2, 3}).to.have_length(3)
expect({}).to.be.empty()

-- Numeric assertions
expect(5).to.be.positive()
expect(-5).to.be.negative()
expect(10).to.be.integer()

-- String assertions
expect("HELLO").to.be.uppercase()
expect("hello").to.be.lowercase()

-- Object assertions
expect({name = "John"}).to.have_property("name")
expect({name = "John"}).to.have_property("name", "John")
```

## Error Testing Best Practices

1. ALWAYS use expect_error flag when the test expects and error and that error is a passing test:
   
   ```lua
   it("test description", { expect_error = true }, function()
   local result, err = test_helper.with_error_capture(function()
    return function_that_throws()
   end)()
   expect(err).to.exist()
   expect(err.message).to.match("pattern")
   end)
   ```

2. ALWAYS use test_helper.with_error_capture() when the test expects and error and that error is a passing test.

3. Be flexible with error categories

4. Use pattern matching for messages

5. Test for existence first

6. Handle both error patterns (nil,error and false)

7. Clean up resources properly

8. Document expected error behavior

## Documentation Links

- Tasks: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/tasks/firmo-tasks.md`
- Architecture: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/plans/firmo-architecture.md`
- Project Status: `/home/gregg/Projects/docs-projects/neovim-ecosystem-docs/project-status.md`