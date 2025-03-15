# Mocking API
This document describes the mocking, spying, and stubbing capabilities provided by Firmo.

## Overview
Firmo provides a comprehensive mocking system for replacing dependencies and verifying interactions during testing. The mocking system includes:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with custom implementations
- **Mocks**: Create complete mock objects with verification
- **Argument Matchers**: Flexible argument matching (`string()`, `number()`, `table_containing()`, etc.)
- **Call Sequence Verification**: Check specific order of method calls
- **Expectation API**: Fluent interface for setting up expectations
- **Context Management**: Automatically restore original functionality

## Spy Functions

### firmo.spy(target, [name], [run])
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
local spy_fn = firmo.spy(fn)
spy_fn(1, 2) -- Calls original function, but tracks the call
-- Spy on an object method
local obj = { method = function(self, arg) return arg end }
local spy_method = firmo.spy(obj, "method")
obj:method("test") -- Calls original method, but tracks the call

```text

### spy.called
A boolean value indicating whether the spy has been called.
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
expect(spy_fn.called).to.be.truthy()

```text

### spy.call_count
The number of times the spy has been called.
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
spy_fn()
expect(spy_fn.call_count).to.equal(2)

```text

### spy.calls
A table containing the arguments passed to each call of the spy.
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn(1, 2)
spy_fn("a", "b")
expect(spy_fn.calls[1][1]).to.equal(1) -- First call, first argument
expect(spy_fn.calls[2][2]).to.equal("b") -- Second call, second argument

```text

### spy:called_with(...)
Checks whether the spy was called with the specified arguments.
**Parameters:**

- `...`: The arguments to check for
**Returns:**

- `true` if the spy was called with the specified arguments, `false` otherwise
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("test", 123)
expect(spy_fn:called_with("test")).to.be.truthy() -- Checks just the first arg
expect(spy_fn:called_with("test", 123)).to.be.truthy() -- Checks both args
expect(spy_fn:called_with("wrong")).to.equal(false)

```text

### spy:called_times(n)
Checks whether the spy was called exactly n times.
**Parameters:**

- `n` (number): The expected number of calls
**Returns:**

- `true` if the spy was called exactly n times, `false` otherwise
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
spy_fn()
expect(spy_fn:called_times(2)).to.be.truthy()
expect(spy_fn:called_times(3)).to.equal(false)

```text

### spy:not_called()
Checks whether the spy was never called.
**Returns:**

- `true` if the spy was never called, `false` otherwise
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
expect(spy_fn:not_called()).to.be.truthy()
spy_fn()
expect(spy_fn:not_called()).to.equal(false)

```text

### spy:called_once()
Checks whether the spy was called exactly once.
**Returns:**

- `true` if the spy was called exactly once, `false` otherwise
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn()
expect(spy_fn:called_once()).to.be.truthy()
spy_fn()
expect(spy_fn:called_once()).to.equal(false)

```text

### spy:called_before(other_spy, [call_index])
Checks whether any call to this spy happened before a specific call to another spy.
**Parameters:**

- `other_spy` (spy): Another spy to compare with
- `call_index` (number, optional): The index of the call to check on the other spy (default: 1)
**Returns:**

- `true` if any call to this spy happened before the specified call to the other spy, `false` otherwise
**Example:**

```lua
local fn1 = function() end
local fn2 = function() end
local spy1 = firmo.spy(fn1)
local spy2 = firmo.spy(fn2)
spy1() -- Called first
spy2() -- Called second
expect(spy1:called_before(spy2)).to.be.truthy()
expect(spy2:called_before(spy1)).to.equal(false)

```text

### spy:called_after(other_spy, [call_index])
Checks whether any call to this spy happened after a specific call to another spy.
**Parameters:**

- `other_spy` (spy): Another spy to compare with
- `call_index` (number, optional): The index of the call to check on the other spy (default: last call)
**Returns:**

- `true` if any call to this spy happened after the specified call to the other spy, `false` otherwise
**Example:**

```lua
local fn1 = function() end
local fn2 = function() end
local spy1 = firmo.spy(fn1)
local spy2 = firmo.spy(fn2)
spy1() -- Called first
spy2() -- Called second
expect(spy2:called_after(spy1)).to.be.truthy()
expect(spy1:called_after(spy2)).to.equal(false)

```text

### spy:has_calls_with(...)
Checks whether the spy has any calls that match the specified pattern of arguments.
**Parameters:**

- `...`: The argument pattern to check for (can include matchers)
**Returns:**

