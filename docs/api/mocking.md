# Mocking API

This document describes the mocking, spying, and stubbing capabilities provided by Lust-Next.

## Overview

Lust-Next provides a comprehensive mocking system for replacing dependencies and verifying interactions during testing. The mocking system includes:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with custom implementations
- **Mocks**: Create complete mock objects with verification
- **Context Management**: Automatically restore original functionality

## Spy Functions

### lust.spy(target, [name], [run])

Creates a spy function or spies on an object method.

**Parameters:**
- `target` (function|table): Function to spy on or table containing method to spy on
- `name` (string, optional): If target is a table, the name of the method to spy on
- `run` (function, optional): Function to run immediately after creating the spy

**Returns:**
- A spy object that tracks calls to the function

**Example:**
```lua
-- Spy on a function
local fn = function(a, b) return a + b end
local spy_fn = lust.spy(fn)
spy_fn(1, 2) -- Calls original function, but tracks the call

-- Spy on an object method
local obj = { method = function(self, arg) return arg end }
local spy_method = lust.spy(obj, "method")
obj:method("test") -- Calls original method, but tracks the call
```

### spy.called

A boolean value indicating whether the spy has been called.

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn()
expect(spy_fn.called).to.be.truthy()
```

### spy.call_count

The number of times the spy has been called.

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn()
spy_fn()
expect(spy_fn.call_count).to.equal(2)
```

### spy.calls

A table containing the arguments passed to each call of the spy.

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn(1, 2)
spy_fn("a", "b")
expect(spy_fn.calls[1][1]).to.equal(1) -- First call, first argument
expect(spy_fn.calls[2][2]).to.equal("b") -- Second call, second argument
```

### spy:called_with(...)

Checks whether the spy was called with the specified arguments.

**Parameters:**
- `...`: The arguments to check for

**Returns:**
- `true` if the spy was called with the specified arguments, `false` otherwise

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn("test", 123)
expect(spy_fn:called_with("test")).to.be.truthy() -- Checks just the first arg
expect(spy_fn:called_with("test", 123)).to.be.truthy() -- Checks both args
expect(spy_fn:called_with("wrong")).to.equal(false)
```

### spy:called_times(n)

Checks whether the spy was called exactly n times.

**Parameters:**
- `n` (number): The expected number of calls

**Returns:**
- `true` if the spy was called exactly n times, `false` otherwise

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn()
spy_fn()
expect(spy_fn:called_times(2)).to.be.truthy()
expect(spy_fn:called_times(3)).to.equal(false)
```

### spy:not_called()

Checks whether the spy was never called.

**Returns:**
- `true` if the spy was never called, `false` otherwise

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

expect(spy_fn:not_called()).to.be.truthy()
spy_fn()
expect(spy_fn:not_called()).to.equal(false)
```

### spy:called_once()

Checks whether the spy was called exactly once.

**Returns:**
- `true` if the spy was called exactly once, `false` otherwise

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn()
expect(spy_fn:called_once()).to.be.truthy()
spy_fn()
expect(spy_fn:called_once()).to.equal(false)
```

### spy:last_call()

Gets the arguments from the most recent call to the spy.

**Returns:**
- A table containing the arguments passed to the most recent call, or nil if the spy was never called

**Example:**
```lua
local fn = function() end
local spy_fn = lust.spy(fn)

spy_fn("first")
spy_fn("second", "arg")
local last_args = spy_fn:last_call()
expect(last_args[1]).to.equal("second")
expect(last_args[2]).to.equal("arg")
```

### spy:restore()

Restores the original function/method if the spy was created for an object method.

**Example:**
```lua
local obj = { method = function() return "original" end }
local spy_method = lust.spy(obj, "method")

expect(obj.method()).to.equal("original") -- Calls through to original
spy_method:restore()
expect(obj.method).to.equal(obj.method) -- Original function is restored
```

## Stub Functions

### lust.stub(return_value_or_implementation)

Creates a standalone stub function that returns a specific value or implements a custom behavior.

**Parameters:**
- `return_value_or_implementation` (any|function): Value to return or function to call when the stub is invoked

**Returns:**
- A stub function that returns the specified value or executes the specified function

**Example:**
```lua
-- Stub with a return value
local get_config = lust.stub({debug = true, timeout = 1000})
local config = get_config() -- Returns {debug = true, timeout = 1000}

-- Stub with a function implementation
local calculate = lust.stub(function(a, b) return a * b end)
local result = calculate(2, 3) -- Returns 6
```

### stub.called, stub.call_count, stub:called_with, etc.

Stubs include all the same tracking and verification methods as spies.

## Mock Objects

### lust.mock(target, [options])

Creates a mock object for the specified target.

**Parameters:**
- `target` (table): The object to mock
- `options` (table, optional): Options for the mock, including:
  - `verify_all_expectations_called` (boolean): If true, verify() will fail if any stubbed methods were not called (default: true)

**Returns:**
- A mock object with methods for stubbing and verification

**Example:**
```lua
local database = {
  connect = function() end,
  query = function() end,
  disconnect = function() end
}

local db_mock = lust.mock(database)
```

### mock:stub(name, implementation_or_value)

Stubs a method on the mock object with a specific implementation or return value.

**Parameters:**
- `name` (string): Name of the method to stub
- `implementation_or_value` (any|function): Function to run when the method is called, or value to return

**Returns:**
- A spy for the stubbed method

**Example:**
```lua
local database = { query = function() end }
local db_mock = lust.mock(database)

-- Stub with a function
db_mock:stub("query", function(query_string)
  return {rows = {{id = 1, name = "test"}}}
end)

