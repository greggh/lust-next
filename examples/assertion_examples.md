# Assertion Module Examples

This document provides comprehensive examples of using the assertion module in the Firmo testing framework. These examples demonstrate both basic and advanced assertion patterns.

## Basic Assertions

```lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Or using the standalone module:
-- local assertion = require("lib.assertion")
-- local expect = assertion.expect

describe("Basic Assertions", function()
  it("demonstrates equality assertions", function()
    -- Basic equality
    expect(1 + 1).to.equal(2)
    expect("hello world").to.equal("hello world")
    expect(true).to.equal(true)
    
    -- With negation
    expect(1 + 1).to_not.equal(3)
    expect("hello").to_not.equal("world")
    
    -- Floating point equality with epsilon
    expect(0.1 + 0.2).to.equal(0.3, 0.0001)
  end)
  
  it("demonstrates existence assertions", function()
    -- Check for existence (not nil)
    expect(123).to.exist()
    expect("").to.exist()      -- Empty string exists
    expect(false).to.exist()   -- False exists
    expect({}).to.exist()      -- Empty table exists
    
    -- Check for non-existence (nil)
    expect(nil).to_not.exist()
    
    local maybe_nil
    expect(maybe_nil).to_not.exist()
  end)
  
  it("demonstrates type assertions", function()
    -- Basic type checks
    expect(123).to.be.a("number")
    expect("hello").to.be.a("string")
    expect({}).to.be.a("table")
    expect(function() end).to.be.a("function")
    expect(true).to.be.a("boolean")
    
    -- Using 'an' for readability with vowels
    expect(8).to.be.an("number")
    
    -- Negated type checks
    expect("hello").to_not.be.a("number")
    expect(123).to_not.be.a("string")
  end)
  
  it("demonstrates truthiness assertions", function()
    -- Truthy values
    expect(true).to.be_truthy()
    expect(1).to.be_truthy()
    expect("hello").to.be_truthy()
    expect({}).to.be_truthy()
    
    -- Falsy values
    expect(false).to.be_falsy()
    expect(nil).to.be_falsy()
    
    -- Alternative spelling
    expect(false).to.be_falsey()
    
    -- Negated truthiness
    expect(true).to_not.be_falsy()
    expect(false).to_not.be_truthy()
  end)
  
  it("demonstrates pattern matching", function()
    -- Simple substring
    expect("hello world").to.match("hello")
    
    -- Lua patterns
    expect("test123").to.match("%a+%d+")
    expect("abc").to.match("^%a+$")
    
    -- Negated patterns
    expect("hello").to_not.match("world")
    expect("123").to_not.match("%a")
  end)
end)
```

## String Assertions

```lua
describe("String Assertions", function()
  it("demonstrates string prefix and suffix checks", function()
    -- Prefix checks
    expect("hello world").to.start_with("hello")
    expect("test123").to.start_with("test")
    expect("hello").to_not.start_with("world")
    
    -- Suffix checks
    expect("hello world").to.end_with("world")
    expect("test123").to.end_with("123")
    expect("hello").to_not.end_with("test")
  end)
  
  it("demonstrates string case assertions", function()
    -- Uppercase check
    expect("HELLO").to.be.uppercase()
    expect("Hello").to_not.be.uppercase()
    expect("").to.be.uppercase()  -- Empty string is considered uppercase
    
    -- Lowercase check
    expect("hello").to.be.lowercase()
    expect("Hello").to_not.be.lowercase()
    expect("").to.be.lowercase()  -- Empty string is considered lowercase
  end)
  
  it("demonstrates string length assertions", function()
    -- Length check
    expect("hello").to.have_length(5)
    expect("").to.have_length(0)
    
    -- Size (alias for length)
    expect("world").to.have_size(5)
    
    -- Empty check
    expect("").to.be.empty()
    expect("hello").to_not.be.empty()
  end)
  
  it("demonstrates regex assertions", function()
    -- Basic regex
    expect("hello world").to.match_regex("hello")
    
    -- Case insensitive matching
    expect("HELLO WORLD").to.match_regex("hello", { case_insensitive = true })
    
    -- Multiline matching
    local multiline_text = "First line\nSecond line\nThird line"
    expect(multiline_text).to.match_regex("^Second", { multiline = true })
    
    -- Both options together
    expect("FIRST LINE\nsecond LINE").to.match_regex("^first.*\n^second", { 
      case_insensitive = true, 
      multiline = true 
    })
  end)
  
  it("demonstrates containment assertions", function()
    -- String containment
    expect("hello world").to.contain("world")
    expect("testing 123").to.contain("123")
    expect("hello").to_not.contain("bye")
  end)
end)
```