- `true` if any call matches the pattern, `false` otherwise
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("test", 123)
spy_fn(456, "example")
expect(spy_fn:has_calls_with("test")).to.be.truthy()
expect(spy_fn:has_calls_with(456)).to.be.truthy()
expect(spy_fn:has_calls_with("missing")).to.equal(false)

```text

### spy:last_call()
Gets the arguments from the most recent call to the spy.
**Returns:**

- A table containing the arguments passed to the most recent call, or nil if the spy was never called
**Example:**

```lua
local fn = function() end
local spy_fn = firmo.spy(fn)
spy_fn("first")
spy_fn("second", "arg")
local last_args = spy_fn:last_call()
expect(last_args[1]).to.equal("second")
expect(last_args[2]).to.equal("arg")

```text

### spy:restore()
Restores the original function/method if the spy was created for an object method.
**Example:**

```lua
local obj = { method = function() return "original" end }
local spy_method = firmo.spy(obj, "method")
expect(obj.method()).to.equal("original") -- Calls through to original
spy_method:restore()
expect(obj.method).to.equal(obj.method) -- Original function is restored

```text

## Stub Functions

### firmo.stub(return_value_or_implementation)
Creates a standalone stub function that returns a specific value or implements a custom behavior.
**Parameters:**

- `return_value_or_implementation` (any|function): Value to return or function to call when the stub is invoked
**Returns:**

- A stub function that returns the specified value or executes the specified function
**Example:**

```lua
-- Stub with a return value
local get_config = firmo.stub({debug = true, timeout = 1000})
local config = get_config() -- Returns {debug = true, timeout = 1000}
-- Stub with a function implementation
local calculate = firmo.stub(function(a, b) return a * b end)
local result = calculate(2, 3) -- Returns 6
-- Stub with sequential return values
local status = firmo.stub(nil):returns_in_sequence({"starting", "in_progress", "complete"})
status() -- Returns "starting"
status() -- Returns "in_progress"
status() -- Returns "complete"
status() -- Returns nil (sequence exhausted)

```text

### stub:returns_in_sequence(values)
Sets up a stub to return different values on successive calls.
**Parameters:**

- `values` (table): Array of values to return in sequence on successive calls
**Returns:**

- A new stub that returns values in sequence
**Example:**

```lua
local counter = firmo.stub("initial"):returns_in_sequence({
  1,
  2,
  3,
  function() return 4 * 2 end -- Can include dynamic functions
})
counter() -- Returns 1
counter() -- Returns 2
counter() -- Returns 3
counter() -- Returns 8 (from function call)
counter() -- Returns nil (sequence exhausted)

```text

### stub:cycle_sequence(enable)
Configures a stub with sequential return values to cycle through the values after reaching the end of the sequence.
**Parameters:**

- `enable` (boolean, optional): Whether to enable cycling (default: true)
**Returns:**

- The stub object for method chaining
**Example:**

```lua
local light = firmo.stub():returns_in_sequence({"red", "yellow", "green"}):cycle_sequence()
light() -- Returns "red"
light() -- Returns "yellow"
light() -- Returns "green"
light() -- Returns "red" (cycles back to beginning)
light() -- Returns "yellow"

```text

### stub:when_exhausted(behavior, [custom_value])
Configures what happens when a sequence of return values is exhausted.
**Parameters:**

- `behavior` (string): One of:
  - `"nil"`: Return nil (default behavior)
  - `"fallback"`: Fall back to the original implementation
  - `"custom"`: Return a custom value
- `custom_value` (any, optional): Value to return when behavior is "custom"
**Returns:**

- The stub object for method chaining
**Example:**

```lua
-- Return a custom error object when exhausted
local api = firmo.stub():returns_in_sequence({
  { status = "success", data = "first" },
  { status = "success", data = "second" }
}):when_exhausted("custom", { status = "error", message = "No more data" })
api() -- Returns { status = "success", data = "first" }
api() -- Returns { status = "success", data = "second" }
api() -- Returns { status = "error", message = "No more data" }
-- Fall back to original implementation when exhausted
local obj = { get_data = function() return "original" end }
local mock_obj = firmo.mock(obj)
mock_obj:stub_in_sequence("get_data", {"mocked"})
  :when_exhausted("fallback")
obj.get_data() -- Returns "mocked"
obj.get_data() -- Returns "original" (falls back)

