# Async Module Examples

This document provides comprehensive examples for using the async testing capabilities in the Firmo framework. These examples demonstrate different async testing patterns and scenarios.

## Basic Async Testing

### Simple Async/Await Test

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local it_async = firmo.it_async
local await = firmo.await

describe("Basic Async Testing", function()
  it_async("waits for a specified time", function()
    local start_time = os.clock()
    
    -- Wait for 100ms
    await(100)
    
    local elapsed = (os.clock() - start_time) * 1000
    expect(elapsed >= 95).to.be_truthy() -- Allow small timing differences
  end)
  
  it_async("can perform assertions after waiting", function()
    local value = 0
    
    -- Simulate async operation that changes a value after 50ms
    local start_time = os.clock() * 1000
    
    -- In a real app, this might be a callback from an event or API
    local timer_id = firmo.set_timeout(function()
      value = 42
    end, 50)
    
    -- Wait for 100ms to ensure the operation completes
    await(100)
    
    -- Now we can make assertions on the updated value
    expect(value).to.equal(42)
  end)
end)
```

### Using wait_until for Conditions

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

describe("Condition-based Waiting", function()
  it_async("waits for a condition to become true", function()
    local value = nil
    
    -- Simulate async operation
    firmo.set_timeout(function()
      value = "completed"
    end, 50)
    
    -- Wait until the value is set (with a 500ms timeout)
    wait_until(function() return value ~= nil end, 500)
    
    -- Now the value should be set
    expect(value).to.equal("completed")
  end)
  
  it_async("can specify a custom check interval", function()
    local counter = 0
    
    -- Increment counter every 10ms
    local interval_id = firmo.set_interval(function()
      counter = counter + 1
    end, 10)
    
    -- Wait until counter reaches 5, checking every 5ms (instead of default)
    wait_until(function() return counter >= 5 end, 200, 5)
    
    -- Clean up the interval
    firmo.clear_interval(interval_id)
    
    -- Counter should be at least 5 now
    expect(counter >= 5).to.be_truthy()
  end)
end)
```

### Testing Async APIs

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

-- Simulate an asynchronous API
local AsyncAPI = {
  fetch_data = function(callback, delay)
    delay = delay or 100 -- default delay
    
    -- Simulate a delayed response
    firmo.set_timeout(function()
      callback({ 
        status = "success", 
        data = { 
          id = 123,
          name = "Test Data",
          timestamp = os.time()
        } 
      })
    end, delay)
  end
}