## Table and Collection Assertions

```lua
describe("Table and Collection Assertions", function()
  it("demonstrates basic table assertions", function()
    -- Table equality (deep comparison)
    expect({1, 2, 3}).to.equal({1, 2, 3})
    expect({a = 1, b = 2}).to.equal({a = 1, b = 2})
    expect({a = 1, b = {c = 2}}).to.equal({a = 1, b = {c = 2}})
    
    -- Table inequality
    expect({1, 2, 3}).to_not.equal({1, 2, 4})
    expect({a = 1, b = 2}).to_not.equal({a = 1, b = 3})
  end)
  
  it("demonstrates table content assertions", function()
    -- Array membership
    expect({1, 2, 3}).to.contain(2)
    expect({"a", "b", "c"}).to.contain("b")
    expect({1, 2, 3}).to_not.contain(4)
    
    -- Key membership
    expect({a = 1, b = 2}).to.contain.key("a")
    expect({[1] = "a", [2] = "b"}).to.contain.key(1)
    expect({a = 1, b = 2}).to_not.contain.key("c")
    
    -- Multiple keys
    expect({a = 1, b = 2, c = 3}).to.contain.keys({"a", "b"})
    
    -- Value membership
    expect({a = 1, b = 2}).to.contain.value(1)
    expect({[1] = "a", [2] = "b"}).to.contain.value("a")
    
    -- Multiple values
    expect({1, 2, 3, x = "test"}).to.contain.values({1, 3})
  end)
  
  it("demonstrates length assertions", function()
    -- Array length
    expect({1, 2, 3}).to.have_length(3)
    expect({}).to.have_length(0)
    
    -- Size (alias for length)
    expect({1, 2, 3, 4}).to.have_size(4)
    
    -- Empty check
    expect({}).to.be.empty()
    expect({1, 2, 3}).to_not.be.empty()
  end)
  
  it("demonstrates property assertions", function()
    local user = {
      id = 1,
      name = "John",
      email = "john@example.com"
    }
    
    -- Property existence
    expect(user).to.have_property("id")
    expect(user).to.have_property("name")
    expect(user).to_not.have_property("address")
    
    -- Property value
    expect(user).to.have_property("id", 1)
    expect(user).to.have_property("name", "John")
    expect(user).to_not.have_property("email", "wrong@example.com")
  end)
  
  it("demonstrates schema validation", function()
    local user = {
      id = 1,
      name = "John",
      email = "john@example.com",
      active = true,
      roles = {"admin", "user"}
    }
    
    -- Type checking schema
    expect(user).to.match_schema({
      id = "number",
      name = "string",
      email = "string",
      active = "boolean",
      roles = "table"
    })
    
    -- Value checking schema
    expect(user).to.match_schema({
      name = "John",
      active = true
    })
    
    -- Mixed schema (type and value checks)
    expect(user).to.match_schema({
      id = "number",      -- Type check
      name = "John",      -- Exact value check
      active = true       -- Exact value check
    })
  end)
end)
```

## Numeric Assertions