```text

### stub:reset_sequence()
Resets a sequence stub to start returning values from the beginning of the sequence again.
**Returns:**

- The stub object for method chaining
**Example:**

```lua
local counter = firmo.stub():returns_in_sequence({1, 2, 3})
counter() -- Returns 1
counter() -- Returns 2
counter() -- Returns 3
counter() -- Returns nil (exhausted)
counter:reset_sequence() -- Reset to start from beginning
counter() -- Returns 1 again
counter() -- Returns 2 again

```text
**Chain Configuration Example:**

```lua
-- Configure multiple behaviors in a single chain
local api = firmo.stub()
  :returns_in_sequence({"pending", "processing", "complete"})
  :cycle_sequence(true)
  :when_exhausted("custom", "error")
api() -- Returns "pending"
api() -- Returns "processing"
api() -- Returns "complete"
api() -- Returns "pending" (cycles)

```text

### stub.called, stub.call_count, stub:called_with, etc.
Stubs include all the same tracking and verification methods as spies.

## Mock Objects

### firmo.mock(target, [options])
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
local db_mock = firmo.mock(database)

```text

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
local db_mock = firmo.mock(database)
-- Stub with a function
db_mock:stub("query", function(query_string)
  return {rows = {{id = 1, name = "test"}}}
end)
-- Stub with a return value
db_mock:stub("connect", {connected = true})

```text

### mock:stub_in_sequence(name, sequence_values)
Stubs a method on the mock object to return different values on successive calls.
**Parameters:**

- `name` (string): Name of the method to stub
- `sequence_values` (table): Array of values to return in sequence on successive calls
**Returns:**

- The mock object for method chaining
**Example:**

```lua
local api = { get_status = function() return "online" end }
local mock_api = firmo.mock(api)
-- Stub with sequential return values
mock_api:stub_in_sequence("get_status", {
  "starting",
  "connecting",
  "online",
  "disconnecting"
})
-- Each call returns the next value in sequence
api.get_status() -- Returns "starting"
api.get_status() -- Returns "connecting"
api.get_status() -- Returns "online"
api.get_status() -- Returns "disconnecting"
api.get_status() -- Returns nil (sequence exhausted)
-- Can combine with functions for dynamic values
mock_api:stub_in_sequence("get_status", {
  "online",
  function() return "error: " .. os.time() end,
  "reconnected"
})

```text

### mock:restore_stub(name)
Restores the original implementation of a specific stubbed method.
**Parameters:**

- `name` (string): Name of the method to restore
**Example:**

```lua
local obj = { method = function() return "original" end }
local mock_obj = firmo.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
expect(obj.method()).to.equal("stubbed")
mock_obj:restore_stub("method")
expect(obj.method()).to.equal("original")

```text

### mock:restore()
Restores all stubbed methods to their original implementations.
**Example:**

```lua
local obj = {
  method1 = function() return "original1" end,
  method2 = function() return "original2" end
}
local mock_obj = firmo.mock(obj)
mock_obj:stub("method1", function() return "stubbed1" end)
mock_obj:stub("method2", function() return "stubbed2" end)
mock_obj:restore()
expect(obj.method1()).to.equal("original1")
expect(obj.method2()).to.equal("original2")

```text

### mock:verify()
Verifies that all expectations set on the mock were met.
**Returns:**

- `true` if all expectations were met
**Throws:**

- Error if any stubbed method was not called (when verify_all_expectations_called is true)
**Example:**

```lua
local obj = { method = function() end }
local mock_obj = firmo.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
obj.method() -- Call the stubbed method
-- Verify all stubbbed methods were called
mock_obj:verify() -- Passes because method was called

```text

### mock:verify_sequence(expected_sequence)
Verifies that methods were called in a specific sequence.
**Parameters:**

- `expected_sequence` (table): Array of method call descriptors with format: `{method = "name", args = {arg1, arg2, ...}}`
**Returns:**

- `true` if the methods were called in the expected sequence
**Throws:**

- Error with details about the mismatch if the actual sequence differs from the expected sequence
**Example:**

```lua
local api = { 
  connect = function() end,
  send = function() end,
  disconnect = function() end
}
local mock_api = firmo.mock(api)
-- Stub methods
mock_api:stub("connect", true)
mock_api:stub("send", true)
mock_api:stub("disconnect", true)
-- Make calls
api.connect()
api.send("data")
api.disconnect()
-- Verify sequence
mock_api:verify_sequence({
  {method = "connect"},
  {method = "send", args = {"data"}},
  {method = "disconnect"}
}) -- Passes because calls were made in this order