describe("Async API Testing", function()
  it_async("tests a callback-based API", function()
    local result = nil
    
    -- Start the async operation
    AsyncAPI.fetch_data(function(data)
      result = data
    end)
    
    -- Wait for the result
    wait_until(function() return result ~= nil end)
    
    -- Verify the response
    expect(result).to.exist()
    expect(result.status).to.equal("success")
    expect(result.data).to.exist()
    expect(result.data.id).to.equal(123)
    expect(result.data.name).to.equal("Test Data")
  end)
  
  it_async("handles API timeouts", function()
    local result = nil
    local operation_timed_out = false
    
    -- Start operation with long delay
    AsyncAPI.fetch_data(function(data)
      result = data
    end, 300) -- 300ms delay
    
    -- Try to wait with a short timeout
    local success = pcall(function()
      -- This should timeout after 50ms
      wait_until(function() return result ~= nil end, 50)
    end)
    
    -- The wait should fail
    expect(success).to.equal(false)
    expect(result).to.equal(nil) -- Response not received yet
    
    -- Now wait for the full duration
    wait_until(function() return result ~= nil end, 500)
    
    -- Now we should have the response
    expect(result).to.exist()
    expect(result.status).to.equal("success")
  end)
end)
```

## Advanced Async Testing

### Running Parallel Operations

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local async, await, parallel_async = firmo.async, firmo.await, firmo.parallel_async

describe("Parallel Async Operations", function()
  it_async("runs multiple operations concurrently", function()
    local start_time = os.clock()
    
    -- Define three operations with different completion times
    local op1 = async(function()
      await(50) -- Operation 1 takes 50ms
      return "op1 done"
    end)()
    
    local op2 = async(function()
      await(30) -- Operation 2 takes 30ms
      return "op2 done"
    end)()
    
    local op3 = async(function()
      await(70) -- Operation 3 takes 70ms
      return "op3 done"
    end)()
    
    -- Run operations in parallel
    local results = parallel_async({ op1, op2, op3 })
    
    -- Check results
    expect(results[1]).to.equal("op1 done")
    expect(results[2]).to.equal("op2 done")
    expect(results[3]).to.equal("op3 done")
    
    -- Verify that the total time is closer to the longest operation
    -- rather than the sum of all operations (which would be 150ms)
    local elapsed = (os.clock() - start_time) * 1000
    expect(elapsed >= 65).to.be_truthy() -- At least close to longest op
    expect(elapsed < 140).to.be_truthy() -- Much less than sum of all ops
  end)
  
  it_async("handles errors in parallel operations", { expect_error = true }, function()
    -- Operations with one failure
    local op1 = async(function()
      await(20)
      return "op1 done"
    end)()
    
    local op2 = async(function()
      await(10)
      error("Operation 2 failed")
    end)()
    
    local op3 = async(function()
      await(30)
      return "op3 done"
    end)()
    
    -- Run operations and expect an error
    local success, err = pcall(function()
      parallel_async({ op1, op2, op3 })
    end)
    
    -- Verify error was thrown and contains the right message
    expect(success).to.equal(false)
    expect(tostring(err)).to.match("One or more parallel operations failed")
    expect(tostring(err)).to.match("Operation 2 failed")
  end)
end)
```

### Testing Promise-like APIs

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

-- Simulate a promise-like API
local PromiseAPI = {
  create_promise = function()
    local promise = {
      state = "pending",
      result = nil,
      error = nil,
      
      -- Handlers
      resolve_handlers = {},
      reject_handlers = {},
      
      -- Resolve the promise
      resolve = function(self, value)
        if self.state ~= "pending" then return end
        
        self.state = "fulfilled"
        self.result = value
        
        -- Call resolve handlers
        for _, handler in ipairs(self.resolve_handlers) do
          handler(value)
        end
      end,
      
      -- Reject the promise
      reject = function(self, reason)
        if self.state ~= "pending" then return end
        
        self.state = "rejected"
        self.error = reason
        
        -- Call reject handlers
        for _, handler in ipairs(self.reject_handlers) do
          handler(reason)
        end
      end,
      
      -- Add then handler
      then_fn = function(self, on_fulfilled, on_rejected)
        if on_fulfilled then
          table.insert(self.resolve_handlers, on_fulfilled)
          
          -- If already fulfilled, call handler
          if self.state == "fulfilled" then
            on_fulfilled(self.result)
          end
        end
        
        if on_rejected then
          table.insert(self.reject_handlers, on_rejected)
          
          -- If already rejected, call handler
          if self.state == "rejected" then
            on_rejected(self.error)
          end
        end
        
        return self
      end,
      
      -- Add catch handler
      catch = function(self, on_rejected)
        return self:then_fn(nil, on_rejected)
      end
    }
    
    -- Set then as actual method (Lua keyword issue)
    promise.then = promise.then_fn
    
    return promise
  end,
  
  -- Function to fetch data with a promise
  fetch_data = function(succeed, delay)
    local promise = PromiseAPI.create_promise()
    
    -- Simulate async operation
    firmo.set_timeout(function()
      if succeed then
        promise:resolve({ 
          status = "success", 
          data = { id = 123, name = "Test Data" } 
        })
      else
        promise:reject("Failed to fetch data")
      end
    end, delay or 50)
    
    return promise
  end
}

