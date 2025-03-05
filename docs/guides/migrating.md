# Migrating from lust to lust-next

This guide helps users of the original [lust](https://github.com/bjornbytes/lust) testing framework migrate to lust-next, which adds significant new functionality while maintaining backward compatibility.

## Overview of Differences

Lust-next is a direct enhancement of the original lust, maintaining all existing functionality while adding numerous new features:

| Aspect | Original lust | lust-next |
|--------|--------------|-----------|
| Core functions | describe, it, expect | Same core functions + additional variants |
| Assertions | Basic assertions | Enhanced assertions + custom assertion support |
| Setup/Teardown | before/after | Same + more flexible hooks |
| Mocking | Basic spies | Comprehensive mocking system with spies, stubs, mocks |
| Filtering | None | Tagging and filtering system |
| Async Testing | None | Complete async testing support |
| Focused Tests | None | fdescribe/fit for focusing tests |
| Excluded Tests | None | xdescribe/xit for excluding tests |
| Output formats | Basic | Multiple output formats (normal, dot, compact, summary) |
| Test discovery | None | Automatic test discovery |
| CLI support | None | Comprehensive CLI with filtering options |

## Step-by-Step Migration

### 1. Installation

**Original lust:**
```lua
-- Copy lust.lua to your project
local lust = require 'lust'
```

**lust-next:**
```lua
-- Copy lust-next.lua to your project
local lust = require 'lust-next'  -- You can keep the original require name
```

### 2. Update Core Testing Patterns

The basic structure of tests remains the same, so most tests should work without modification:

```lua
local lust = require 'lust-next'
local describe, it, expect = lust.describe, lust.it, lust.expect

describe("My test suite", function()
  it("tests something", function()
    expect(1 + 1).to.equal(2)
  end)
end)
```

### 3. Take Advantage of Enhanced Assertions

lust-next includes many new assertion types that make tests more expressive:

**Original lust:**
```lua
-- Basic assertions
expect(x).to.exist()
expect(x).to.equal(y)
expect(x).to.be(y)
expect(x).to.be.truthy()
expect(x).to.be.a(y)
expect(x).to.have(y)
expect(f).to.fail()
```

**lust-next:**
```lua
-- Enhanced table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.keys({"id", "name", "email"})
expect(table).to.contain.value("example")
expect(small_table).to.contain.subset(big_table)

-- Enhanced string assertions
expect(str).to.start_with("hello")
expect(str).to.end_with("world")

-- Enhanced numeric assertions
expect(value).to.be_greater_than(minimum)
expect(value).to.be_between(min, max)
expect(value).to.be_approximately(target, delta)

-- Enhanced error assertions
expect(function_that_throws).to.throw.error_matching("pattern")
expect(function_that_throws).to.throw.error_type("string")
```

### 4. Upgrade Your Mocking Strategy

The enhanced mocking system is one of the most significant improvements:

**Original lust:**
```lua
-- Basic spy in original lust
local spy = lust.spy(myFunction)
spy(1, 2, 3)
expect(#spy).to.equal(1)
expect(spy[1][1]).to.equal(1)
```

**lust-next:**
```lua
-- Enhanced spy with better API
local spy = lust.spy(myFunction)
spy(1, 2, 3)
expect(spy.called).to.be.truthy()
expect(spy.call_count).to.equal(1)
expect(spy:called_with(1, 2, 3)).to.be.truthy()

-- Complete mocks of objects
local db_mock = lust.mock(database)

-- Stub methods with implementation functions
db_mock:stub("query", function(query_string)
  expect(query_string).to.match("SELECT")
  return {rows = {{id = 1, name = "Test"}}}
end)

-- Set expectations with fluent API
db_mock:expect("get_users").with(lust.arg_matcher.any()).to.be.called.times(1)
```

### 5. Implement Focused and Excluded Tests

Use focused and excluded tests to run specific subsets of your test suite:

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

### 6. Add Async Testing Support

For code that is asynchronous, use the new async testing support:

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
```

### 7. Implement Test Tagging and Filtering

Organize your tests with tags and filters:

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

-- Command line filtering
-- lua lust-next.lua --tags unit,math
-- lua lust-next.lua --filter "addition"
```

## Code Examples: Before and After

### Example 1: Basic Test Structure

**Original lust:**
```lua
local lust = require 'lust'
local describe, it, expect = lust.describe, lust.it, lust.expect

describe('math', function()
  it('addition', function()
    expect(1 + 1).to.equal(2)
  end)
  
  it('subtraction', function()
    expect(5 - 3).to.equal(2)
  end)
end)
```

**lust-next:** (Unchanged - backwards compatible)
```lua
local lust = require 'lust-next'
local describe, it, expect = lust.describe, lust.it, lust.expect

describe('math', function()
  it('addition', function()
    expect(1 + 1).to.equal(2)
  end)
  
  it('subtraction', function()
    expect(5 - 3).to.equal(2)
  end)
end)
```

### Example 2: Using Enhanced Assertions

**Original lust:**
```lua
describe('user', function()
  it('validates user data', function()
    local user = {id = 1, name = "Test", email = "test@example.com"}
    expect(user.id).to.be.a('number')
    expect(user.name).to.be.a('string')
    expect(user.name).to.equal("Test")
    -- Limited assertions available
  end)
end)
```

**lust-next:**
```lua
describe('user', function()
  it('validates user data', function()
    local user = {id = 1, name = "Test", email = "test@example.com"}
    
    -- Enhanced assertions
    expect(user).to.contain.keys({"id", "name", "email"})
    expect(user.id).to.be_greater_than(0)
    expect(user.name).to.start_with("T")
    expect(user.email).to.match("@example%.com$")
  end)
end)
```

### Example 3: Mocking

**Original lust:**
```lua
describe('database', function()
  it('queries data', function()
    local db = {
      query = function(sql) return {id = 1, name = "Test"} end
    }
    
    local querySpy = lust.spy(db.query)
    db.query = querySpy
    
    local result = db.query("SELECT * FROM users")
    expect(#querySpy).to.equal(1)
    expect(querySpy[1][1]).to.equal("SELECT * FROM users")
  end)
end)
```

**lust-next:**
```lua
describe('database', function()
  it('queries data', function()
    local db = {
      query = function(sql) return {id = 1, name = "Test"} end
    }
    
    local db_mock = lust.mock(db)
    db_mock:stub("query", function(sql)
      expect(sql).to.match("SELECT")
      return {id = 1, name = "Test"}
    end)
    
    local result = db.query("SELECT * FROM users")
    
    expect(db_mock._stubs.query.called).to.be.truthy()
    expect(db_mock._stubs.query:called_with("SELECT * FROM users")).to.be.truthy()
    expect(db_mock._stubs.query.call_count).to.equal(1)
  end)
end)
```

## Common Migration Issues and Solutions

### Issue 1: Spy Usage Changes

**Problem:** The spy API in lust-next has been enhanced and differs from the original.

**Solution:** Update spy usages to use the new properties:
```lua
-- Old style
expect(#spy).to.equal(1)
expect(spy[1][1]).to.equal("arg")

-- New style
expect(spy.call_count).to.equal(1)
expect(spy.calls[1][1]).to.equal("arg")
-- or
expect(spy:called_with("arg")).to.be.truthy()
```

### Issue 2: New Features Causing Confusion

**Problem:** New features like focused tests might cause unexpected behavior.

**Solution:** Be aware that using `fdescribe` or `fit` will cause only focused tests to run. Remove these when you want to run all tests again.

### Issue 3: Output Format Changes

**Problem:** Test output format looks different from the original lust.

**Solution:** Configure the output format to your liking:
```lua
lust.format({
  use_color = true,          -- Whether to use color codes
  indent_char = '  ',        -- Character for indentation
  indent_size = 2,           -- Indentation size
  show_trace = false,        -- Show stack traces
  show_success_detail = true, -- Show details for successes
  compact = false,           -- Use compact format
  dot_mode = false,          -- Use dot mode
  summary_only = false       -- Show only summary
})

-- Or use the basic mode
lust.format({ compact = true })
```

### Issue 4: Test Discovery and Command-Line Options

**Problem:** Running tests from the command line works differently.

**Solution:** Use the new CLI options:
```bash
# Run all tests in a directory
lua lust-next.lua --dir ./tests

# Run specific test files
lua lust-next.lua --file test1.lua --file test2.lua

# Run with specific tags
lua lust-next.lua --tags unit,fast

# Run with specific output format
lua lust-next.lua --format dot
```

## Feature Comparison Table

| Feature | Original lust | lust-next |
|---------|--------------|-----------|
| **Core Testing** | | |
| describe/it blocks | ✅ | ✅ |
| before/after hooks | ✅ | ✅ |
| **Assertions** | | |
| Basic assertions (.exist, .equal, etc.) | ✅ | ✅ |
| Table assertions (.contains.key, etc.) | ❌ | ✅ |
| String assertions (.start_with, etc.) | ❌ | ✅ |
| Numeric assertions (.be_greater_than, etc.) | ❌ | ✅ |
| Error assertions (.throw.error_matching, etc.) | ❌ | ✅ |
| Custom assertions | ❌ | ✅ |
| **Mocking** | | |
| Function spies | ✅ (basic) | ✅ (enhanced) |
| Method stubs | ❌ | ✅ |
| Complete mock objects | ❌ | ✅ |
| Argument matchers | ❌ | ✅ |
| Call sequence verification | ❌ | ✅ |
| **Test Organization** | | |
| Nested describe blocks | ✅ | ✅ |
| Focused tests (fdescribe/fit) | ❌ | ✅ |
| Excluded tests (xdescribe/xit) | ❌ | ✅ |
| Test tagging | ❌ | ✅ |
| Test filtering | ❌ | ✅ |
| **Async Testing** | | |
| async/await support | ❌ | ✅ |
| Timeouts and delays | ❌ | ✅ |
| Conditional waiting | ❌ | ✅ |
| **Reporting** | | |
| Colored output | ✅ | ✅ |
| Multiple output formats | ❌ | ✅ |
| Detailed failure messages | ❌ | ✅ |
| Test summaries | ❌ | ✅ |
| **Usability** | | |
| Test discovery | ❌ | ✅ |
| Command-line interface | ❌ | ✅ |
| Configuration options | ❌ | ✅ |

## Conclusion

Migrating from lust to lust-next should be a smooth process for most users. Since lust-next is fully backward compatible, you can gradually adopt new features as needed. The enhancements provide significant improvements to test organization, assertion capabilities, and mocking functionality, making your tests more expressive and maintainable.

For more information, consult the [API Reference](../api/README.md) and [Example Files](../../examples).