```text

### mock:expect(method_name)
Sets up expectations for how a method should be called. This returns a fluent interface for defining expectations.
**Parameters:**

- `method_name` (string): Name of the method to set expectations for
**Returns:**

- A fluent interface for defining expectations
**Example:**

```lua
local api = { get_user = function() end }
local mock_api = firmo.mock(api)
-- Set up expectations
mock_api:expect("get_user")
  .with(123)
  .to.be.called.once()
-- Stub implementation
mock_api:stub("get_user", {name = "Test User"})
-- Call method
api.get_user(123)
-- Verify expectations
mock_api:verify_expectations()

```text

### mock:verify_expectations()
Verifies that all expectations set with `expect()` were met.
**Returns:**

- `true` if all expectations were met
**Throws:**

- Error with details if any expectation was not met
**Example:**

```lua
local api = { get_user = function() end }
local mock_api = firmo.mock(api)
-- Set up expectations
mock_api:expect("get_user").to.be.called.times(2)
-- Stub implementation 
mock_api:stub("get_user", {name = "Test User"})
-- Call method only once (should fail verification)
api.get_user(123)
-- This will throw an error because get_user was called only once
local success, err = pcall(function()
  mock_api:verify_expectations()
end)
expect(success).to.equal(false)

```text

### mock._stubs
A table containing all the stubs created on the mock.
**Example:**

```lua
local obj = { method = function() end }
local mock_obj = firmo.mock(obj)
mock_obj:stub("method", function() return "stubbed" end)
obj.method()
expect(mock_obj._stubs.method.called).to.be.truthy()
expect(mock_obj._stubs.method.call_count).to.equal(1)

```text

## Argument Matchers
Argument matchers provide flexible ways to match arguments in function calls.

### firmo.arg_matcher.any()
Matches any value.
**Returns:**

- A matcher that accepts any argument value
**Example:**

```lua
local spy_fn = firmo.spy(function() end)
spy_fn("test")
expect(spy_fn:called_with(firmo.arg_matcher.any())).to.be.truthy()

```text

### firmo.arg_matcher.string()
Matches any string value.
**Returns:**

- A matcher that accepts any string argument
**Example:**

```lua
local spy_fn = firmo.spy(function() end)
spy_fn("test")
spy_fn(123)
expect(spy_fn:called_with(firmo.arg_matcher.string())).to.be.truthy()
expect(spy_fn:called_with(firmo.arg_matcher.number())).to.be.truthy()

```text

### firmo.arg_matcher.number()
Matches any number value.

### firmo.arg_matcher.boolean()
Matches any boolean value.

### firmo.arg_matcher.table()
Matches any table value.

### firmo.arg_matcher.func()
Matches any function value.

### firmo.arg_matcher.table_containing(partial)
Matches a table that contains at least the specified keys and values.
**Parameters:**

- `partial` (table): Table with keys and values that must be present in the matched table
**Returns:**

- A matcher that checks if a table contains the specified keys and values
**Example:**

```lua
local spy_fn = firmo.spy(function() end)
spy_fn({id = 123, name = "test", extra = "value"})
-- Matches because the argument contains the specified keys/values
expect(spy_fn:called_with(
  firmo.arg_matcher.table_containing({id = 123, name = "test"})
)).to.be.truthy()
-- Doesn't match because the value for 'name' is different
expect(spy_fn:called_with(
  firmo.arg_matcher.table_containing({id = 123, name = "different"})
)).to.equal(false)

```text

### firmo.arg_matcher.custom(fn, description)
Creates a custom matcher using the provided function.
**Parameters:**

- `fn` (function): Function that takes a value and returns true if it matches, false otherwise
- `description` (string, optional): Description of the matcher for error messages
**Returns:**

- A custom matcher that uses the provided function
**Example:**

```lua
-- Create a matcher for positive numbers
local positive_matcher = firmo.arg_matcher.custom(
  function(val) return type(val) == "number" and val > 0 end,
  "positive number"
)
local spy_fn = firmo.spy(function() end)
spy_fn(42)
spy_fn(-10)
expect(spy_fn:called_with(positive_matcher)).to.be.truthy()