```lua
describe("Numeric Assertions", function()
  it("demonstrates comparison assertions", function()
    -- Greater than
    expect(5).to.be_greater_than(3)
    expect(10).to.be_greater_than(5)
    expect(3).to_not.be_greater_than(5)
    
    -- Less than
    expect(3).to.be_less_than(5)
    expect(5).to.be_less_than(10)
    expect(5).to_not.be_less_than(3)
    
    -- Between (inclusive)
    expect(5).to.be_between(1, 10)
    expect(1).to.be_between(1, 10)  -- Boundary check
    expect(10).to.be_between(1, 10) -- Boundary check
    expect(11).to_not.be_between(1, 10)
    
    -- Approximate equality
    expect(0.1 + 0.2).to.be_approximately(0.3, 0.0001)
    expect(10).to.be_approximately(10.1, 0.2)
    expect(10).to_not.be_approximately(11, 0.5)
  end)
  
  it("demonstrates numeric property assertions", function()
    -- Positivity
    expect(5).to.be.positive()
    expect(0.1).to.be.positive()
    expect(0).to_not.be.positive()
    expect(-5).to_not.be.positive()
    
    -- Negativity
    expect(-5).to.be.negative()
    expect(-0.1).to.be.negative()
    expect(0).to_not.be.negative()
    expect(5).to_not.be.negative()
    
    -- Integer check
    expect(5).to.be.integer()
    expect(-10).to.be.integer()
    expect(0).to.be.integer()
    expect(5.5).to_not.be.integer()
    expect(-0.1).to_not.be.integer()
  end)
end)
```

## Function Assertions

```lua
describe("Function Assertions", function()
  it("demonstrates error assertions", function()
    -- Basic error check
    local function throws_error()
      error("Something went wrong")
    end
    
    expect(throws_error).to.fail()
    expect(function() error("Test error") end).to.fail()
    
    -- Error message check
    expect(function() error("Specific error") end).to.fail.with("Specific")
    expect(function() error("Wrong message") end).to_not.fail.with("Missing")
    
    -- Error type check using throw syntax
    expect(function() error("String error") end).to.throw.error()
    expect(function() error("Pattern match") end).to.throw.error_matching("Pattern")
    expect(function() error("String type") end).to.throw.error_type("string")
    
    -- Negated error check
    local function no_error()
      return true
    end
    
    expect(no_error).to_not.fail()
  end)
  
  it("demonstrates function behavior assertions", function()
    -- Change check
    local obj = {count = 0}
    expect(function() obj.count = obj.count + 1 end).to.change(function() return obj.count end)
    
    -- Custom change validation
    expect(function() obj.count = obj.count + 5 end).to.change(
      function() return obj.count end,
      function(before, after) return after - before == 5 end
    )
    
    -- No change check
    expect(function() obj.count = obj.count end).to_not.change(function() return obj.count end)
    
    -- Increase check
    local counter = {value = 10}
    expect(function() counter.value = counter.value + 1 end).to.increase(function() return counter.value end)
    
    -- Decrease check
    expect(function() counter.value = counter.value - 1 end).to.decrease(function() return counter.value end)
  end)
end)
```

## Date Assertions

```lua
describe("Date Assertions", function()
  it("demonstrates date validation assertions", function()
    -- Basic date validation
    expect("2023-10-15").to.be_date()             -- ISO format
    expect("10/15/2023").to.be_date()             -- MM/DD/YYYY format
    expect("15/10/2023").to.be_date()             -- DD/MM/YYYY format
    expect("2023-10-15T14:30:15Z").to.be_date()   -- ISO with time
    expect("not-a-date").to_not.be_date()         -- Invalid date
    
    -- ISO date validation
    expect("2023-10-15").to.be_iso_date()         -- Basic ISO format
    expect("2023-10-15T14:30:15Z").to.be_iso_date() -- ISO with time
    expect("10/15/2023").to_not.be_iso_date()     -- Not ISO format
  end)
  
  it("demonstrates date comparison assertions", function()
    -- Before comparison
    expect("2022-01-01").to.be_before("2023-01-01")
    expect("01/01/2022").to.be_before("01/01/2023")
    expect("2022-01-01").to_not.be_before("2022-01-01") -- Same date
    expect("2023-01-01").to_not.be_before("2022-01-01") -- Later date
    
    -- After comparison
    expect("2023-01-01").to.be_after("2022-01-01")
    expect("01/01/2023").to.be_after("01/01/2022")
    expect("2022-01-01").to_not.be_after("2022-01-01") -- Same date
    expect("2022-01-01").to_not.be_after("2023-01-01") -- Earlier date
    
    -- Same day comparison
    expect("2022-01-01T10:30:00Z").to.be_same_day_as("2022-01-01T15:45:00Z") -- Same day, different times
    expect("01/01/2022 10:30").to.be_same_day_as("01/01/2022 15:45")
    expect("2022-01-01").to_not.be_same_day_as("2022-01-02") -- Different days
  end)
end)
```

