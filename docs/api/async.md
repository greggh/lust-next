
# Async Testing API

This document describes the asynchronous testing capabilities provided by Lust-Next.

## Overview

Lust-Next provides a modular system for testing asynchronous code. The `src/async.lua` module implements the core functionality, which is then integrated into the main testing framework.

## Async Test Functions

### lust.async(fn, [timeout])

Creates an asynchronous test function wrapper.

**Parameters:**

- `fn` (function): The function to make asynchronous
- `timeout` (number, optional): Maximum time in milliseconds to wait before failing (default: 5000)

**Returns:**

- A wrapped function that when called returns an asynchronous test function

**Example:**

```lua
it("performs async operation", lust.async(function()
  -- Async test code here
  lust.await(100) -- Wait 100ms
  expect(result).to.exist()
end))

```text

### lust.it_async(name, fn, [timeout])

Convenient shorthand for creating an asynchronous test.

**Parameters:**

- `name` (string): The name of the test
- `fn` (function): The asynchronous test function
- `timeout` (number, optional): Maximum time in milliseconds before failing (default: 5000)

**Returns:** None

**Example:**

```lua
lust.it_async("performs async operation", function()
  -- Async test code here
  lust.await(100) -- Wait 100ms
  expect(result).to.exist()
end)

```text

## Async Utilities

### lust.await(milliseconds)

Pauses execution for the specified number of milliseconds.

**Parameters:**

- `milliseconds` (number): Number of milliseconds to wait

**Returns:** None

**Notes:**

- Can only be called within an async test function
- Uses coroutine.yield internally to pause execution

**Example:**

```lua
lust.it_async("waits before checking result", function()
  local result = nil

  -- Start async operation
  setTimeout(function() result = "done" end, 50)

  -- Wait for operation to complete
  lust.await(100)

  -- Check result
  expect(result).to.equal("done")
end)

```text

### lust.wait_until(condition_fn, [timeout], [check_interval])

Waits until the condition function returns true or until the timeout is reached.

**Parameters:**

- `condition_fn` (function): Function that returns true when the condition is met
- `timeout` (number, optional): Maximum wait time in milliseconds (default: 5000)
- `check_interval` (number, optional): Interval in milliseconds between condition checks (default: 10)

**Returns:** 

- `true` if the condition was met
- Throws an error if the timeout is reached before the condition is met

**Notes:**

- Can only be called within an async test function
- Throws an error with a timeout message if the condition isn't met within the timeout period

**Example:**

```lua
lust.it_async("waits for condition", function()
  local value = nil

  -- Start async operation
  setTimeout(function() value = "done" end, 50)

  -- Wait until value is set
  lust.wait_until(function() return value ~= nil end, 1000, 10)

  -- Check result
  expect(value).to.equal("done")
end)

```text

### lust.parallel_async(operations, [timeout])

Runs multiple async operations concurrently and waits for all to complete.

**Parameters:**

- `operations` (table): Array of functions to run concurrently
- `timeout` (number, optional): Maximum time in milliseconds to wait before failing (default: configured timeout)

**Returns:**

- Array of results from all operations in the same order they were provided

**Notes:**

- Can only be called within an async test function
- All operations run concurrently and the results are only returned when all have completed
- Significantly faster than running operations sequentially
- If any operation fails, an error is thrown with details about which operations failed
- If the timeout is reached, an error is thrown listing the operations that didn't complete

**Example:**

```lua
lust.it_async("runs operations in parallel", function()
  -- Define multiple async operations
  local function fetch_users()
    lust.await(100)  -- Simulate network delay
    return { {id = 1, name = "User 1"}, {id = 2, name = "User 2"} }
  end

  local function fetch_posts()
    lust.await(150)  -- Different operation with different timing
    return { {id = 1, title = "Post 1"}, {id = 2, title = "Post 2"} }
  end

  local function fetch_comments()
    lust.await(80)  -- Yet another async operation
    return { {id = 1, text = "Comment 1"}, {id = 2, text = "Comment 2"} }
  end

  -- Run all operations in parallel (completes in ~150ms instead of ~330ms)
  local results = lust.parallel_async({fetch_users, fetch_posts, fetch_comments})

  -- Verify all results
  expect(#results).to.equal(3)
  expect(#results[1]).to.equal(2)  -- Two users
  expect(#results[2]).to.equal(2)  -- Two posts
  expect(#results[3]).to.equal(2)  -- Two comments
  expect(results[1][1].name).to.equal("User 1")
  expect(results[2][1].title).to.equal("Post 1")
  expect(results[3][1].text).to.equal("Comment 1")
end)
```

### Configuring Timeouts

To set the default timeout for all async operations, access the async module directly:

```lua
local async_module = package.loaded["src.async"]
if async_module then
  async_module.set_timeout(10000) -- 10 seconds
end

lust.it_async("long running test", function()
  -- This test has up to 10 seconds to complete
end)
```

Individual timeouts can also be specified when using `wait_until`:

```lua
-- Wait for up to 5 seconds, checking every 100ms
wait_until(condition_fn, 5000, 100)
```

## Working with Asynchronous Code

### Testing Callbacks

```lua
lust.it_async("tests callback-based async code", function()
  local result = nil

  -- Function with callback
  local function fetchData(callback)
    -- Simulate async operation
    setTimeout(function() 
      callback({success = true, data = "result"})
    end, 50)
  end

  -- Call async function with callback
  fetchData(function(data)
    result = data
  end)

  -- Wait for callback to be called
  lust.wait_until(function() return result ~= nil end)

  -- Verify result
  expect(result.success).to.be.truthy()
  expect(result.data).to.equal("result")
end)

```text

### Testing Promises

```lua
lust.it_async("tests promise-like async code", function()
  local result = nil

  -- Function returning promise-like object
  local function fetchData()
    local promise = {
      state = "pending",
      then = function(self, callback)
        setTimeout(function()
          callback({success = true, data = "result"})
        end, 50)
        return self
      end
    }
    return promise
  end

  -- Call async function
  fetchData():then(function(data)
    result = data
  end)

  -- Wait for promise to resolve
  lust.wait_until(function() return result ~= nil end)

  -- Verify result
  expect(result.success).to.be.truthy()
  expect(result.data).to.equal("result")
end)

```text

### Handling Timeouts

```lua
lust.it_async("handles timeouts gracefully", function()
  local result = nil

  -- This function takes too long
  local function slowOperation(callback)
    setTimeout(function() 
      callback("done")
    end, 500)
  end

  -- Start slow operation
  slowOperation(function(data)
    result = data
  end)

  -- This will fail due to timeout (only waits 100ms)
  local success = pcall(function()
    lust.wait_until(function() return result ~= nil end, 100)
  end)

  -- Verify timeout occurred
  expect(success).to.equal(false)
  expect(result).to.equal(nil)
end)

```text

## Best Practices

1. **Keep timeouts reasonable**: Set timeouts that give your async operations enough time to complete, but not so long that tests hang when errors occur.

1. **Always check for completion**: Use `wait_until` to confirm operations completed before making assertions.

1. **Clean up after async operations**: Use Lust's `after` hooks to clean up any resources from async operations.

1. **Isolate tests**: Each async test should be self-contained and not depend on the state of other tests.

1. **Handle errors**: Use pcall to capture and test for expected errors in async code.

1. **Test edge cases**: Test timeout conditions, error conditions, and race conditions in your async code.