```text

## Context Management

### firmo.with_mocks(fn)
Creates a context where mocks are automatically restored when the function exits, even if an error occurs.
**Parameters:**

- `fn` (function): Function to run inside the mock context, receives a mock function as its argument
**Example:**

```lua
local obj = { method = function() return "original" end }
firmo.with_mocks(function(mock)
  -- Create mocks inside the context
  local mock_obj = mock(obj)
  mock_obj:stub("method", function() return "stubbed" end)
  -- Use the mock
  expect(obj.method()).to.equal("stubbed")
  -- No need to restore, happens automatically
end)
-- Outside the context, original method is restored
expect(obj.method()).to.equal("original")

```text

## Examples

### Simple Function Stubbing

```lua
describe("Function stubbing", function()
  it("can stub a function to return a fixed value", function()
    -- Create a stub that returns a fixed value
    local getUser = firmo.stub({id = 1, name = "John"})
    -- Use the stub
    local user = getUser()
    -- Verify the stub returned the expected value
    expect(user.id).to.equal(1)
    expect(user.name).to.equal("John")
    -- Verify the stub was called
    expect(getUser.called).to.be.truthy()
  end)
end)

```text

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
    local mock_service = firmo.mock(user_service)
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

```text

### Using the with_mocks Context

```lua
describe("with_mocks context", function()
  it("automatically restores mocks when context ends", function()
    local original_function = function() return "original" end
    local obj = { func = original_function }
    -- Create mocks in a context
    firmo.with_mocks(function(mock)
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
      firmo.with_mocks(function(mock)
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

```text

## Best Practices

1. **Restore mocks**: Always restore mocks after using them, or use the `with_mocks` context.
1. **Use minimal stubbing**: Only stub the methods and behavior necessary for your test.
1. **Verify meaningful interactions**: Focus verification on interactions that are relevant to the test.
1. **Avoid complex implementations**: Keep stub implementations simple and deterministic.
1. **Test mock behavior**: Ensure your mocks behave as expected before using them in tests.
1. **Use appropriate mocking approach**:
   - Use spies when you want to verify calls without changing behavior
   - Use stubs when you need to replace functionality
   - Use mocks when you need both replacement and verification

## Advanced Examples

### Using Expectations API and Call Sequence Verification

```lua
describe("Order processing system", function()
  it("processes orders in the correct sequence", function()
    local order_system = {
      validate_order = function() end,
      process_payment = function() end,
      update_inventory = function() end,
      send_confirmation = function() end
    }
    -- Create a mock of the order system
    firmo.with_mocks(function(mock)
      local system_mock = mock(order_system)
      -- Set up expectations with the fluent API
      system_mock:expect("validate_order")
        .with(firmo.arg_matcher.table_containing({id = 123}))
        .to.be.called.once()
      system_mock:expect("process_payment")
        .with(firmo.arg_matcher.number())
        .to.be.called.once()
        .and_return(true)
      system_mock:expect("update_inventory")
        .to.be.called.once()
      system_mock:expect("send_confirmation")
        .to.be.called.once()
        .after("update_inventory")
      -- Stub implementations
      system_mock:stub("validate_order", true)
      system_mock:stub("process_payment", true)
      system_mock:stub("update_inventory", true)
      system_mock:stub("send_confirmation", true)
      -- Run the function under test
      local order = {id = 123, items = {{id = 1, quantity = 2}}}
      process_order(order_system, order, 99.99)
      -- Verify the expected sequence of calls
      system_mock:verify_sequence({
        {method = "validate_order", args = {order}},
        {method = "process_payment", args = {99.99}},
        {method = "update_inventory", args = {order.items}},
        {method = "send_confirmation", args = {order.id}}
      })
      -- Verify all expectations were met
      system_mock:verify_expectations()
    end)
  end)
end)

```text

### Using Sequential Return Values