## Async Assertions

```lua
local async = require("lib.async")

describe("Async Assertions", function()
  it("demonstrates completion assertions", function()
    async.test(function()
      local promise = function(resolve)
        async.set_timeout(function() resolve("success") end, 10)
      end
      
      expect(promise).to.complete()
    end)
  end)
  
  it("demonstrates timeout assertions", function()
    async.test(function()
      local quick_promise = function(resolve)
        async.set_timeout(function() resolve("success") end, 10)
      end
      
      expect(quick_promise).to.complete_within(50) -- Should resolve within 50ms
      
      local slow_promise = function(resolve)
        async.set_timeout(function() resolve("success") end, 100)
      end
      
      expect(slow_promise).to_not.complete_within(20) -- Won't resolve within 20ms
    end)
  end)
  
  it("demonstrates value assertions", function()
    async.test(function()
      local promise = function(resolve)
        async.set_timeout(function() resolve("expected value") end, 10)
      end
      
      expect(promise).to.resolve_with("expected value")
      expect(promise).to_not.resolve_with("wrong value")
    end)
  end)
  
  it("demonstrates rejection assertions", function()
    async.test(function()
      local promise = function(_, reject)
        async.set_timeout(function() reject("validation failed") end, 10)
      end
      
      expect(promise).to.reject() -- Just check that it rejects
      expect(promise).to.reject("validation") -- Check error message pattern
      expect(promise).to_not.reject("wrong error") -- Doesn't match pattern
    end)
  end)
end)
```

## Real-world Examples

### API Response Validation

```lua
describe("API Response Validation", function()
  it("validates complex API response structure", function()
    -- Mock API response
    local api_response = {
      success = true,
      data = {
        users = {
          {id = 1, name = "Alice", active = true},
          {id = 2, name = "Bob", active = false},
          {id = 3, name = "Charlie", active = true}
        },
        pagination = {
          page = 1,
          per_page = 10,
          total = 3
        }
      },
      meta = {
        generated_at = "2023-05-01T12:34:56Z",
        version = "1.0"
      }
    }
    
    -- Basic response validation
    expect(api_response).to.exist()
    expect(api_response).to.be.a("table")
    expect(api_response.success).to.be_truthy()
    
    -- Data structure validation
    expect(api_response.data).to.exist()
    expect(api_response.data.users).to.be.a("table")
    expect(api_response.data.pagination).to.be.a("table")
    
    -- Array length validation
    expect(api_response.data.users).to.have_length(3)
    
    -- Check specific values
    expect(api_response.data.pagination.page).to.equal(1)
    expect(api_response.data.pagination.per_page).to.equal(10)
    
    -- Or use schema validation for more concise checks
    expect(api_response).to.match_schema({
      success = "boolean",
      data = "table",
      meta = "table"
    })
    
    expect(api_response.data).to.match_schema({
      users = "table",
      pagination = "table"
    })
    
    -- Check for a user with specific ID
    local found_user = false
    for _, user in ipairs(api_response.data.users) do
      if user.id == 2 then
        found_user = user
        break
      end
    end
    
    expect(found_user).to.exist()
    expect(found_user.name).to.equal("Bob")
    expect(found_user.active).to.equal(false)
  end)
end)
```

### Database Record Validation