-- Stub with a return value
db_mock:stub("connect", {connected = true})
```

### mock:restore_stub(name)

Restores the original implementation of a specific stubbed method.

**Parameters:**
- `name` (string): Name of the method to restore

**Example:**
```lua
local obj = { method = function() return "original" end }
local mock_obj = lust.mock(obj)

mock_obj:stub("method", function() return "stubbed" end)
expect(obj.method()).to.equal("stubbed")

mock_obj:restore_stub("method")
expect(obj.method()).to.equal("original")
```

### mock:restore()

Restores all stubbed methods to their original implementations.

**Example:**
```lua
local obj = {
  method1 = function() return "original1" end,
  method2 = function() return "original2" end
}
local mock_obj = lust.mock(obj)

mock_obj:stub("method1", function() return "stubbed1" end)
mock_obj:stub("method2", function() return "stubbed2" end)

mock_obj:restore()
expect(obj.method1()).to.equal("original1")
expect(obj.method2()).to.equal("original2")
```

### mock:verify()

Verifies that all expectations set on the mock were met.

**Returns:**
- `true` if all expectations were met

**Throws:**
- Error if any stubbed method was not called (when verify_all_expectations_called is true)

**Example:**
```lua
local obj = { method = function() end }
local mock_obj = lust.mock(obj)

mock_obj:stub("method", function() return "stubbed" end)
obj.method() -- Call the stubbed method

-- Verify all stubbbed methods were called
mock_obj:verify() -- Passes because method was called
```

### mock._stubs

A table containing all the stubs created on the mock.

**Example:**
```lua
local obj = { method = function() end }
local mock_obj = lust.mock(obj)

mock_obj:stub("method", function() return "stubbed" end)
obj.method()

expect(mock_obj._stubs.method.called).to.be.truthy()
expect(mock_obj._stubs.method.call_count).to.equal(1)
```

## Context Management

### lust.with_mocks(fn)

Creates a context where mocks are automatically restored when the function exits, even if an error occurs.

**Parameters:**
- `fn` (function): Function to run inside the mock context, receives a mock function as its argument

**Example:**
```lua
local obj = { method = function() return "original" end }

lust.with_mocks(function(mock)
  -- Create mocks inside the context
  local mock_obj = mock(obj)
  mock_obj:stub("method", function() return "stubbed" end)
  
  -- Use the mock
  expect(obj.method()).to.equal("stubbed")
  
  -- No need to restore, happens automatically
end)

-- Outside the context, original method is restored
expect(obj.method()).to.equal("original")
```

## Examples

### Simple Function Stubbing

```lua
describe("Function stubbing", function()
  it("can stub a function to return a fixed value", function()
    -- Create a stub that returns a fixed value
    local getUser = lust.stub({id = 1, name = "John"})
    
    -- Use the stub
    local user = getUser()
    
    -- Verify the stub returned the expected value
    expect(user.id).to.equal(1)
    expect(user.name).to.equal("John")
    
    -- Verify the stub was called
    expect(getUser.called).to.be.truthy()
  end)
end)
```

### Mocking Dependencies

```lua
-- Function under test that uses a dependency
local function process_user(user_service, id)
  local user = user_service.get_user(id)
  if not user then
    return nil
  end
  return {
    display_name = user.first_name .. " " .. user.last_name,
    email = user.email
  }
end

describe("process_user", function()
  it("formats user data correctly", function()
    -- Create a mock user service
    local user_service = {
      get_user = function() end
    }
    
    local mock_service = lust.mock(user_service)
    
    -- Stub the get_user method
    mock_service:stub("get_user", function(id)
      expect(id).to.equal(123) -- Verify correct ID is passed
      return {
        first_name = "John",
        last_name = "Doe",
        email = "john@example.com"
      }
    end)
    
    -- Call the function under test
    local result = process_user(user_service, 123)
    
    -- Verify the result
    expect(result.display_name).to.equal("John Doe")
    expect(result.email).to.equal("john@example.com")
    
    -- Verify the mock was called
    expect(mock_service._stubs.get_user.called).to.be.truthy()
    
    -- Clean up
    mock_service:restore()
  end)
end)
```

### Using the with_mocks Context

```lua
describe("with_mocks context", function()
  it("automatically restores mocks when context ends", function()
    local original_function = function() return "original" end
    local obj = { func = original_function }
    
    -- Create mocks in a context
    lust.with_mocks(function(mock)
      local obj_mock = mock(obj)
      obj_mock:stub("func", function() return "mocked" end)
      
      -- Inside the context, the function is mocked
      expect(obj.func()).to.equal("mocked")
    end)
    
    -- Outside the context, the function is restored
    expect(obj.func).to.equal(original_function)
    expect(obj.func()).to.equal("original")
  end)
  
  it("restores mocks even if an error occurs", function()
    local original_function = function() return "original" end
    local obj = { func = original_function }
    
    -- Create mocks in a context that throws an error
    pcall(function()
      lust.with_mocks(function(mock)
        local obj_mock = mock(obj)
        obj_mock:stub("func", function() return "mocked" end)
        
        -- Throw an error
        error("Test error")
      end)
    end)
    
    -- Even though an error was thrown, the function is restored
    expect(obj.func).to.equal(original_function)
    expect(obj.func()).to.equal("original")
  end)
end)
```

## Best Practices

1. **Restore mocks**: Always restore mocks after using them, or use the `with_mocks` context.

2. **Use minimal stubbing**: Only stub the methods and behavior necessary for your test.

3. **Verify meaningful interactions**: Focus verification on interactions that are relevant to the test.

4. **Avoid complex implementations**: Keep stub implementations simple and deterministic.

5. **Test mock behavior**: Ensure your mocks behave as expected before using them in tests.

6. **Use appropriate mocking approach**:
   - Use spies when you want to verify calls without changing behavior
   - Use stubs when you need to replace functionality
   - Use mocks when you need both replacement and verification