describe("Promise-like API Testing", function()
  it_async("tests a successful promise", function()
    local result = nil
    
    -- Start promise operation
    local promise = PromiseAPI.fetch_data(true)
    
    -- Add callback
    promise:then(function(data)
      result = data
    end)
    
    -- Wait for promise to resolve
    wait_until(function() return promise.state ~= "pending" end)
    
    -- Check results
    expect(promise.state).to.equal("fulfilled")
    expect(result).to.exist()
    expect(result.status).to.equal("success")
    expect(result.data.id).to.equal(123)
  end)
  
  it_async("tests a failed promise", function()
    local error_result = nil
    
    -- Start promise operation that will fail
    local promise = PromiseAPI.fetch_data(false)
    
    -- Add error callback
    promise:catch(function(err)
      error_result = err
    end)
    
    -- Wait for promise to resolve (either way)
    wait_until(function() return promise.state ~= "pending" end)
    
    -- Check results
    expect(promise.state).to.equal("rejected")
    expect(error_result).to.equal("Failed to fetch data")
  end)
end)
```

## Practical Scenarios

### Testing a Database Client

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

-- Mock database client
local DB = {
  _data = {
    users = {
      {id = 1, name = "Alice", active = true},
      {id = 2, name = "Bob", active = false}
    }
  },
  
  -- Simple query function with callback
  query = function(sql, callback)
    -- Parse the simple SQL to demonstrate
    local collection, where_field, where_value
    
    -- Parse: SELECT * FROM users WHERE id = 1
    collection = sql:match("FROM ([%w_]+)")
    where_field = sql:match("WHERE ([%w_]+) =")
    where_value = sql:match("= ([%w_']+)")
    
    -- Strip quotes if present
    if where_value and where_value:sub(1,1) == "'" then
      where_value = where_value:sub(2, -2)
    end
    
    -- Convert to number if needed
    if where_value and tonumber(where_value) then
      where_value = tonumber(where_value)
    end
    
    -- Simulate delay
    firmo.set_timeout(function()
      local results = {}
      
      -- Filter results if where clause present
      if collection and where_field and where_value then
        for _, item in ipairs(DB._data[collection] or {}) do
          if item[where_field] == where_value then
            table.insert(results, item)
          end
        end
      else if collection then
        -- Just return all items in collection
        results = DB._data[collection] or {}
      end
      
      -- Return results
      callback(nil, results)
    end, 30)
  end,
  
  -- Insert with callback
  insert = function(collection, data, callback)
    -- Generate ID if needed
    if not data.id then
      data.id = #DB._data[collection] + 1
    end
    
    -- Simulate delay
    firmo.set_timeout(function()
      -- Initialize collection if needed
      DB._data[collection] = DB._data[collection] or {}
      
      -- Insert data
      table.insert(DB._data[collection], data)
      
      -- Return data with ID
      callback(nil, data)
    end, 50)
  end
}

describe("Database Client", function()
  it_async("can query records", function()
    local results = nil
    
    -- Execute query
    DB.query("SELECT * FROM users WHERE id = 1", function(err, data)
      expect(err).to.equal(nil)
      results = data
    end)
    
    -- Wait for query to complete
    wait_until(function() return results ~= nil end)
    
    -- Verify results
    expect(#results).to.equal(1)
    expect(results[1].id).to.equal(1)
    expect(results[1].name).to.equal("Alice")
  end)
  
  it_async("can insert records", function()
    local result = nil
    
    -- Insert new record
    DB.insert("users", {name = "Charlie", active = true}, function(err, data)
      expect(err).to.equal(nil)
      result = data
    end)
    
    -- Wait for insert to complete
    wait_until(function() return result ~= nil end)
    
    -- Verify insert worked
    expect(result.id).to.equal(3)
    expect(result.name).to.equal("Charlie")
    
    -- Verify we can query the new record
    local query_result = nil
    DB.query("SELECT * FROM users WHERE name = 'Charlie'", function(err, data)
      expect(err).to.equal(nil)
      query_result = data
    end)
    
    -- Wait for query to complete
    wait_until(function() return query_result ~= nil end)
    
    -- Verify query found the new record
    expect(#query_result).to.equal(1)
    expect(query_result[1].name).to.equal("Charlie")
  end)
end)
```

### Testing a Message Queue

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