```lua
describe("Database Record Validation", function()
  it("validates a user record", function()
    -- Mock user record from database
    local user = {
      id = 42,
      username = "johndoe",
      email = "john@example.com",
      created_at = "2023-01-15T10:30:00Z",
      updated_at = "2023-05-20T14:25:30Z",
      settings = {
        notifications = true,
        theme = "dark",
        language = "en"
      },
      roles = {"user", "moderator"}
    }
    
    -- Basic type validation
    expect(user.id).to.be.a("number")
    expect(user.username).to.be.a("string")
    expect(user.email).to.be.a("string")
    expect(user.settings).to.be.a("table")
    expect(user.roles).to.be.a("table")
    
    -- Email format validation
    expect(user.email).to.match("%w+@%w+%.%w+")
    
    -- Date validation
    expect(user.created_at).to.be_iso_date()
    expect(user.updated_at).to.be_iso_date()
    expect(user.created_at).to.be_before(user.updated_at)
    
    -- Role validation
    expect(user.roles).to.contain("user")
    expect(#user.roles).to.be_greater_than(0)
    
    -- Settings validation
    expect(user.settings).to.have_property("notifications", true)
    expect(user.settings).to.have_property("theme", "dark")
    
    -- Or use schema validation
    expect(user).to.match_schema({
      id = "number",
      username = "string",
      email = "string",
      created_at = "string",
      updated_at = "string",
      settings = "table",
      roles = "table"
    })
    
    expect(user.settings).to.match_schema({
      notifications = "boolean",
      theme = "string",
      language = "string"
    })
  end)
end)
```

### Error Handling Code

```lua
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

describe("Error Handling", function()
  it("demonstrates basic error validation", function()
    -- Test with manual error creation
    local function validate(value)
      if type(value) ~= "number" then
        return nil, error_handler.validation_error(
          "Expected a number",
          {provided_type = type(value)}
        )
      end
      return value
    end
    
    -- Valid case
    local result, err = validate(42)
    expect(result).to.equal(42)
    expect(err).to_not.exist()
    
    -- Invalid case
    result, err = validate("not a number")
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    expect(err.message).to.match("Expected a number")
  end)
  
  it("validates error handling with expect_error flag", { expect_error = true }, function()
    -- Function that will throw an error
    local function divide(a, b)
      if b == 0 then
        error(error_handler.create(
          "Division by zero",
          error_handler.CATEGORY.ARITHMETIC,
          error_handler.SEVERITY.ERROR,
          {operation = "divide", a = a, b = b}
        ))
      end
      return a / b
    end
    
    -- Use test_helper to safely capture errors
    local result, err = test_helper.with_error_capture(function()
      return divide(10, 0)
    end)()
    
    -- Verify the error was handled correctly
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Division by zero")
    expect(err.category).to.equal(error_handler.CATEGORY.ARITHMETIC)
    expect(err.context).to.exist()
    expect(err.context.operation).to.equal("divide")
  end)
  
  it("demonstrates error pattern testing", { expect_error = true }, function()
    -- Use test_helper.expect_error for simple error validation
    local err = test_helper.expect_error(function()
      error("Authentication failed: Invalid credentials")
    end, "Authentication failed")
    
    expect(err).to.exist()
    expect(err.message).to.match("Invalid credentials")
  end)
end)
```

### Testing State Changes

```lua
describe("State Change Testing", function()
  it("validates state changes in a counter object", function()
    local counter = {
      value = 0,
      increment = function(self, amount)
        self.value = self.value + (amount or 1)
        return self.value
      end,
      decrement = function(self, amount)
        self.value = self.value - (amount or 1)
        return self.value
      end,
      reset = function(self)
        self.value = 0
        return self.value
      end
    }
    
    -- Test increment
    expect(function() counter:increment() end).to.change(function() return counter.value end)
    expect(counter.value).to.equal(1)
    
    expect(function() counter:increment(5) end).to.change(
      function() return counter.value end,
      function(before, after) return after - before == 5 end
    )
    expect(counter.value).to.equal(6)
    
    -- Test decrement
    expect(function() counter:decrement() end).to.decrease(function() return counter.value end)
    expect(counter.value).to.equal(5)
    
    expect(function() counter:decrement(3) end).to.decrease(function() return counter.value end)
    expect(counter.value).to.equal(2)
    
    -- Test reset
    expect(function() counter:reset() end).to.change(function() return counter.value end)
    expect(counter.value).to.equal(0)
    
    -- Test no change
    expect(function() counter:reset() end).to_not.change(function() return counter.value end)
  end)
end)
```

