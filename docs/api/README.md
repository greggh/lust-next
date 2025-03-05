# Lust-Next API Reference

This section contains detailed API documentation for all Lust-Next functionality.

## Table of Contents

- [Core Functions](core.md) - Essential test functions (`describe`, `it`, etc.)
- [Assertions](assertions.md) - Assertion functions for test verification
- [Async Testing](async.md) - APIs for testing asynchronous code
- [Mocking](mocking.md) - Mocking, spying, and stubbing capabilities
- [Test Filtering](filtering.md) - Test filtering and tagging support
- [CLI](cli.md) - Command-line interface and options
- [Test Discovery](discovery.md) - Automatic test discovery capabilities

## API Overview

Lust-Next provides a comprehensive API for testing Lua code. The API is designed to be simple, intuitive, and powerful.

### Core Functions

```lua
-- Define a test group
lust.describe("Group name", function()
  -- Define a test
  lust.it("Test name", function()
    -- Test code here
  end)
end)

-- Setup and teardown
lust.before(function() -- Run before each test end)
lust.after(function() -- Run after each test end)
```

### Assertions

```lua
-- Basic assertions
expect(value).to.exist()
expect(value).to.equal(expected)
expect(value).to.be.truthy()

-- Table assertions
expect(table).to.contain.key("id")
expect(table).to.contain.values({"a", "b"})

-- String assertions
expect(str).to.start_with("prefix")
```

### Async Testing

```lua
-- Async test
lust.it_async("Async test", function()
  local result = nil
  lust.await(100) -- Wait 100ms
  expect(result).to.exist()
end)
```

### Mocking

```lua
-- Create a mock
local mock_obj = lust.mock(dependencies)
mock_obj:stub("method", function() return "mocked" end)

-- Create a spy
local spy = lust.spy(function() end)
```

See the individual sections for detailed documentation on each API area.