-- Mock message queue
local MessageQueue = {
  _queues = {},
  
  -- Create a new queue
  create_queue = function(name)
    MessageQueue._queues[name] = MessageQueue._queues[name] or {
      messages = {},
      consumers = {}
    }
  end,
  
  -- Send a message to a queue
  send = function(queue_name, message, callback)
    -- Ensure queue exists
    MessageQueue.create_queue(queue_name)
    local queue = MessageQueue._queues[queue_name]
    
    -- Simulate network delay
    firmo.set_timeout(function()
      -- Add message to queue
      table.insert(queue.messages, message)
      
      -- Notify consumers
      for _, consumer in ipairs(queue.consumers) do
        consumer(message)
      end
      
      -- Call completion callback
      if callback then
        callback(nil, { id = #queue.messages, timestamp = os.time() })
      end
    end, 20)
  end,
  
  -- Consume messages from a queue
  consume = function(queue_name, consumer_fn)
    -- Ensure queue exists
    MessageQueue.create_queue(queue_name)
    local queue = MessageQueue._queues[queue_name]
    
    -- Register consumer
    table.insert(queue.consumers, consumer_fn)
    
    -- Return a function to stop consuming
    return function()
      for i, fn in ipairs(queue.consumers) do
        if fn == consumer_fn then
          table.remove(queue.consumers, i)
          break
        end
      end
    end
  end,
  
  -- Get queue length
  get_queue_length = function(queue_name, callback)
    -- Ensure queue exists
    MessageQueue.create_queue(queue_name)
    local queue = MessageQueue._queues[queue_name]
    
    -- Simulate network delay
    firmo.set_timeout(function()
      callback(nil, #queue.messages)
    end, 10)
  end
}

describe("Message Queue", function()
  -- Reset queues before each test
  before_each(function()
    MessageQueue._queues = {}
  end)
  
  it_async("can send and receive messages", function()
    local message_received = false
    local received_content = nil
    
    -- Start consuming messages
    local stop_consuming = MessageQueue.consume("test-queue", function(msg)
      message_received = true
      received_content = msg
    end)
    
    -- Send a message
    local send_result = nil
    MessageQueue.send("test-queue", {type = "greeting", text = "Hello World"}, function(err, result)
      send_result = result
    end)
    
    -- Wait for message to be sent
    wait_until(function() return send_result ~= nil end)
    
    -- Wait for message to be received
    wait_until(function() return message_received end)
    
    -- Verify message content
    expect(received_content).to.exist()
    expect(received_content.type).to.equal("greeting")
    expect(received_content.text).to.equal("Hello World")
    
    -- Clean up
    stop_consuming()
  end)
  
  it_async("can handle multiple messages in order", function()
    local received_messages = {}
    
    -- Start consuming messages
    local stop_consuming = MessageQueue.consume("test-queue", function(msg)
      table.insert(received_messages, msg)
    end)
    
    -- Send multiple messages
    local completed_count = 0
    local completion_callback = function()
      completed_count = completed_count + 1
    end
    
    MessageQueue.send("test-queue", {id = 1, text = "First"}, completion_callback)
    MessageQueue.send("test-queue", {id = 2, text = "Second"}, completion_callback)
    MessageQueue.send("test-queue", {id = 3, text = "Third"}, completion_callback)
    
    -- Wait for all sends to complete
    wait_until(function() return completed_count == 3 end)
    
    -- Wait for all messages to be received
    wait_until(function() return #received_messages == 3 end)
    
    -- Verify message order is preserved
    expect(received_messages[1].id).to.equal(1)
    expect(received_messages[2].id).to.equal(2)
    expect(received_messages[3].id).to.equal(3)
    
    -- Clean up
    stop_consuming()
  end)
  
  it_async("can get queue length", function()
    -- Send a few messages
    MessageQueue.send("test-queue", {text = "One"})
    MessageQueue.send("test-queue", {text = "Two"})
    MessageQueue.send("test-queue", {text = "Three"})
    
    -- Get queue length
    local length = nil
    MessageQueue.get_queue_length("test-queue", function(err, count)
      length = count
    end)
    
    -- Wait for length to be retrieved
    wait_until(function() return length ~= nil end)
    
    -- Verify queue length
    expect(length).to.equal(3)
  end)
end)
```

### Testing a Timer System

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local await, wait_until = firmo.await, firmo.wait_until

-- Mock timer system
local Timer = {
  _timers = {},
  _timer_id_counter = 0,
  
  -- Create a timeout timer
  set_timeout = function(callback, ms)
    Timer._timer_id_counter = Timer._timer_id_counter + 1
    local id = Timer._timer_id_counter
    
    -- Record start time
    local start_time = os.clock() * 1000
    
    -- Create timer object
    Timer._timers[id] = {
      id = id,
      callback = callback,
      ms = ms,
      start_time = start_time,
      expires_at = start_time + ms,
      interval = false,
      cancelled = false
    }
    
    -- Start the timer using Firmo's real timer (for testing only)
    firmo.set_timeout(function()
      -- Only execute if not cancelled
      if not Timer._timers[id] or Timer._timers[id].cancelled then
        return
      end
      
      -- Execute callback
      Timer._timers[id].callback()
      
      -- If not an interval, remove the timer
      if not Timer._timers[id].interval then
        Timer._timers[id] = nil
      end
    end, ms)
    
    return id
  end,
  
  -- Create an interval timer
  set_interval = function(callback, ms)
    Timer._timer_id_counter = Timer._timer_id_counter + 1
    local id = Timer._timer_id_counter
    
    -- Record start time
    local start_time = os.clock() * 1000
    
    -- Create timer object
    Timer._timers[id] = {
      id = id,
      callback = callback,
      ms = ms,
      start_time = start_time,
      next_run = start_time + ms,
      interval = true,
      cancelled = false,
      run_count = 0
    }
    
    -- For testing purposes, use Firmo's real interval
    local interval_id = firmo.set_interval(function()
      -- Only execute if not cancelled
      if not Timer._timers[id] or Timer._timers[id].cancelled then
        firmo.clear_interval(interval_id)
        return
      end
      
      -- Execute callback
      Timer._timers[id].callback()
      
      -- Update timer state
      Timer._timers[id].run_count = Timer._timers[id].run_count + 1
      Timer._timers[id].next_run = (os.clock() * 1000) + ms
    end, ms)
    
    return id
  end,
  
  -- Cancel a timer
  cancel_timer = function(id)
    if Timer._timers[id] then
      Timer._timers[id].cancelled = true
      return true
    end
    return false
  end,
  
  -- Get info about a timer
  get_timer_info = function(id)
    return Timer._timers[id]
  end,
  
  -- Clear all timers
  clear_all = function()
    Timer._timers = {}
  end
}

describe("Timer System", function()
  -- Reset timers before each test
  before_each(function()
    Timer.clear_all()
  end)
  
  it_async("executes a timeout callback after specified delay", function()
    local callback_executed = false
    local execution_time = nil
    local start_time = os.clock() * 1000
    
    -- Set a timeout for 50ms
    Timer.set_timeout(function()
      callback_executed = true
      execution_time = os.clock() * 1000
    end, 50)
    
    -- Wait for callback to execute
    wait_until(function() return callback_executed end)
    
    -- Verify callback was executed
    expect(callback_executed).to.be_truthy()
    
    -- Verify timing (with some tolerance)
    local elapsed = execution_time - start_time
    expect(elapsed >= 45).to.be_truthy() -- At least close to requested time
    expect(elapsed < 150).to.be_truthy() -- Not too much delay
  end)
  
  it_async("executes interval callbacks repeatedly", function()
    local execution_count = 0
    
    -- Set an interval that runs every 20ms
    local timer_id = Timer.set_interval(function()
      execution_count = execution_count + 1
    end, 20)
    
    -- Wait for multiple executions
    await(100) -- Should allow for about 5 executions
    
    -- Cancel the interval
    Timer.cancel_timer(timer_id)
    
    -- Verify multiple executions occurred
    expect(execution_count >= 3).to.be_truthy() -- At least 3 executions
    
    -- Get timer info
    local timer_info = Timer.get_timer_info(timer_id)
    
    -- Verify timer is marked as cancelled
    expect(timer_info.cancelled).to.be_truthy()
  end)
  
  it_async("can cancel a timeout before it executes", function()
    local callback_executed = false
    
    -- Set a timeout for 100ms
    local timer_id = Timer.set_timeout(function()
      callback_executed = true
    end, 100)
    
    -- Cancel the timeout after 20ms
    await(20)
    Timer.cancel_timer(timer_id)
    
    -- Wait longer than the timeout period
    await(150)
    
    -- Verify callback was not executed
    expect(callback_executed).to.equal(false)
  end)
end)
```

## Complex Async Testing Patterns

### Testing Error Recovery and Retry Logic

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

-- Mock API with retry capability
local RetryableAPI = {
  _fail_count = 2, -- Fail the first 2 calls
  
  -- Reset the failure counter
  reset = function()
    RetryableAPI._fail_count = 2
  end,
  
  -- Simulated API call that fails initially but succeeds after retries
  fetch_data = function(callback)
    -- Simulate network delay
    firmo.set_timeout(function()
      if RetryableAPI._fail_count > 0 then
        -- Fail this attempt
        RetryableAPI._fail_count = RetryableAPI._fail_count - 1
        callback(nil, {success = false, error = "Server error"})
      else
        -- Succeed
        callback(nil, {
          success = true, 
          data = {id = 123, name = "Test Data"}
        })
      end
    end, 20)
  end
}

-- Service with retry logic
local DataService = {
  -- Get data with retries
  get_data_with_retry = function(max_retries, callback)
    local attempts = 0
    local retry_delay = 30 -- ms
    
    -- Function to attempt the fetch
    local function attempt_fetch()
      attempts = attempts + 1
      
      RetryableAPI.fetch_data(function(err, result)
        if err or not result.success then
          -- Failed attempt
          if attempts < max_retries then
            -- Retry after delay
            firmo.set_timeout(attempt_fetch, retry_delay)
            -- Increase retry delay for next attempt (exponential backoff)
            retry_delay = retry_delay * 1.5
          else
            -- All retries exhausted
            callback(nil, {
              success = false,
              error = "Failed after " .. attempts .. " attempts",
              last_error = result and result.error or err
            })
          end
        else
          -- Success
          callback(nil, {
            success = true,
            data = result.data,
            attempts = attempts
          })
        end
      end)
    end
    
    -- Start the first attempt
    attempt_fetch()
  end
}

describe("Retry Logic", function()
  -- Reset API before each test
  before_each(function()
    RetryableAPI.reset()
  end)
  
  it_async("succeeds after retrying failed requests", function()
    local result = nil
    
    -- Call service with sufficient retries
    DataService.get_data_with_retry(5, function(err, data)
      result = data
    end)
    
    -- Wait for final result
    wait_until(function() return result ~= nil end)
    
    -- Verify success after retries
    expect(result.success).to.be_truthy()
    expect(result.attempts).to.equal(3) -- 1 initial + 2 retries
    expect(result.data.id).to.equal(123)
  end)
  
  it_async("fails when max retries are exhausted", function()
    local result = nil
    
    -- Reset API to fail more times
    RetryableAPI._fail_count = 5
    
    -- Call service with insufficient retries
    DataService.get_data_with_retry(3, function(err, data)
      result = data
    end)
    
    -- Wait for final result
    wait_until(function() return result ~= nil end)
    
    -- Verify failure after retries exhausted
    expect(result.success).to.equal(false)
    expect(result.error).to.match("Failed after 3 attempts")
  end)
end)
```

### Testing Race Conditions

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local async, await, parallel_async, wait_until = firmo.async, firmo.await, firmo.parallel_async, firmo.wait_until

-- Counter with race condition
local UnsafeCounter = {
  value = 0,
  
  -- Unsafe increment (simulates race condition)
  increment = function(callback)
    -- Get current value
    local current = UnsafeCounter.value
    
    -- Simulate processing delay where race condition can occur
    firmo.set_timeout(function()
      -- Use current value (which may be outdated in concurrent scenario)
      UnsafeCounter.value = current + 1
      
      if callback then
        callback(UnsafeCounter.value)
      end
    end, math.random(5, 15)) -- Random delay to increase race condition probability
  end,
  
  -- Reset counter
  reset = function()
    UnsafeCounter.value = 0
  end
}

-- Counter with mutex protection
local SafeCounter = {
  value = 0,
  _lock = false,
  _queue = {},
  
  -- Acquire mutex lock
  _acquire = function(callback)
    if not SafeCounter._lock then
      -- Lock is free, acquire it
      SafeCounter._lock = true
      callback()
    else
      -- Lock is taken, queue the request
      table.insert(SafeCounter._queue, callback)
    end
  end,
  
  -- Release mutex lock
  _release = function()
    SafeCounter._lock = false
    
    -- Process next waiting request if any
    if #SafeCounter._queue > 0 then
      local next_callback = table.remove(SafeCounter._queue, 1)
      SafeCounter._lock = true
      next_callback()
    end
  end,
  
  -- Safe increment with mutex
  increment = function(callback)
    SafeCounter._acquire(function()
      -- Get current value
      local current = SafeCounter.value
      
      -- Simulate processing delay
      firmo.set_timeout(function()
        -- Use current value (protected by mutex)
        SafeCounter.value = current + 1
        
        -- Release lock
        SafeCounter._release()
        
        if callback then
          callback(SafeCounter.value)
        end
      end, math.random(5, 15))
    end)
  end,
  
  -- Reset counter
  reset = function()
    SafeCounter.value = 0
    SafeCounter._lock = false
    SafeCounter._queue = {}
  end
}

describe("Race Condition Testing", function()
  -- Reset counters before each test
  before_each(function()
    UnsafeCounter.reset()
    SafeCounter.reset()
  end)
  
  it_async("demonstrates race condition in unsafe counter", function()
    local completion_count = 0
    local target_count = 10
    
    -- Create increment operations
    local operations = {}
    for i = 1, target_count do
      operations[i] = async(function()
        UnsafeCounter.increment(function()
          completion_count = completion_count + 1
        end)
      end)()
    end
    
    -- Run all increment operations
    parallel_async(operations)
    
    -- Wait for all increments to complete
    wait_until(function() return completion_count == target_count end)
    
    -- Due to race condition, the final value will likely be less than target_count
    expect(UnsafeCounter.value).to.be_less_than(target_count)
    
    -- Display the actual value for demonstration
    print("Unsafe counter value after " .. target_count .. " increments: " .. UnsafeCounter.value)
  end)
  
  it_async("shows safe counter prevents race conditions", function()
    local completion_count = 0
    local target_count = 10
    
    -- Create increment operations
    local operations = {}
    for i = 1, target_count do
      operations[i] = async(function()
        SafeCounter.increment(function()
          completion_count = completion_count + 1
        end)
      end)()
    end
    
    -- Run all increment operations
    parallel_async(operations)
    
    -- Wait for all increments to complete
    wait_until(function() return completion_count == target_count end)
    
    -- With mutex protection, final value should exactly match target_count
    expect(SafeCounter.value).to.equal(target_count)
    
    -- Display the actual value for demonstration
    print("Safe counter value after " .. target_count .. " increments: " .. SafeCounter.value)
  end)
end)
```

### Testing Event-Based Systems

```lua
local firmo = require("firmo")
local describe, it_async, expect = firmo.describe, firmo.it_async, firmo.expect
local wait_until = firmo.wait_until

-- Simple event emitter
local EventEmitter = {
  -- Create a new emitter
  create = function()
    local emitter = {
      _events = {},
      
      -- Register event handler
      on = function(self, event_name, handler)
        self._events[event_name] = self._events[event_name] or {}
        table.insert(self._events[event_name], handler)
        
        -- Return a function to remove this handler
        return function()
          for i, h in ipairs(self._events[event_name] or {}) do
            if h == handler then
              table.remove(self._events[event_name], i)
              break
            end
          end
        end
      end,
      
      -- One-time event handler
      once = function(self, event_name, handler)
        local remove_handler
        local wrapper = function(...)
          -- Remove handler after first call
          if remove_handler then
            remove_handler()
          end
          -- Call the original handler
          return handler(...)
        end
        
        -- Register the wrapper
        remove_handler = self:on(event_name, wrapper)
        return remove_handler
      end,
      
      -- Emit an event
      emit = function(self, event_name, ...)
        local handlers = self._events[event_name] or {}
        local args = {...}
        
        -- Call each handler with the provided arguments
        for _, handler in ipairs(handlers) do
          handler(unpack(args))
        end
        
        return #handlers > 0
      end
    }
    
    return emitter
  end
}

-- Event-based service
local ServiceEvents = {
  -- Create new service
  create = function()
    local service = {
      emitter = EventEmitter.create(),
      _status = "stopped",
      
      -- Start the service
      start = function(self)
        if self._status == "running" then
          return false
        end
        
        -- Simulate startup
        firmo.set_timeout(function()
          self._status = "running"
          self.emitter:emit("start", {time = os.time()})
          
          -- Emit data events periodically
          local emit_count = 0
          local interval_id = firmo.set_interval(function()
            emit_count = emit_count + 1
            self.emitter:emit("data", {id = emit_count, value = math.random(1, 100)})
            
            -- Stop after 5 events
            if emit_count >= 5 then
              firmo.clear_interval(interval_id)
              
              -- Emit complete event
              self.emitter:emit("complete", {count = emit_count})
            end
          end, 20)
        end, 30)
        
        return true
      end,
      
      -- Stop the service
      stop = function(self)
        if self._status == "stopped" then
          return false
        end
        
        -- Simulate shutdown
        firmo.set_timeout(function()
          self._status = "stopped"
          self.emitter:emit("stop", {time = os.time()})
        end, 20)
        
        return true
      end
    }
    
    return service
  end
}

describe("Event-Based Systems", function()
  it_async("can listen for and process events", function()
    local service = ServiceEvents.create()
    local events_received = {
      start = false,
      data = {},
      complete = false,
      stop = false
    }
    
    -- Set up event listeners
    service.emitter:on("start", function(info)
      events_received.start = info
    end)
    
    service.emitter:on("data", function(data)
      table.insert(events_received.data, data)
    end)
    
    service.emitter:on("complete", function(info)
      events_received.complete = info
    end)
    
    service.emitter:on("stop", function(info)
      events_received.stop = info
    end)
    
    -- Start the service
    service:start()
    
    -- Wait for start event
    wait_until(function() return events_received.start ~= false end)
    
    -- Wait for complete event
    wait_until(function() return events_received.complete ~= false end)
    
    -- Stop the service
    service:stop()
    
    -- Wait for stop event
    wait_until(function() return events_received.stop ~= false end)
    
    -- Check event results
    expect(events_received.start).to.exist()
    expect(events_received.start.time).to.be.a("number")
    
    expect(#events_received.data).to.equal(5)
    expect(events_received.data[1].id).to.equal(1)
    expect(events_received.data[5].id).to.equal(5)
    
    expect(events_received.complete).to.exist()
    expect(events_received.complete.count).to.equal(5)
    
    expect(events_received.stop).to.exist()
    expect(events_received.stop.time).to.be.a("number")
  end)
  
  it_async("can process one-time events correctly", function()
    local emitter = EventEmitter.create()
    local handler_called = 0
    
    -- Register one-time handler
    emitter:once("test", function()
      handler_called = handler_called + 1
    end)
    
    -- Emit event multiple times
    emitter:emit("test")
    emitter:emit("test")
    emitter:emit("test")
    
    -- Wait for any async processing
    await(10)
    
    -- Handler should only be called once
    expect(handler_called).to.equal(1)
  end)
end)
```

## Conclusion

These examples demonstrate the range of async testing capabilities available in the Firmo framework. By using these patterns, you can effectively test asynchronous code including callbacks, promises, timers, and event-based systems.

For a complete reference of the async API, see the [Async Module API Reference](/docs/api/async.md).

For best practices and usage guidelines, see the [Async Testing Guide](/docs/guides/async.md).