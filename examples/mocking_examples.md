# Firmo Mocking Examples

This file contains practical examples of using Firmo's mocking system for different test scenarios. Each example demonstrates a specific feature or pattern.

## Table of Contents

1. [Basic Spy Examples](#basic-spy-examples)
2. [Basic Stub Examples](#basic-stub-examples)
3. [Basic Mock Examples](#basic-mock-examples)
4. [Sequential Return Values](#sequential-return-values)
5. [Testing Database Access](#testing-database-access)
6. [Testing API Clients](#testing-api-clients)
7. [Testing Asynchronous Code](#testing-asynchronous-code)
8. [Testing Error Conditions](#testing-error-conditions)
9. [Call Order Verification](#call-order-verification)
10. [Using with_mocks Context](#using-with_mocks-context)
11. [Integration with Expect](#integration-with-expect)

## Basic Spy Examples

Spies track function calls without changing behavior, which is useful for verifying interactions.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy = firmo.spy

describe("Basic Spy Examples", function()
  it("tracks function calls without changing behavior", function()
    -- Create a function to spy on
    local calculate = function(a, b)
      return a + b
    end
    
    -- Create a spy
    local spy_calculate = spy(calculate)
    
    -- Call the function through the spy
    local result = spy_calculate(5, 3)
    
    -- Function still works normally
    expect(result).to.equal(8)
    
    -- But calls are tracked
    expect(spy_calculate.called).to.be_truthy()
    expect(spy_calculate.call_count).to.equal(1)
    expect(spy_calculate.calls[1][1]).to.equal(5)
    expect(spy_calculate.calls[1][2]).to.equal(3)
  end)
  
  it("can spy on object methods", function()
    -- Create an object with a method
    local calculator = {
      add = function(a, b) 
        return a + b 
      end
    }
    
    -- Spy on the method
    local add_spy = spy(calculator, "add")
    
    -- Call the method
    local result = calculator.add(7, 2)
    
    -- Method still works
    expect(result).to.equal(9)
    
    -- But calls are tracked
    expect(add_spy.called).to.be_truthy()
    expect(add_spy.calls[1][1]).to.equal(7)
    expect(add_spy.calls[1][2]).to.equal(2)
    
    -- Restore original method
    add_spy:restore()
  end)
  
  it("can check for specific call patterns", function()
    -- Create a spy
    local logger = function() end
    local spy_logger = spy(logger)
    
    -- Make various calls
    spy_logger("info", "User logged in")
    spy_logger("error", "Database connection failed")
    spy_logger("info", "User logged out")
    
    -- Check call count
    expect(spy_logger.call_count).to.equal(3)
    
    -- Check specific arguments
    expect(spy_logger:called_with("info", "User logged in")).to.be_truthy()
    expect(spy_logger:called_with("error")).to.be_truthy()
    expect(spy_logger:called_with("debug")).to.equal(false)
    
    -- Get the last call
    local last_call = spy_logger:last_call()
    expect(last_call[1]).to.equal("info")
    expect(last_call[2]).to.equal("User logged out")
  end)
end)
```

## Basic Stub Examples

Stubs replace functions with controlled implementations for predictable test behavior.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local stub = firmo.stub

describe("Basic Stub Examples", function()
  it("returns fixed values", function()
    -- Create a stub that returns a fixed value
    local get_user = stub({ id = 1, name = "Test User" })
    
    -- Call the stub
    local user = get_user()
    
    -- Returns our fixed value
    expect(user.id).to.equal(1)
    expect(user.name).to.equal("Test User")
    
    -- Tracking still works
    expect(get_user.called).to.be_truthy()
    expect(get_user.call_count).to.equal(1)
  end)
  
  it("implements custom behavior", function()
    -- Create a stub with custom implementation
    local multiply = stub(function(a, b)
      return a * b
    end)
    
    -- Call the stub
    local result = multiply(4, 5)
    
    -- Returns result from our implementation
    expect(result).to.equal(20)
  end)
  
  it("can replace object methods", function()
    -- Create an object
    local calculator = {
      add = function(a, b) return a + b end,
      subtract = function(a, b) return a - b end
    }
    
    -- Create a stub for the add method
    local add_stub = stub.on(calculator, "add", function(a, b)
      return a * b  -- Different behavior for testing
    end)
    
    -- Call the stubbed method
    local result = calculator.add(4, 5)
    
    -- Should use our stub implementation
    expect(result).to.equal(20)  -- 4 * 5, not 4 + 5
    
    -- Subtract still uses original implementation
    expect(calculator.subtract(10, 4)).to.equal(6)
    
    -- Restore original method
    add_stub:restore()
    
    -- Now uses original implementation again
    expect(calculator.add(4, 5)).to.equal(9)
  end)
  
  it("can configure return values in multiple ways", function()
    -- Create an initial stub
    local config_stub = stub("default")
    expect(config_stub()).to.equal("default")
    
    -- Change return value
    local new_stub = config_stub:returns("new value")
    expect(new_stub()).to.equal("new value")
    
    -- Create a stub that throws an error
    local error_stub = stub():throws("Test error")
    expect(function() error_stub() end).to.throw()
    
    -- Create a stub that returns its arguments
    local echo_stub = stub(function(...) return ... end)
    local a, b = echo_stub("hello", "world")
    expect(a).to.equal("hello")
    expect(b).to.equal("world")
  end)
end)
```

## Basic Mock Examples

Mocks combine stubbing with verification for comprehensive testing.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock = firmo.mock
local test_helper = require("lib.tools.test_helper")

describe("Basic Mock Examples", function()
  it("can create a complete mock object", function()
    -- Create a sample service
    local user_service = {
      get_user = function(id) 
        -- Would normally access database
        return { id = id, name = "Real User" }
      end,
      save_user = function(user)
        -- Would normally save to database
        return true
      end
    }
    
    -- Create a mock of the service
    local mock_service = mock(user_service)
    
    -- Stub the get_user method
    mock_service:stub("get_user", function(id)
      return { id = id, name = "Mock User", is_mock = true }
    end)
    
    -- Stub the save_user method
    mock_service:stub("save_user", function(user)
      -- In reality we're not saving anything
      return true
    end)
    
    -- Use the mock
    local user = user_service.get_user(123)
    local result = user_service.save_user({ id = 123, name = "Updated User" })
    
    -- Verify results
    expect(user.is_mock).to.be_truthy()
    expect(user.name).to.equal("Mock User")
    expect(result).to.equal(true)
    
    -- Verify the mock was called correctly
    expect(mock_service._stubs.get_user.call_count).to.equal(1)
    expect(mock_service._stubs.get_user.calls[1][1]).to.equal(123)
    expect(mock_service._stubs.save_user.called).to.be_truthy()
    
    -- Use the verify method to check all expectations
    expect(mock_service:verify()).to.be_truthy()
    
    -- Clean up
    mock_service:restore()
  end)
  
  it("can stub specific methods while preserving others", function()
    -- Create a calculator object
    local calculator = {
      add = function(a, b) return a + b end,
      subtract = function(a, b) return a - b end,
      multiply = function(a, b) return a * b end,
      divide = function(a, b) return a / b end
    }
    
    -- Create a mock
    local mock_calc = mock(calculator)
    
    -- Only stub methods we want to override
    mock_calc:stub("divide", function(a, b)
      if b == 0 then
        return 0 -- Instead of raising an error
      end
      return a / b
    end)
    
    -- Original methods work as before
    expect(calculator.add(5, 3)).to.equal(8)
    expect(calculator.subtract(10, 4)).to.equal(6)
    expect(calculator.multiply(2, 3)).to.equal(6)
    
    -- Stubbed method uses our implementation
    expect(calculator.divide(10, 2)).to.equal(5)
    expect(calculator.divide(10, 0)).to.equal(0) -- Would normally error
    
    -- Restore all methods
    mock_calc:restore()
  end)
  
  it("can verify specific stubs were called", { expect_error = true }, function()
    -- Create an object with methods
    local notifier = {
      send_email = function() end,
      send_sms = function() end,
      log_message = function() end
    }
    
    -- Create a mock
    local mock_notifier = mock(notifier)
    
    -- Stub all methods
    mock_notifier:stub("send_email", function() return true end)
    mock_notifier:stub("send_sms", function() return true end)
    mock_notifier:stub("log_message", function() return true end)
    
    -- Only call some methods
    notifier.send_email("user@example.com", "Test")
    notifier.log_message("Email sent")
    
    -- Individual verification passes for called methods
    expect(mock_notifier._stubs.send_email.called).to.be_truthy()
    expect(mock_notifier._stubs.log_message.called).to.be_truthy()
    
    -- But full verification fails because send_sms wasn't called
    local _, err = test_helper.with_error_capture(function()
      mock_notifier:verify()
    end)()
    
    expect(err).to.exist()
    expect(err.message).to.match("send_sms")
    
    -- Clean up
    mock_notifier:restore()
  end)
end)
```

## Sequential Return Values

Return different values from successive calls to a stub.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local stub, mock = firmo.stub, firmo.mock

describe("Sequential Return Values", function()
  it("returns values in sequence", function()
    -- Create a stub with sequential returns
    local status_stub = stub():returns_in_sequence({
      "connecting",
      "authenticating",
      "connected",
      "ready"
    })
    
    -- Call multiple times
    expect(status_stub()).to.equal("connecting")
    expect(status_stub()).to.equal("authenticating")
    expect(status_stub()).to.equal("connected")
    expect(status_stub()).to.equal("ready")
    
    -- Sequence is exhausted, returns nil
    expect(status_stub()).to.equal(nil)
  end)
  
  it("can use functions in sequences", function()
    -- Create a stub with both values and functions
    local process_stub = stub():returns_in_sequence({
      "starting",
      function(input)
        return "processing: " .. input
      end,
      "completed"
    })
    
    -- Call in sequence
    expect(process_stub()).to.equal("starting")
    expect(process_stub("test data")).to.equal("processing: test data")
    expect(process_stub()).to.equal("completed")
  end)
  
  it("can cycle through sequences", function()
    -- Create a cycling stub
    local light_stub = stub()
      :returns_in_sequence({"red", "yellow", "green"})
      :cycle_sequence(true)
    
    -- Values cycle
    expect(light_stub()).to.equal("red")
    expect(light_stub()).to.equal("yellow")
    expect(light_stub()).to.equal("green")
    expect(light_stub()).to.equal("red") -- Cycles back
    expect(light_stub()).to.equal("yellow")
  end)
  
  it("can reset sequences", function()
    -- Create a sequence stub
    local counter_stub = stub():returns_in_sequence({1, 2, 3})
    
    -- Use the sequence
    expect(counter_stub()).to.equal(1)
    expect(counter_stub()).to.equal(2)
    
    -- Reset in the middle
    counter_stub:reset_sequence()
    
    -- Starts again from beginning
    expect(counter_stub()).to.equal(1)
    expect(counter_stub()).to.equal(2)
    expect(counter_stub()).to.equal(3)
  end)
  
  it("can use custom behavior when sequence is exhausted", function()
    -- Default behavior returns nil when exhausted
    local stub1 = stub():returns_in_sequence({"a", "b"})
    expect(stub1()).to.equal("a")
    expect(stub1()).to.equal("b")
    expect(stub1()).to.equal(nil)
    
    -- Custom value when exhausted
    local stub2 = stub()
      :returns_in_sequence({"a", "b"})
      :when_exhausted("custom", "exhausted")
    
    expect(stub2()).to.equal("a")
    expect(stub2()).to.equal("b")
    expect(stub2()).to.equal("exhausted")
    
    -- Use original implementation when exhausted
    local original_fn = function() return "original" end
    local obj = { method = original_fn }
    
    local mock_obj = mock(obj)
    mock_obj:stub_in_sequence("method", {"stubbed1", "stubbed2"})
      :when_exhausted("fallback")
    
    expect(obj.method()).to.equal("stubbed1")
    expect(obj.method()).to.equal("stubbed2")
    expect(obj.method()).to.equal("original") -- Falls back to original
  end)
end)
```

## Testing Database Access

Mock database connections and queries for reliable testing.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, with_mocks = firmo.mock, firmo.with_mocks

-- Create a sample database client
local DatabaseClient = {
  new = function(config)
    return {
      config = config,
      
      connect = function(self)
        -- In reality would connect to a real database
        print("Connecting to " .. self.config.host)
        return { connected = true }
      end,
      
      query = function(self, query_string, params)
        -- In reality would execute a database query
        print("Executing query: " .. query_string)
        return { rows = {}, affected = 0 }
      end,
      
      disconnect = function(self)
        -- In reality would close the connection
        print("Disconnecting")
      end
    }
  end
}

-- Create a service that uses the database
local UserRepository = {
  new = function(db_client)
    return {
      db = db_client,
      
      get_users = function(self)
        local conn = self.db:connect()
        local result = self.db:query("SELECT * FROM users")
        self.db:disconnect()
        return result.rows
      end,
      
      find_user = function(self, id)
        local conn = self.db:connect()
        local result = self.db:query("SELECT * FROM users WHERE id = ?", {id})
        self.db:disconnect()
        
        if #result.rows == 0 then
          return nil
        end
        
        return result.rows[1]
      end,
      
      create_user = function(self, user)
        local conn = self.db:connect()
        local result = self.db:query(
          "INSERT INTO users (name, email) VALUES (?, ?)",
          {user.name, user.email}
        )
        self.db:disconnect()
        
        return { 
          success = result.affected > 0,
          user_id = result.last_insert_id or 0
        }
      end
    }
  end
}

describe("Database Access Testing", function()
  it("retrieves users from database", function()
    with_mocks(function(mock_fn)
      -- Create a database client
      local db_client = DatabaseClient.new({
        host = "localhost",
        user = "test_user",
        password = "password",
        database = "test_db"
      })
      
      -- Mock the database client
      local mock_db = mock_fn(db_client)
      
      -- Stub the methods
      mock_db:stub("connect", function(self)
        return { connected = true }
      end)
      
      mock_db:stub("query", function(self, query_string, params)
        if query_string:match("SELECT %* FROM users") then
          return {
            rows = {
              { id = 1, name = "User 1", email = "user1@example.com" },
              { id = 2, name = "User 2", email = "user2@example.com" }
            },
            affected = 0
          }
        end
        
        return { rows = {}, affected = 0 }
      end)
      
      mock_db:stub("disconnect", function(self)
        -- Do nothing for testing
      end)
      
      -- Create a user repository with our mocked client
      local repo = UserRepository.new(db_client)
      
      -- Test get_users method
      local users = repo:get_users()
      
      -- Verify results
      expect(users).to.exist()
      expect(#users).to.equal(2)
      expect(users[1].name).to.equal("User 1")
      expect(users[2].email).to.equal("user2@example.com")
      
      -- Verify interactions
      expect(mock_db._stubs.connect.called).to.be_truthy()
      expect(mock_db._stubs.query.called).to.be_truthy()
      expect(mock_db._stubs.query.calls[1][2]).to.match("SELECT %* FROM users")
      expect(mock_db._stubs.disconnect.called).to.be_truthy()
    end)
  end)
  
  it("finds a specific user by ID", function()
    with_mocks(function(mock_fn)
      -- Create a database client
      local db_client = DatabaseClient.new({
        host = "localhost",
        user = "test_user",
        password = "password",
        database = "test_db"
      })
      
      -- Mock the database client
      local mock_db = mock_fn(db_client)
      
      -- Stub the methods
      mock_db:stub("connect", function(self)
        return { connected = true }
      end)
      
      mock_db:stub("query", function(self, query_string, params)
        if query_string:match("WHERE id = %?") and params and params[1] == 1 then
          return {
            rows = {
              { id = 1, name = "User 1", email = "user1@example.com" }
            },
            affected = 0
          }
        elseif query_string:match("WHERE id = %?") and params and params[1] == 999 then
          -- User not found
          return { rows = {}, affected = 0 }
        end
        
        return { rows = {}, affected = 0 }
      end)
      
      mock_db:stub("disconnect", function(self)
        -- Do nothing for testing
      end)
      
      -- Create a user repository with our mocked client
      local repo = UserRepository.new(db_client)
      
      -- Test find_user method with existing user
      local user = repo:find_user(1)
      
      -- Verify results for existing user
      expect(user).to.exist()
      expect(user.id).to.equal(1)
      expect(user.name).to.equal("User 1")
      
      -- Test find_user method with non-existent user
      local non_existent = repo:find_user(999)
      
      -- Verify results for non-existent user
      expect(non_existent).to.equal(nil)
      
      -- Verify all interactions
      expect(mock_db._stubs.connect.call_count).to.equal(2)
      expect(mock_db._stubs.query.call_count).to.equal(2)
      expect(mock_db._stubs.disconnect.call_count).to.equal(2)
    end)
  end)
end)
```

## Testing API Clients

Mock HTTP clients to test API integrations without network access.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, with_mocks = firmo.mock, firmo.with_mocks
local test_helper = require("lib.tools.test_helper")

-- Create a sample HTTP client
local HttpClient = {
  request = function(method, url, options)
    -- In reality would make a real HTTP request
    print("Making " .. method .. " request to " .. url)
    return { 
      status = 200,
      body = "{}"
    }
  end,
  
  get = function(url, options)
    return HttpClient.request("GET", url, options)
  end,
  
  post = function(url, data, options)
    local options = options or {}
    options.data = data
    return HttpClient.request("POST", url, options)
  end
}

-- Create a weather API client that uses the HTTP client
local WeatherClient = {
  new = function(http_client, api_key)
    return {
      http = http_client,
      api_key = api_key,
      base_url = "https://api.weather.example/v1",
      
      get_current_weather = function(self, city)
        local url = self.base_url .. "/current?city=" .. city .. "&api_key=" .. self.api_key
        
        local response = self.http.get(url)
        
        if response.status ~= 200 then
          return nil, { 
            message = "Failed to get weather data",
            status = response.status
          }
        end
        
        -- Parse JSON response (simplified for example)
        local data = response.body
        if type(data) == "string" then
          -- In a real application, we'd parse the JSON here
          data = response.parsed_body or {}
        end
        
        return {
          temperature = data.temperature,
          conditions = data.conditions,
          location = data.location,
          updated_at = data.updated_at
        }
      end,
      
      get_forecast = function(self, city, days)
        days = days or 5
        
        local url = self.base_url .. "/forecast?city=" .. city 
                  .. "&days=" .. days .. "&api_key=" .. self.api_key
        
        local response = self.http.get(url)
        
        if response.status ~= 200 then
          return nil, { 
            message = "Failed to get forecast data",
            status = response.status
          }
        end
        
        -- Parse JSON response (simplified for example)
        local data = response.body
        if type(data) == "string" then
          -- In a real application, we'd parse the JSON here
          data = response.parsed_body or { forecast = {} }
        end
        
        return data.forecast
      end
    }
  end
}

describe("API Client Testing", function()
  it("gets current weather successfully", function()
    with_mocks(function(mock_fn)
      -- Mock the HTTP client
      local mock_http = mock_fn(HttpClient)
      
      -- Stub the get method to return test data
      mock_http:stub("get", function(url)
        -- Verify URL contains expected parameters
        expect(url).to.match("api.weather.example")
        expect(url).to.match("city=London")
        expect(url).to.match("api_key=test_key")
        
        -- Return mock response
        return {
          status = 200,
          body = {
            temperature = 22.5,
            conditions = "Cloudy",
            location = "London, UK",
            updated_at = "2025-03-26T12:00:00Z"
          },
          -- Skip JSON parsing for test
          parsed_body = {
            temperature = 22.5,
            conditions = "Cloudy",
            location = "London, UK",
            updated_at = "2025-03-26T12:00:00Z"
          }
        }
      end)
      
      -- Create weather client with mocked HTTP client
      local weather = WeatherClient.new(HttpClient, "test_key")
      
      -- Call the method under test
      local current = weather:get_current_weather("London")
      
      -- Verify results
      expect(current).to.exist()
      expect(current.temperature).to.equal(22.5)
      expect(current.conditions).to.equal("Cloudy")
      expect(current.location).to.equal("London, UK")
      
      -- Verify HTTP client was called correctly
      expect(mock_http._stubs.get.call_count).to.equal(1)
      expect(mock_http._stubs.get.calls[1][1]).to.match("London")
    end)
  end)
  
  it("handles API errors gracefully", function()
    with_mocks(function(mock_fn)
      -- Mock the HTTP client
      local mock_http = mock_fn(HttpClient)
      
      -- Stub the get method to return an error
      mock_http:stub("get", function(url)
        return {
          status = 401,
          body = {
            error = "Invalid API key"
          }
        }
      end)
      
      -- Create weather client
      local weather = WeatherClient.new(HttpClient, "invalid_key")
      
      -- Call the method under test
      local current, error_info = weather:get_current_weather("London")
      
      -- Verify error handling
      expect(current).to.equal(nil)
      expect(error_info).to.exist()
      expect(error_info.status).to.equal(401)
      expect(error_info.message).to.match("Failed to get weather data")
    end)
  end)
  
  it("gets weather forecast for multiple days", function()
    with_mocks(function(mock_fn)
      -- Mock the HTTP client
      local mock_http = mock_fn(HttpClient)
      
      -- Stub the get method with sequential responses for forecast
      mock_http:stub("get", function(url)
        -- If URL contains "forecast", return forecast data
        if url:match("forecast") then
          return {
            status = 200,
            body = {
              forecast = {
                { 
                  date = "2025-03-26", 
                  high = 24, 
                  low = 18, 
                  conditions = "Partly Cloudy" 
                },
                { 
                  date = "2025-03-27", 
                  high = 22, 
                  low = 17, 
                  conditions = "Rain" 
                },
                { 
                  date = "2025-03-28", 
                  high = 20, 
                  low = 15, 
                  conditions = "Rain" 
                }
              }
            },
            parsed_body = {
              forecast = {
                { 
                  date = "2025-03-26", 
                  high = 24, 
                  low = 18, 
                  conditions = "Partly Cloudy" 
                },
                { 
                  date = "2025-03-27", 
                  high = 22, 
                  low = 17, 
                  conditions = "Rain" 
                },
                { 
                  date = "2025-03-28", 
                  high = 20, 
                  low = 15, 
                  conditions = "Rain" 
                }
              }
            }
          }
        else
          -- Default response for other endpoints
          return { status = 200, body = {} }
        end
      end)
      
      -- Create weather client
      local weather = WeatherClient.new(HttpClient, "test_key")
      
      -- Call the method under test
      local forecast = weather:get_forecast("London", 3)
      
      -- Verify results
      expect(forecast).to.exist()
      expect(#forecast).to.equal(3)
      expect(forecast[1].date).to.equal("2025-03-26")
      expect(forecast[2].conditions).to.equal("Rain")
      expect(forecast[3].high).to.equal(20)
    end)
  end)
end)
```

## Testing Asynchronous Code

Mock asynchronous operations for deterministic testing.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, with_mocks = firmo.mock, firmo.with_mocks
local test_helper = require("lib.tools.test_helper")
local task = require("lib.async.task") -- Fictitious async task library

-- Simulated task module for the example
task = {
  create = function(fn, timeout)
    return {
      id = math.random(1000, 9999),
      fn = fn,
      timeout = timeout or 0,
      is_completed = false,
      result = nil,
      
      run = function(self)
        self.is_completed = true
        self.result = self.fn()
        return self.result
      end
    }
  end,
  
  schedule = function(fn, timeout)
    local new_task = task.create(fn, timeout)
    -- Would normally schedule for later execution
    print("Scheduled task " .. new_task.id .. " to run in " .. timeout .. "ms")
    return new_task
  end,
  
  cancel = function(task_id)
    -- Would normally cancel a scheduled task
    print("Cancelled task " .. task_id)
    return true
  end
}

-- Create an async task manager
local TaskManager = {
  new = function(task_module)
    return {
      task = task_module,
      tasks = {},
      results = {},
      
      schedule = function(self, name, fn, timeout)
        local task_obj = self.task.schedule(fn, timeout)
        self.tasks[name] = task_obj
        return task_obj.id
      end,
      
      run_task = function(self, name)
        local task_obj = self.tasks[name]
        if not task_obj then
          return nil, "Task not found"
        end
        
        local result = task_obj:run()
        self.results[name] = result
        return result
      end,
      
      cancel_task = function(self, name)
        local task_obj = self.tasks[name]
        if not task_obj then
          return false
        end
        
        self.task.cancel(task_obj.id)
        self.tasks[name] = nil
        return true
      end,
      
      get_results = function(self)
        return self.results
      end
    }
  end
}

describe("Asynchronous Code Testing", function()
  it("schedules tasks with appropriate timeouts", function()
    with_mocks(function(mock_fn)
      -- Mock the task module
      local mock_task = mock_fn(task)
      
      -- Keep track of scheduled tasks
      local scheduled_tasks = {}
      
      -- Stub the schedule method
      mock_task:stub("schedule", function(fn, timeout)
        -- Create a task object
        local task_obj = {
          id = #scheduled_tasks + 1,
          fn = fn,
          timeout = timeout,
          is_completed = false,
          result = nil,
          
          run = function(self)
            self.is_completed = true
            self.result = self.fn()
            return self.result
          end
        }
        
        table.insert(scheduled_tasks, task_obj)
        return task_obj
      end)
      
      -- Create task manager with mocked task module
      local manager = TaskManager.new(task)
      
      -- Schedule some tasks
      local task1_id = manager:schedule("fetch_data", function() return "data" end, 1000)
      local task2_id = manager:schedule("process_data", function() return "processed" end, 2000)
      
      -- Verify tasks were scheduled with correct timeouts
      expect(mock_task._stubs.schedule.call_count).to.equal(2)
      expect(scheduled_tasks[1].timeout).to.equal(1000)
      expect(scheduled_tasks[2].timeout).to.equal(2000)
      
      -- Run the first task
      local result = manager:run_task("fetch_data")
      expect(result).to.equal("data")
      
      -- Check the results collection
      local results = manager:get_results()
      expect(results.fetch_data).to.equal("data")
      expect(results.process_data).to.equal(nil) -- Not run yet
    end)
  end)
  
  it("handles task cancellation", function()
    with_mocks(function(mock_fn)
      -- Mock the task module
      local mock_task = mock_fn(task)
      
      -- Stub methods
      mock_task:stub("schedule", function(fn, timeout)
        return {
          id = 123,
          fn = fn,
          timeout = timeout,
          is_completed = false
        }
      end)
      
      mock_task:stub("cancel", function(task_id)
        expect(task_id).to.equal(123)
        return true
      end)
      
      -- Create task manager
      local manager = TaskManager.new(task)
      
      -- Schedule a task
      manager:schedule("background_task", function() return "bg result" end, 5000)
      
      -- Cancel the task
      local canceled = manager:cancel_task("background_task")
      
      -- Verify cancellation
      expect(canceled).to.be_truthy()
      expect(mock_task._stubs.cancel.called).to.be_truthy()
      
      -- Try to run the canceled task
      local result, err = manager:run_task("background_task")
      expect(result).to.equal(nil)
      expect(err).to.equal("Task not found")
    end)
  end)
  
  it("manages multiple tasks with different statuses", function()
    with_mocks(function(mock_fn)
      -- Mock the task module
      local mock_task = mock_fn(task)
      
      -- Create a collection of test tasks
      local test_tasks = {}
      
      -- Stub schedule to track tasks
      mock_task:stub("schedule", function(fn, timeout)
        local task_id = #test_tasks + 1
        local task_obj = {
          id = task_id,
          fn = fn,
          timeout = timeout,
          is_completed = false,
          result = nil,
          
          run = function(self)
            self.is_completed = true
            self.result = self.fn()
            return self.result
          end
        }
        
        table.insert(test_tasks, task_obj)
        return task_obj
      end)
      
      -- Create task manager
      local manager = TaskManager.new(task)
      
      -- Schedule multiple tasks
      manager:schedule("task1", function() return "result1" end, 100)
      manager:schedule("task2", function() return "result2" end, 200)
      manager:schedule("task3", function() return "result3" end, 300)
      
      -- Run some tasks but not others
      manager:run_task("task1")
      manager:run_task("task3")
      
      -- Verify results
      local results = manager:get_results()
      expect(results.task1).to.equal("result1")
      expect(results.task2).to.equal(nil) -- Not run
      expect(results.task3).to.equal("result3")
      
      -- Verify task completion status
      expect(test_tasks[1].is_completed).to.be_truthy()
      expect(test_tasks[2].is_completed).to.equal(false)
      expect(test_tasks[3].is_completed).to.be_truthy()
    end)
  end)
end)
```

## Testing Error Conditions

Simulate errors for testing error handling.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local mock, stub, with_mocks = firmo.mock, firmo.stub, firmo.with_mocks
local test_helper = require("lib.tools.test_helper")

-- Create a file service that might encounter errors
local FileService = {
  new = function(file_system)
    return {
      fs = file_system,
      
      read_config = function(self, path)
        -- Check if file exists
        if not self.fs.exists(path) then
          return nil, { code = "FILE_NOT_FOUND", message = "Config file not found" }
        end
        
        -- Read file content
        local content, err = self.fs.read_file(path)
        if not content then
          return nil, { code = "READ_ERROR", message = "Failed to read config file" }
        end
        
        -- Parse JSON (simplified for example)
        local config = self.fs.parse_json(content)
        if not config then
          return nil, { code = "PARSE_ERROR", message = "Invalid JSON in config file" }
        end
        
        return config
      end,
      
      save_config = function(self, path, config)
        -- Convert to JSON
        local content = self.fs.serialize_json(config)
        if not content then
          return nil, { code = "SERIALIZE_ERROR", message = "Failed to serialize config" }
        end
        
        -- Write to file
        local success, err = self.fs.write_file(path, content)
        if not success then
          return nil, { code = "WRITE_ERROR", message = "Failed to write config file" }
        end
        
        return true
      end
    }
  end
}

-- Mock file system for testing
local FileSystem = {
  exists = function(path)
    -- In reality would check if file exists
    return true
  end,
  
  read_file = function(path)
    -- In reality would read file from disk
    return '{"setting": "value"}'
  end,
  
  write_file = function(path, content)
    -- In reality would write to disk
    return true
  end,
  
  parse_json = function(content)
    -- In reality would parse JSON properly
    return { setting = "value" }
  end,
  
  serialize_json = function(data)
    -- In reality would serialize to JSON properly
    return '{"setting":"value"}'
  end
}

describe("Error Condition Testing", function()
  it("handles missing config file", { expect_error = true }, function()
    with_mocks(function(mock_fn)
      -- Mock the file system
      local mock_fs = mock_fn(FileSystem)
      
      -- Make exists return false to simulate missing file
      mock_fs:stub("exists", function(path)
        return false
      end)
      
      -- Create service with mocked file system
      local service = FileService.new(FileSystem)
      
      -- Test with error capture
      local result, err = test_helper.with_error_capture(function()
        return service:read_config("/config.json")
      end)()
      
      -- Verify error handling
      expect(result).to.equal(nil)
      expect(err).to.exist()
      expect(err.code).to.equal("FILE_NOT_FOUND")
      
      -- Verify exists was called
      expect(mock_fs._stubs.exists.called).to.be_truthy()
      
      -- Other methods should not have been called
      expect(mock_fs._stubs.read_file).to.equal(nil)
    end)
  end)
  
  it("handles read errors", { expect_error = true }, function()
    with_mocks(function(mock_fn)
      -- Mock the file system
      local mock_fs = mock_fn(FileSystem)
      
      -- Exists returns true
      mock_fs:stub("exists", function(path)
        return true
      end)
      
      -- But read_file returns an error
      mock_fs:stub("read_file", function(path)
        return nil, "Permission denied"
      end)
      
      -- Create service with mocked file system
      local service = FileService.new(FileSystem)
      
      -- Test with error capture
      local result, err = test_helper.with_error_capture(function()
        return service:read_config("/config.json")
      end)()
      
      -- Verify error handling
      expect(result).to.equal(nil)
      expect(err).to.exist()
      expect(err.code).to.equal("READ_ERROR")
      
      -- Verify method calls
      expect(mock_fs._stubs.exists.called).to.be_truthy()
      expect(mock_fs._stubs.read_file.called).to.be_truthy()
      
      -- Parse should not have been called
      expect(mock_fs._stubs.parse_json).to.equal(nil)
    end)
  end)
  
  it("handles invalid JSON", { expect_error = true }, function()
    with_mocks(function(mock_fn)
      -- Mock the file system
      local mock_fs = mock_fn(FileSystem)
      
      -- All methods succeed until parse_json
      mock_fs:stub("exists", function(path) return true end)
      mock_fs:stub("read_file", function(path) return '{invalid json}' end)
      mock_fs:stub("parse_json", function(content) return nil end)
      
      -- Create service with mocked file system
      local service = FileService.new(FileSystem)
      
      -- Test with error capture
      local result, err = test_helper.with_error_capture(function()
        return service:read_config("/config.json")
      end)()
      
      -- Verify error handling
      expect(result).to.equal(nil)
      expect(err).to.exist()
      expect(err.code).to.equal("PARSE_ERROR")
      
      -- Verify method calls
      expect(mock_fs._stubs.exists.called).to.be_truthy()
      expect(mock_fs._stubs.read_file.called).to.be_truthy()
      expect(mock_fs._stubs.parse_json.called).to.be_truthy()
    end)
  end)
  
  it("throws exception from stub", { expect_error = true }, function()
    with_mocks(function(mock_fn)
      -- Mock the file system
      local mock_fs = mock_fn(FileSystem)
      
      -- Make write_file throw an error
      mock_fs:stub("write_file", function(path, content)
        error("Disk full")
      end)
      
      -- Other methods work normally
      mock_fs:stub("serialize_json", function(data)
        return '{"setting":"value"}'
      end)
      
      -- Create service with mocked file system
      local service = FileService.new(FileSystem)
      
      -- Test with error capture to catch the thrown error
      local success, err = pcall(function()
        service:save_config("/config.json", { setting = "value" })
      end)
      
      -- Verify error was caught
      expect(success).to.equal(false)
      expect(err).to.match("Disk full")
      
      -- Verify method calls
      expect(mock_fs._stubs.serialize_json.called).to.be_truthy()
      expect(mock_fs._stubs.write_file.called).to.be_truthy()
    end)
  end)
  
  it("uses stub.throws for error simulation", { expect_error = true }, function()
    -- Create a standalone stub with throws
    local error_stub = stub():throws("Database connection error")
    
    -- Test with error capture
    local success, err = pcall(function()
      error_stub()
    end)
    
    -- Verify error was thrown
    expect(success).to.equal(false)
    expect(err).to.match("Database connection error")
    
    -- Use in a mock context
    with_mocks(function(mock_fn)
      local db = {
        query = function() return { rows = {} } end
      }
      
      local mock_db = mock_fn(db)
      
      -- Use stub.throws with mock
      mock_db:stub("query", function()
        error("Query timeout")
      end)
      
      -- Attempt to use the stubbed method
      local success, err = pcall(function()
        db.query("SELECT * FROM users")
      end)
      
      -- Verify error was thrown
      expect(success).to.equal(false)
      expect(err).to.match("Query timeout")
    end)
  end)
end)
```

## Call Order Verification

Verify that functions are called in the expected order.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy, mock, with_mocks = firmo.spy, firmo.mock, firmo.with_mocks

-- Create a service with multiple operations
local OrderProcessor = {
  new = function(inventory, payment, notification)
    return {
      inventory = inventory,
      payment = payment,
      notification = notification,
      
      process_order = function(self, order)
        -- Check inventory first
        local items_available = self.inventory.check_availability(order.items)
        if not items_available then
          return { success = false, reason = "out_of_stock" }
        end
        
        -- Process payment
        local payment_result = self.payment.process(order.payment, order.total)
        if not payment_result.success then
          return { success = false, reason = "payment_failed" }
        end
        
        -- Reserve inventory
        local reserved = self.inventory.reserve(order.items)
        if not reserved then
          -- Refund payment if inventory reservation fails
          self.payment.refund(payment_result.transaction_id)
          return { success = false, reason = "inventory_error" }
        end
        
        -- Send confirmation
        self.notification.send_confirmation(order.customer_email, {
          order_id = order.id,
          items = order.items,
          total = order.total
        })
        
        return { 
          success = true,
          transaction_id = payment_result.transaction_id
        }
      end
    }
  end
}

-- Create the services used by the order processor
local InventoryService = {
  check_availability = function(items)
    -- Would check database in real implementation
    return true
  end,
  
  reserve = function(items)
    -- Would update inventory in real implementation
    return true
  end
}

local PaymentService = {
  process = function(payment_info, amount)
    -- Would call payment gateway in real implementation
    return { success = true, transaction_id = "tx_123456" }
  end,
  
  refund = function(transaction_id)
    -- Would process refund in real implementation
    return true
  end
}

local NotificationService = {
  send_confirmation = function(email, order_details)
    -- Would send email in real implementation
    return true
  end
}

describe("Call Order Verification", function()
  it("calls services in the correct order for successful order", function()
    with_mocks(function(mock_fn, spy_fn, stub_fn)
      -- Create spies on all services
      local inventory_spy = spy_fn(InventoryService)
      local payment_spy = spy_fn(PaymentService)
      local notification_spy = spy_fn(NotificationService)
      
      -- Create an order processor with the spied services
      local processor = OrderProcessor.new(
        InventoryService,
        PaymentService,
        NotificationService
      )
      
      -- Create a test order
      local order = {
        id = "order_123",
        customer_email = "customer@example.com",
        items = {
          { id = "item1", quantity = 2 },
          { id = "item2", quantity = 1 }
        },
        payment = {
          method = "credit_card",
          number = "4111111111111111",
          expiry = "12/25"
        },
        total = 99.99
      }
      
      -- Process the order
      local result = processor:process_order(order)
      
      -- Verify the result
      expect(result.success).to.be_truthy()
      expect(result.transaction_id).to.equal("tx_123456")
      
      -- Verify correct call order
      expect(inventory_spy.check_availability).to.be.called_before(payment_spy.process)
      expect(payment_spy.process).to.be.called_before(inventory_spy.reserve)
      expect(inventory_spy.reserve).to.be.called_before(notification_spy.send_confirmation)
      
      -- Verify all expected methods were called
      expect(inventory_spy.check_availability.called).to.be_truthy()
      expect(payment_spy.process.called).to.be_truthy()
      expect(inventory_spy.reserve.called).to.be_truthy()
      expect(notification_spy.send_confirmation.called).to.be_truthy()
      
      -- Payment refund should NOT have been called
      expect(payment_spy.refund).to.equal(nil)
    end)
  end)
  
  it("handles inventory errors with correct sequence", function()
    with_mocks(function(mock_fn)
      -- Create mock services for inventory error scenario
      local mock_inventory = mock_fn(InventoryService)
      mock_inventory:stub("check_availability", function(items)
        return true  -- Items are available
      end)
      mock_inventory:stub("reserve", function(items)
        return false  -- But reservation fails
      end)
      
      local mock_payment = mock_fn(PaymentService)
      mock_payment:stub("process", function(payment_info, amount)
        return { success = true, transaction_id = "tx_123456" }
      end)
      mock_payment:stub("refund", function(transaction_id)
        expect(transaction_id).to.equal("tx_123456")
        return true
      end)
      
      local mock_notification = mock_fn(NotificationService)
      mock_notification:stub("send_confirmation", function(email, order_details)
        return true
      end)
      
      -- Create processor with mock services
      local processor = OrderProcessor.new(
        InventoryService,
        PaymentService,
        NotificationService
      )
      
      -- Create a test order
      local order = {
        id = "order_123",
        customer_email = "customer@example.com",
        items = {
          { id = "item1", quantity = 2 },
          { id = "item2", quantity = 1 }
        },
        payment = {
          method = "credit_card",
          number = "4111111111111111",
          expiry = "12/25"
        },
        total = 99.99
      }
      
      -- Process the order
      local result = processor:process_order(order)
      
      -- Verify the result
      expect(result.success).to.equal(false)
      expect(result.reason).to.equal("inventory_error")
      
      -- Verify all expected methods were called and in correct order
      expect(mock_inventory._stubs.check_availability.called).to.be_truthy()
      expect(mock_payment._stubs.process.called).to.be_truthy()
      expect(mock_inventory._stubs.reserve.called).to.be_truthy()
      expect(mock_payment._stubs.refund.called).to.be_truthy()
      
      -- Notification should NOT have been called
      expect(mock_notification._stubs.send_confirmation).to.equal(nil)
      
      -- Check refund was called after reservation failed
      expect(mock_inventory._stubs.reserve)
        .to.be.called_before(mock_payment._stubs.refund)
    end)
  end)
  
  it("skips later steps when early checks fail", function()
    with_mocks(function(mock_fn)
      -- Create mock services for out of stock scenario
      local mock_inventory = mock_fn(InventoryService)
      mock_inventory:stub("check_availability", function(items)
        return false  -- Items not available
      end)
      
      local mock_payment = mock_fn(PaymentService)
      mock_payment:stub("process", function(payment_info, amount)
        return { success = true, transaction_id = "tx_123456" }
      end)
      
      local mock_notification = mock_fn(NotificationService)
      mock_notification:stub("send_confirmation", function(email, order_details)
        return true
      end)
      
      -- Create processor with mock services
      local processor = OrderProcessor.new(
        InventoryService,
        PaymentService,
        NotificationService
      )
      
      -- Create a test order
      local order = {
        id = "order_123",
        items = { { id = "item1", quantity = 99999 } }, -- Unrealistic quantity
        payment = { method = "credit_card" },
        total = 99.99
      }
      
      -- Process the order
      local result = processor:process_order(order)
      
      -- Verify the result
      expect(result.success).to.equal(false)
      expect(result.reason).to.equal("out_of_stock")
      
      -- Verify only check_availability was called
      expect(mock_inventory._stubs.check_availability.called).to.be_truthy()
      
      -- Later methods should not be called
      expect(mock_payment._stubs.process).to.equal(nil)
      expect(mock_inventory._stubs.reserve).to.equal(nil)
      expect(mock_notification._stubs.send_confirmation).to.equal(nil)
    end)
  end)
end)
```

## Using with_mocks Context

The `with_mocks` context manager provides automatic cleanup of mocks.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local with_mocks = firmo.with_mocks
local test_helper = require("lib.tools.test_helper")

-- Create a simple service for demonstration
local UserService = {
  get_user = function(id)
    -- Would get user from database
    return { id = id, name = "Real User" }
  end,
  
  update_user = function(user)
    -- Would update user in database
    return true
  end,
  
  delete_user = function(id)
    -- Would delete user from database
    return true
  end
}

describe("with_mocks Context Manager", function()
  it("provides mocking capabilities", function()
    -- Store original method for comparison
    local original_get_user = UserService.get_user
    
    with_mocks(function(mock_fn, spy_fn, stub_fn)
      -- Create a mock for our service
      local mock_service = mock_fn(UserService)
      
      -- Stub methods
      mock_service:stub("get_user", function(id)
        return { id = id, name = "Mock User", is_mock = true }
      end)
      
      -- Use the mock
      local user = UserService.get_user(123)
      
      -- Verify stub was used
      expect(user.is_mock).to.be_truthy()
      expect(user.name).to.equal("Mock User")
      
      -- Verify the mock was called correctly
      expect(mock_service._stubs.get_user.called).to.be_truthy()
      expect(mock_service._stubs.get_user.calls[1][1]).to.equal(123)
    end)
    
    -- Outside the context, original method is restored
    expect(UserService.get_user).to.equal(original_get_user)
    
    -- Using the original method
    local real_user = UserService.get_user(456)
    expect(real_user.name).to.equal("Real User")
  end)
  
  it("provides spy capabilities", function()
    with_mocks(function(mock_fn, spy_fn, stub_fn)
      -- Create a spy on a method
      local get_user_spy = spy_fn(UserService, "get_user")
      
      -- Use the method
      local user = UserService.get_user(789)
      
      -- Method still works normally
      expect(user.id).to.equal(789)
      expect(user.name).to.equal("Real User")
      
      -- But calls are tracked
      expect(get_user_spy.called).to.be_truthy()
      expect(get_user_spy.calls[1][1]).to.equal(789)
    end)
  end)
  
  it("provides stub capabilities", function()
    with_mocks(function(mock_fn, spy_fn, stub_fn)
      -- Create a standalone stub
      local get_data = stub_fn({ value = "test data" })
      
      -- Use the stub
      local data = get_data()
      
      -- Verify stub works
      expect(data.value).to.equal("test data")
      expect(get_data.called).to.be_truthy()
      
      -- Stub an object method
      local update_stub = stub_fn.on(UserService, "update_user", function(user)
        expect(user.id).to.equal(999)
        return true, "Updated successfully"
      end)
      
      -- Use the stubbed method
      local result, message = UserService.update_user({ id = 999, name = "Updated" })
      
      -- Verify stub was used
      expect(result).to.equal(true)
      expect(message).to.equal("Updated successfully")
      expect(update_stub.called).to.be_truthy()
    end)
  end)
  
  it("cleans up even when an error occurs", { expect_error = true }, function()
    -- Store original method for comparison
    local original_delete_user = UserService.delete_user
    
    -- Wrap in pcall to catch the error but still verify cleanup
    local success, err = pcall(function()
      with_mocks(function(mock_fn)
        -- Create a mock
        local mock_service = mock_fn(UserService)
        
        -- Stub a method
        mock_service:stub("delete_user", function(id)
          return true, "Deleted"
        end)
        
        -- Verify stub works
        local result, message = UserService.delete_user(123)
        expect(result).to.equal(true)
        expect(message).to.equal("Deleted")
        
        -- Throw an error
        error("Test error")
        
        -- This code is never reached
      end)
    end)
    
    -- The error should be propagated
    expect(success).to.equal(false)
    expect(err).to.match("Test error")
    
    -- But the mock should still be cleaned up
    expect(UserService.delete_user).to.equal(original_delete_user)
  end)
  
  it("supports multiple concurrent mocks", function()
    with_mocks(function(mock_fn)
      -- Create multiple mocks in one context
      local data_service = {
        get_data = function() return "real data" end
      }
      
      local log_service = {
        log = function(message) end
      }
      
      local api_client = {
        fetch = function(url) return { status = 200 } end
      }
      
      -- Mock all three services
      local mock_data = mock_fn(data_service)
      local mock_log = mock_fn(log_service)
      local mock_api = mock_fn(api_client)
      
      -- Stub methods
      mock_data:stub("get_data", function() return "mock data" end)
      mock_log:stub("log", function(message) end)
      mock_api:stub("fetch", function(url) return { status = 200, mock = true } end)
      
      -- Use all the mocks
      expect(data_service.get_data()).to.equal("mock data")
      log_service.log("Test message")
      local response = api_client.fetch("https://example.com")
      
      -- Verify all mocks were called
      expect(mock_data._stubs.get_data.called).to.be_truthy()
      expect(mock_log._stubs.log.called).to.be_truthy()
      expect(mock_api._stubs.fetch.called).to.be_truthy()
      expect(response.mock).to.be_truthy()
    end)
  end)
end)
```

## Integration with Expect

Firmo's mocking system integrates with the expectation library for fluent assertions.

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy, mock, with_mocks = firmo.spy, firmo.mock, firmo.with_mocks

describe("Expect Integration", function()
  it("provides expect assertions for spies", function()
    -- Create a spy
    local fn = function(a, b) return a + b end
    local spy_fn = spy(fn)
    
    -- Call the spy
    spy_fn(5, 3)
    spy_fn(10, 2)
    
    -- Use expect assertions
    expect(spy_fn).to.be.called()
    expect(spy_fn).to.be.called.times(2)
    expect(spy_fn).to.be.called.with(5, 3)
    expect(spy_fn).to_not.be.called.with(1, 2)
    
    -- Create another spy for order verification
    local another_fn = function() end
    local another_spy = spy(another_fn)
    
    -- Call in specific order
    spy_fn(1, 1)
    another_spy()
    
    -- Verify order
    expect(spy_fn).to.be.called.before(another_spy)
    expect(another_spy).to.be.called.after(spy_fn)
  end)
  
  it("provides expect assertions for stubs", function()
    -- Create a stub
    local stub_fn = firmo.stub("stubbed value")
    
    -- Call the stub
    local result = stub_fn()
    
    -- Basic assertions
    expect(result).to.equal("stubbed value")
    expect(stub_fn).to.be.called()
    expect(stub_fn).to.be.called.once()
    
    -- Create a stub with sequence
    local sequence_stub = firmo.stub():returns_in_sequence({1, 2, 3})
    
    -- Call and verify
    expect(sequence_stub()).to.equal(1)
    expect(sequence_stub()).to.equal(2)
    expect(sequence_stub).to.be.called.times(2)
  end)
  
  it("provides expect assertions for mocks", function()
    with_mocks(function(mock_fn)
      -- Create a mock
      local service = {
        get_data = function() return "real data" end,
        process = function(data) return "processed: " .. data end
      }
      
      local mock_service = mock_fn(service)
      
      -- Stub methods
      mock_service:stub("get_data", function() return "mock data" end)
      mock_service:stub("process", function(data) return "mock processed: " .. data end)
      
      -- Use the mock
      service.get_data()
      service.process("test")
      
      -- Use expect assertions
      expect(mock_service._stubs.get_data).to.be.called()
      expect(mock_service._stubs.process).to.be.called.with("test")
      expect(mock_service._stubs.get_data).to.be.called.before(mock_service._stubs.process)
      
      -- Use the verify method
      expect(mock_service:verify()).to.be_truthy()
    end)
  end)
  
  it("supports matchers for flexible assertions", function()
    -- Create a spy
    local logger = function(level, message) end
    local spy_logger = spy(logger)
    
    -- Call with various values
    spy_logger("info", "User logged in")
    spy_logger("warning", "Disk space low")
    spy_logger("error", "Failed to connect")
    
    -- Use string matcher
    expect(spy_logger).to.be.called.with("info", expect.any_string())
    
    -- Use function matcher
    expect(spy_logger).to.be.called.with(
      expect.matches(function(value)
        return value == "warning" or value == "error"
      end),
      expect.contains("space") -- Contains substring
    )
    
    -- Use table matchers
    local api = function(options) end
    local spy_api = spy(api)
    
    spy_api({ timeout = 1000, retries = 3 })
    
    expect(spy_api).to.be.called.with(expect.contains({ timeout = 1000 }))
    expect(spy_api).to.be.called.with(expect.table_containing({ retries = 3 }))
  end)
  
  it("provides readable test output", function()
    -- Create multiple spies
    local login = function() end
    local validate = function() end
    local save = function() end
    
    local spy_login = spy(login)
    local spy_validate = spy(validate)
    local spy_save = spy(save)
    
    -- Call in wrong order for demonstration
    spy_save()
    spy_login()
    
    -- These assertions fail with readable messages
    if not pcall(function()
      expect(spy_login).to.be.called.before(spy_save)
    end) then
      print("User-friendly error: login was not called before save")
    end
    
    if not pcall(function()
      expect(spy_validate).to.be.called()
    end) then
      print("User-friendly error: validate was not called")
    end
  end)
end)
```