## Advanced Assertions

### Custom Assertion Extension

```lua
describe("Custom Assertions", function()
  it("demonstrates creating and using custom assertions", function()
    local assertion = require("lib.assertion")
    
    -- Add a custom assertion for even numbers
    assertion.paths.to.be_even = {
      test = function(v)
        if type(v) ~= "number" then
          error("Expected a number, got " .. type(v))
        end
        
        return v % 2 == 0,
          "expected " .. tostring(v) .. " to be even",
          "expected " .. tostring(v) .. " to not be even"
      end
    }
    
    -- Add a custom assertion for odd numbers
    assertion.paths.to.be_odd = {
      test = function(v)
        if type(v) ~= "number" then
          error("Expected a number, got " .. type(v))
        end
        
        return v % 2 == 1,
          "expected " .. tostring(v) .. " to be odd",
          "expected " .. tostring(v) .. " to not be odd"
      end
    }
    
    -- Use the custom assertions
    assertion.expect(4).to.be_even()
    assertion.expect(5).to_not.be_even()
    
    assertion.expect(5).to.be_odd()
    assertion.expect(4).to_not.be_odd()
    
    -- They'll work with the normal expect function too if we're in a firmo test
    expect(2).to.be_even()
    expect(3).to.be_odd()
  end)
end)
```

### Helper Functions for Complex Validation

```lua
describe("Validation Helpers", function()
  it("demonstrates creating and using validation helper functions", function()
    -- Helper for checking email addresses
    local function expect_valid_email(email)
      expect(email).to.be.a("string")
      expect(email).to.match("%w+@%w+%.%w+")  -- Basic email pattern
      return true
    end
    
    -- Helper for checking user objects
    local function expect_valid_user(user)
      expect(user).to.be.a("table")
      expect(user.id).to.be.a("number")
      expect(user.name).to.be.a("string")
      expect(user.email).to.be.a("string")
      expect_valid_email(user.email)
      return true
    end
    
    -- Use helpers in tests
    local user1 = {id = 1, name = "Alice", email = "alice@example.com"}
    local user2 = {id = 2, name = "Bob", email = "bob@example.com"}
    
    expect(expect_valid_user(user1)).to.be_truthy()
    expect(expect_valid_user(user2)).to.be_truthy()
    
    -- Invalid user (helper will throw an error)
    local invalid_user = {id = 3, name = "Invalid", email = "not-an-email"}
    
    expect(function()
      expect_valid_user(invalid_user)
    end).to.fail()
  end)
end)
```

## Complete Test Suite Example

Here's a complete example of a well-structured test file for a calculator module:

```lua
-- Import firmo
local firmo = require("firmo")

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test lifecycle hooks
local before, after = firmo.before, firmo.after

-- Import module to test
local calculator = require("calculator")

-- Main test suite
describe("Calculator", function()
  -- Variables for test scope
  local calc
  
  -- Setup before each test
  before(function()
    calc = calculator.new()
  end)
  
  -- Cleanup after each test
  after(function()
    calc = nil
  end)
  
  -- Test group for addition functionality
  describe("addition", function()
    it("should add two positive numbers", function()
      expect(calc:add(2, 3)).to.equal(5)
    end)
    
    it("should handle negative numbers", function()
      expect(calc:add(-2, 3)).to.equal(1)
      expect(calc:add(2, -3)).to.equal(-1)
      expect(calc:add(-2, -3)).to.equal(-5)
    end)
    
    it("should handle zero", function()
      expect(calc:add(0, 5)).to.equal(5)
      expect(calc:add(5, 0)).to.equal(5)
      expect(calc:add(0, 0)).to.equal(0)
    end)
    
    it("should handle decimal numbers", function()
      expect(calc:add(1.5, 2.5)).to.equal(4)
      expect(calc:add(0.1, 0.2)).to.be_approximately(0.3, 0.0001)
    end)
  end)
  
  -- Test group for subtraction functionality
  describe("subtraction", function()
    it("should subtract two numbers", function()
      expect(calc:subtract(5, 3)).to.equal(2)
    end)
    
    it("should handle negative results", function()
      expect(calc:subtract(3, 5)).to.equal(-2)
    end)
    
    it("should handle negative inputs", function()
      expect(calc:subtract(-3, -5)).to.equal(2)
      expect(calc:subtract(-3, 5)).to.equal(-8)
    end)
    
    it("should handle zero", function()
      expect(calc:subtract(5, 0)).to.equal(5)
      expect(calc:subtract(0, 5)).to.equal(-5)
      expect(calc:subtract(0, 0)).to.equal(0)
    end)
  end)
  
  -- Test group for multiplication functionality
  describe("multiplication", function()
    it("should multiply two numbers", function()
      expect(calc:multiply(2, 3)).to.equal(6)
    end)
    
    it("should handle negative numbers", function()
      expect(calc:multiply(-2, 3)).to.equal(-6)
      expect(calc:multiply(2, -3)).to.equal(-6)
      expect(calc:multiply(-2, -3)).to.equal(6)
    end)
    
    it("should handle zero", function()
      expect(calc:multiply(5, 0)).to.equal(0)
      expect(calc:multiply(0, 5)).to.equal(0)
      expect(calc:multiply(0, 0)).to.equal(0)
    end)
    
    it("should handle decimal numbers", function()
      expect(calc:multiply(1.5, 2)).to.equal(3)
      expect(calc:multiply(0.1, 0.2)).to.be_approximately(0.02, 0.0001)
    end)
  end)
  
  -- Test group for division functionality with error handling
  describe("division", function()
    it("should divide two numbers", function()
      expect(calc:divide(6, 3)).to.equal(2)
      expect(calc:divide(5, 2)).to.equal(2.5)
    end)
    
    it("should handle negative numbers", function()
      expect(calc:divide(-6, 3)).to.equal(-2)
      expect(calc:divide(6, -3)).to.equal(-2)
      expect(calc:divide(-6, -3)).to.equal(2)
    end)
    
    it("should handle division by zero", { expect_error = true }, function()
      local function divide_by_zero()
        return calc:divide(5, 0)
      end
      
      expect(divide_by_zero).to.fail()
      
      -- Or alternatively with the test helper
      local result, err = test_helper.with_error_capture(divide_by_zero)()
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.match("division by zero")
    end)
  end)
  
  -- Test group for state tracking functionality
  describe("memory functionality", function()
    it("should store last result", function()
      calc:add(2, 3)
      expect(calc:get_last_result()).to.equal(5)
      
      calc:subtract(10, 4)
      expect(calc:get_last_result()).to.equal(6)
    end)
    
    it("should clear memory", function()
      calc:add(2, 3)
      expect(calc:get_last_result()).to.equal(5)
      
      calc:clear_memory()
      expect(calc:get_last_result()).to.equal(0)
    end)
    
    it("should track operations count", function()
      expect(calc:get_operations_count()).to.equal(0)
      
      calc:add(1, 1)
      expect(calc:get_operations_count()).to.equal(1)
      
      calc:subtract(5, 2)
      expect(calc:get_operations_count()).to.equal(2)
      
      -- Test state changes
      expect(function() 
        calc:add(1, 1) 
      end).to.increase(function() 
        return calc:get_operations_count() 
      end)
    end)
  end)
end)
```

## Conclusion

These examples demonstrate the wide range of assertion capabilities provided by the assertion module. You can combine these patterns to create expressive, maintainable tests for your Lua code.

For more details on the API, see the [Assertion Module API Reference](/docs/api/assertion.md).

For best practices and usage guidance, see the [Assertion Module Usage Guide](/docs/guides/assertion.md).