```lua
describe("API client with changing state", function()
  it("correctly handles a resource lifecycle", function()
    -- Function under test - polls until a job is complete
    local function wait_for_job_completion(api_client, job_id, max_attempts)
      max_attempts = max_attempts or 5
      local attempts = 0

      repeat
        attempts = attempts + 1
        local job_status = api_client.get_job_status(job_id)

        if job_status.status == "completed" then
          return true, job_status.result
        elseif job_status.status == "failed" then
          return false, job_status.error
        end

        -- In real code, would wait between attempts
      until attempts >= max_attempts

      return false, "Timed out waiting for job completion"
    end

    -- Setup mocked API client
    local api_client = {
      get_job_status = function(id) 
        return { status = "queued", id = id } 
      end
    }

    -- Test the normal success path
    firmo.with_mocks(function(mock)
      local mock_api = mock(api_client)

      -- Mock a job that progresses through multiple states
      mock_api:stub_in_sequence("get_job_status", {
        { status = "queued", id = 123 },
        { status = "processing", id = 123, progress = 25 },
        { status = "processing", id = 123, progress = 75 },
        { status = "completed", id = 123, result = "success" }
      })

      -- Call the function under test
      local success, result = wait_for_job_completion(api_client, 123)

      -- Check results
      expect(success).to.equal(true)
      expect(result).to.equal("success")
      expect(mock_api._stubs.get_job_status.call_count).to.equal(4)
    end)

    -- Test the error path
    firmo.with_mocks(function(mock)
      local mock_api = mock(api_client)

      -- Mock a job that fails midway
      mock_api:stub_in_sequence("get_job_status", {
        { status = "queued", id = 456 },
        { status = "processing", id = 456, progress = 30 },
        { status = "failed", id = 456, error = "Resource not found" }
      })

      -- Call the function under test
      local success, result = wait_for_job_completion(api_client, 456)

      -- Check results
      expect(success).to.equal(false)
      expect(result).to.equal("Resource not found")
      expect(mock_api._stubs.get_job_status.call_count).to.equal(3)
    end)

    -- Test timeout scenario with manual cycling implementation
    firmo.with_mocks(function(mock)
      local mock_api = mock(api_client)

      -- Use a manual implementation for reliable cycling
      local cycle_values = {
        { status = "processing", id = 789, progress = 10 },
        { status = "processing", id = 789, progress = 20 },
        { status = "processing", id = 789, progress = 30 }
      }
      local index = 1

      -- Create a stub with reliable cycling behavior
      mock_api:stub("get_job_status", function()
        local result = cycle_values[((index - 1) % #cycle_values) + 1]
        index = index + 1
        return result
      end)

      -- Call the function with 3 max attempts
      local success, result = wait_for_job_completion(api_client, 789, 3)

      -- Check results
      expect(success).to.equal(false)
      expect(result).to.equal("Timed out waiting for job completion")
      expect(mock_api._stubs.get_job_status.call_count).to.equal(3)
    end)
  end)
end)

```text

### Advanced Sequence Control Examples

```lua
describe("Advanced sequence behavior", function()
  it("demonstrates custom exhaustion behavior", function()
    local api = { get_status = function() return "online" end }
    local mock_api = firmo.mock(api)

    -- Option 1: Using direct implementation for reliable control
    local sequence_values = {
      "starting",
      "connecting" 
    }
    local exhausted_value = "error"
    local index = 1

    mock_api:stub("get_status", function()
      if index <= #sequence_values then
        local result = sequence_values[index]
        index = index + 1
        return result
      else
        -- Return custom value on exhaustion
        return exhausted_value
      end
    end)

    -- First calls get sequence values
    expect(api.get_status()).to.equal("starting")
    expect(api.get_status()).to.equal("connecting")

    -- After exhaustion, gets custom value
    expect(api.get_status()).to.equal("error")
  end)

  it("demonstrates falling back to original implementation", function()
    local original_impl = function() return "original value" end
    local obj = { method = original_impl }
    local mock_obj = firmo.mock(obj)

    -- Setup sequence with fallback to original
    local sequence = { "mock 1", "mock 2" }
    local index = 1

    mock_obj:stub("method", function()
      if index <= #sequence then
        local value = sequence[index]
        index = index + 1
        return value
      else
        -- Fall back to original implementation
        return original_impl()
      end
    end)

    -- Use sequence values first
    expect(obj.method()).to.equal("mock 1")
    expect(obj.method()).to.equal("mock 2")

    -- Then fall back to original
    expect(obj.method()).to.equal("original value")
  end)

  it("demonstrates resetting a sequence", function()
    local obj = { method = function() return "real" end }
    local mock_obj = firmo.mock(obj)

    -- Create a sequence we can reset
    local sequence = { "value 1", "value 2" }
    local index = 1

    -- Function to reset the sequence
    local reset_sequence = function()
      index = 1
    end

    mock_obj:stub("method", function()
      if index <= #sequence then
        local value = sequence[index]
        index = index + 1
        return value
      else
        return nil
      end
    end)

    -- First run through sequence
    expect(obj.method()).to.equal("value 1")
    expect(obj.method()).to.equal("value 2")
    expect(obj.method()).to.equal(nil)

    -- Reset sequence
    reset_sequence()

    -- Run through again
    expect(obj.method()).to.equal("value 1")
    expect(obj.method()).to.equal("value 2")
  end)
end)

```text

