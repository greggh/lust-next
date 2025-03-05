# Getting Started with Lust-Next

This guide will help you get started with Lust-Next, a lightweight and powerful testing framework for Lua.

## Installation

### Method 1: Copy the File

The simplest way to use Lust-Next is to copy the `lust-next.lua` file directly into your project.

1. Download the `lust-next.lua` file from the repository
2. Place it in your project directory or in a lib/vendor directory

### Method 2: LuaRocks (Coming Soon)

```bash
luarocks install lust-next
```

## Basic Usage

### 1. Create Your First Test File

Create a file named `example_test.lua` with the following content:

```lua
-- Require the Lust-Next library
local lust = require("lust-next")

-- Import the core functions
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Define a test suite
describe("Math operations", function()
  
  -- Define a test
  it("adds two numbers correctly", function()
    expect(1 + 1).to.equal(2)
  end)
  
  -- Define another test
  it("subtracts two numbers correctly", function()
    expect(5 - 3).to.equal(2)
  end)
  
  -- Test for errors
  it("raises an error when dividing by zero", function()
    expect(function() 
      return 5 / 0 
    end).to.fail()
  end)
  
end)
```

### 2. Run the Test

Run the test using the Lua interpreter:

```bash
lua example_test.lua
```

You should see output similar to:

```
Math operations
	PASS adds two numbers correctly
	PASS subtracts two numbers correctly
	PASS raises an error when dividing by zero
```

## Writing Tests

### Test Structure

Lust-Next uses a BDD-style syntax with describe and it blocks:

- `describe(name, fn)`: Groups related tests
- `it(name, fn)`: Defines an individual test
- `expect(value)`: Creates assertions about a value

### Assertions

Lust-Next provides a rich set of assertions:

```lua
-- Basic assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()
expect(value).to.be.a("string")

-- Table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.value("example")

-- String assertions
expect(str).to.start_with("hello")
expect(str).to.end_with("world")

-- Numeric assertions
expect(num).to.be_greater_than(5)
expect(num).to.be_approximately(0.3, 0.0001)

-- Error assertions
expect(function() error("oops") end).to.fail()
expect(function() error("invalid") end).to.throw.error_matching("invalid")
```

### Before and After Hooks

You can use `before` and `after` hooks for setup and teardown:

```lua
describe("Database tests", function()
  local db
  
  before(function()
    -- Set up database connection before each test
    db = Database.connect()
  end)
  
  it("queries data", function()
    local result = db:query("SELECT * FROM users")
    expect(#result).to.be_greater_than(0)
  end)
  
  after(function()
    -- Clean up after each test
    db:disconnect()
  end)
end)
```

## Organizing Tests

### Nested Describe Blocks

You can nest `describe` blocks to organize your tests:

```lua
describe("User module", function()
  describe("Authentication", function()
    it("logs in valid users", function()
      -- Test code
    end)
    
    it("rejects invalid credentials", function()
      -- Test code
    end)
  end)
  
  describe("Profile", function()
    it("updates user information", function()
      -- Test code
    end)
  end)
end)
```

### Tagging Tests

You can add tags to your tests for filtering:

```lua
describe("User module", function()
  lust.tags("unit")
  
  it("validates username format", function()
    -- Fast unit test
  end)
  
  lust.tags("integration", "slow")
  it("stores user in database", function()
    -- Slower integration test
  end)
end)
```

## Running Tests

### Running a Single Test File

```bash
lua example_test.lua
```

### Running Multiple Test Files

Create a directory for your tests (e.g., `tests`) and use Lust-Next's test discovery:

```bash
lua lust-next.lua --dir ./tests
```

### Filtering Tests

Run only tests with specific tags:

```bash
lua lust-next.lua --tags unit
```

Run only tests matching a pattern:

```bash
lua lust-next.lua --filter authentication
```

## Asynchronous Testing

For testing asynchronous code, use the async testing support:

```lua
lust.it_async("fetches data asynchronously", function()
  local result = nil
  
  -- Start async operation
  fetchData(function(data) 
    result = data
  end)
  
  -- Wait for operation to complete
  lust.wait_until(function() return result ~= nil end)
  
  -- Make assertions on the result
  expect(result).to.exist()
  expect(result.status).to.equal("success")
end)
```

## Mocking

For isolating your tests, use the mocking system:

```lua
-- Create a mock database
local db_mock = lust.mock(database)

-- Stub methods with test implementations
db_mock:stub("query", function(query_string)
  return {
    rows = {{id = 1, name = "test"}}
  }
end)

-- Test code that uses the database
local users = UserService.get_users()

-- Verify the mock was called correctly
expect(db_mock._stubs.query.called).to.be.truthy()

-- Restore original methods
db_mock:restore()
```

## Next Steps

Now that you understand the basics of Lust-Next, you can:

1. Explore the [API Reference](../api/README.md) for detailed documentation
2. Look at the [Examples](../../examples) directory for more complex examples
3. Check out [Advanced Topics](../guides/advanced-topics.md) for advanced features

Happy testing!