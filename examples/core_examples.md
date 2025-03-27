# Core Module Examples

This document provides practical examples of using Firmo's core testing functionality.

## Basic Test Structure

### Simple Test File

```lua
-- calculator_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Simple calculator functions for testing
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then error("Cannot divide by zero") end
    return a / b
  end
}

-- Test suite
describe("Calculator", function()
  it("adds two numbers", function()
    expect(calculator.add(2, 3)).to.equal(5)
  end)
  
  it("subtracts two numbers", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
  end)
  
  it("multiplies two numbers", function()
    expect(calculator.multiply(2, 3)).to.equal(6)
  end)
  
  it("divides two numbers", function()
    expect(calculator.divide(6, 2)).to.equal(3)
  end)
  
  it("throws error when dividing by zero", function()
    expect(function() calculator.divide(5, 0) end).to.fail()
  end)
end)
```

### Using the Test Alias

```lua
-- test_alias_example.lua
local firmo = require("firmo")
local describe, test, expect = firmo.describe, firmo.test, firmo.expect

describe("String utilities", function()
  test("concatenates strings", function()
    expect("Hello" .. " World").to.equal("Hello World")
  end)
  
  test("converts to uppercase", function()
    expect(string.upper("hello")).to.equal("HELLO")
  end)
end)
```

## Nested Test Groups

### Organizing Related Tests

```lua
-- string_utils_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("String Utilities", function()
  describe("Case conversion", function()
    it("converts to uppercase", function()
      expect(string.upper("hello")).to.equal("HELLO")
    end)
    
    it("converts to lowercase", function()
      expect(string.lower("HELLO")).to.equal("hello")
    end)
  end)
  
  describe("Concatenation", function()
    it("joins two strings", function()
      expect("Hello" .. " World").to.equal("Hello World")
    end)
    
    it("joins multiple strings", function()
      expect("a" .. "b" .. "c").to.equal("abc")
    end)
  end)
  
  describe("Substring operations", function()
    it("extracts substring", function()
      expect(string.sub("Hello World", 1, 5)).to.equal("Hello")
    end)
    
    it("finds string position", function()
      expect(string.find("Hello World", "World")).to.equal(7)
    end)
  end)
end)
```

### Deep Nesting

```lua
-- deep_nesting_test.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Application", function()
  describe("User module", function()
    describe("Authentication", function()
      describe("Password validation", function()
        it("requires minimum length", function()
          local is_valid = function(password) return #password >= 8 end
          expect(is_valid("short")).to.be_falsy()
          expect(is_valid("long_enough")).to.be_truthy()
        end)
        
        it("requires at least one number", function()
          local has_number = function(password) return password:match("%d") ~= nil end
          expect(has_number("password")).to.be_falsy()
          expect(has_number("password123")).to.be_truthy()
        end)
      end)
      
      describe("Token generation", function()
        it("creates tokens of correct length", function()
          local generate_token = function(length) return string.rep("x", length) end
          expect(#generate_token(32)).to.equal(32)
        end)
      end)
    end)
  end)
end)
```

## Setup and Teardown

### Basic Setup and Teardown

```lua
-- setup_teardown_example.lua
local firmo = require("firmo")
local describe, it, before, after, expect = firmo.describe, firmo.it, firmo.before, firmo.after, firmo.expect

describe("Array operations", function()
  local array
  
  before(function()
    -- Initialize before each test
    array = {1, 2, 3}
  end)
  
  it("adds an element", function()
    table.insert(array, 4)
    expect(array[4]).to.equal(4)
    expect(#array).to.equal(4)
  end)
  
  it("removes an element", function()
    table.remove(array, 1)
    expect(array[1]).to.equal(2)
    expect(#array).to.equal(2)
  end)
  
  after(function()
    -- Clean up after each test
    array = nil
  end)
end)
```

### File Management Example

```lua
-- file_operations_test.lua
local firmo = require("firmo")
local describe, it, before, after, expect = firmo.describe, firmo.it, firmo.before, firmo.after, firmo.expect

describe("File operations", function()
  local test_file = "test_file.txt"
  
  before(function()
    -- Create a test file before each test
    local file = io.open(test_file, "w")
    file:write("Initial content")
    file:close()
  end)
  
  it("reads file content", function()
    local file = io.open(test_file, "r")
    local content = file:read("*all")
    file:close()
    expect(content).to.equal("Initial content")
  end)
  
  it("appends to file", function()
    local file = io.open(test_file, "a")
    file:write(" with appended text")
    file:close()
    
    file = io.open(test_file, "r")
    local content = file:read("*all")
    file:close()
    expect(content).to.equal("Initial content with appended text")
  end)
  
  after(function()
    -- Remove the test file after each test
    os.remove(test_file)
  end)
end)
```

### Multiple Setup and Teardown Hooks

```lua
-- multiple_hooks_example.lua
local firmo = require("firmo")
local describe, it, before, after, expect = firmo.describe, firmo.it, firmo.before, firmo.after, firmo.expect

describe("Database operations", function()
  local connection
  local test_records = {}
  
  before(function()
    -- First setup function - establish connection
    print("Connecting to database")
    connection = {
      connected = true,
      execute = function(self, query) 
        print("Executing: " .. query)
        return true
      end,
      disconnect = function(self)
        self.connected = false
        print("Disconnected from database")
      end
    }
  end)
  
  before(function()
    -- Second setup function - prepare test data
    print("Creating test records")
    connection:execute("CREATE TABLE test_table (id INTEGER, value TEXT)")
    
    for i = 1, 3 do
      table.insert(test_records, {id = i, value = "test" .. i})
      connection:execute(string.format("INSERT INTO test_table VALUES (%d, '%s')", i, "test" .. i))
    end
  end)
  
  it("inserts records", function()
    expect(connection.connected).to.be.truthy()
    expect(#test_records).to.equal(3)
  end)
  
  after(function()
    -- First teardown function - clean up data
    print("Removing test data")
    connection:execute("DROP TABLE test_table")
    test_records = {}
  end)
  
  after(function()
    -- Second teardown function - close connection
    print("Closing database connection")
    connection:disconnect()
  end)
end)
```

## Nested Setup and Teardown

```lua
-- nested_hooks_example.lua
local firmo = require("firmo")
local describe, it, before, after, expect = firmo.describe, firmo.it, firmo.before, firmo.after, firmo.expect

describe("User management", function()
  local users = {}
  
  before(function()
    print("Parent before: Initializing user system")
    users = {
      active = {},
      add = function(self, user)
        table.insert(self.active, user)
      end,
      remove = function(self, username)
        for i, user in ipairs(self.active) do
          if user.username == username then
            table.remove(self.active, i)
            return true
          end
        end
        return false
      end
    }
  end)
  
  it("starts with no users", function()
    expect(#users.active).to.equal(0)
  end)
  
  describe("Adding users", function()
    local new_user
    
    before(function()
      print("Child before: Preparing new user")
      new_user = {username = "john", email = "john@example.com"}
    end)
    
    it("adds a user successfully", function()
      users:add(new_user)
      expect(#users.active).to.equal(1)
      expect(users.active[1].username).to.equal("john")
    end)
    
    after(function()
      print("Child after: Cleaning up added user")
      users:remove("john")
    end)
  end)
  
  it("ends with no users", function()
    expect(#users.active).to.equal(0)
  end)
  
  after(function()
    print("Parent after: Shutting down user system")
    users = nil
  end)
end)
```

## Test Organization with Tags

```lua
-- tagged_tests_example.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("API Client", function()
  -- Apply tags to all tests in this describe block
  firmo.tags("api", "integration")
  
  it("initializes correctly", function()
    expect(true).to.be.truthy()
  end)
  
  describe("Authentication", function()
    -- These tests inherit parent tags and add "auth" tag
    firmo.tags("auth")
    
    it("logs in with valid credentials", function()
      expect(true).to.be.truthy()
    end)
    
    it("rejects invalid credentials", function()
      expect(false).to.be_falsy()
    end)
  end)
  
  describe("Data retrieval", function()
    -- These tests inherit parent tags and add "data" tag
    firmo.tags("data")
    
    it("fetches user profile", function()
      expect(true).to.be.truthy()
    end)
    
    it("handles missing data gracefully", function()
      expect(true).to.be.truthy()
    end)
    
    -- Add a "slow" tag just to this test
    it("paginates large result sets", function()
      firmo.tags("slow")
      expect(true).to.be.truthy()
    end)
  end)
end)
```

## Advanced Test Patterns

### Shared Setup Functions

```lua
-- shared_setup_example.lua
local firmo = require("firmo")
local describe, it, before, after, expect = firmo.describe, firmo.it, firmo.before, firmo.after, firmo.expect

-- Create a shared setup module
local TestSetup = {}

function TestSetup.create_test_environment()
  local env = {
    config = {
      api_url = "https://test-api.example.com",
      timeout = 1000,
      debug = true
    },
    fixtures = {
      users = {
        {id = 1, name = "Test User 1"},
        {id = 2, name = "Test User 2"}
      }
    },
    cleanup = function(self)
      self.fixtures = nil
      self.config = nil
    end
  }
  return env
end

-- Use shared setup in tests
describe("API Module", function()
  local env
  
  before(function()
    env = TestSetup.create_test_environment()
  end)
  
  it("connects to API", function()
    expect(env.config.api_url).to.equal("https://test-api.example.com")
  end)
  
  it("loads user fixtures", function()
    expect(env.fixtures.users).to.have_length(2)
    expect(env.fixtures.users[1].name).to.equal("Test User 1")
  end)
  
  after(function()
    env:cleanup()
  end)
end)
```

### Custom Test Helpers

```lua
-- test_helpers_example.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Define test helpers
local helpers = {}

function helpers.assert_deep_equal(actual, expected, path)
  path = path or "root"
  
  -- Check type
  if type(actual) ~= type(expected) then
    error(string.format("Type mismatch at %s: expected %s, got %s", 
          path, type(expected), type(actual)))
  end
  
  -- For tables, compare each key
  if type(actual) == "table" then
    for k, v in pairs(expected) do
      if actual[k] == nil then
        error(string.format("Missing key at %s.%s", path, tostring(k)))
      end
      helpers.assert_deep_equal(actual[k], v, path .. "." .. tostring(k))
    end
    
    -- Check for extra keys in actual
    for k, v in pairs(actual) do
      if expected[k] == nil then
        error(string.format("Unexpected key at %s.%s", path, tostring(k)))
      end
    end
  else
    -- For non-tables, compare values directly
    if actual ~= expected then
      error(string.format("Value mismatch at %s: expected %s, got %s", 
            path, tostring(expected), tostring(actual)))
    end
  end
  
  return true
end

-- Use helpers in tests
describe("Complex Data Structures", function()
  it("correctly processes nested data", function()
    local expected = {
      users = {
        {id = 1, name = "Alice", permissions = {"read", "write"}},
        {id = 2, name = "Bob", permissions = {"read"}}
      },
      settings = {
        theme = "dark",
        notifications = true
      }
    }
    
    local actual = {
      users = {
        {id = 1, name = "Alice", permissions = {"read", "write"}},
        {id = 2, name = "Bob", permissions = {"read"}}
      },
      settings = {
        theme = "dark",
        notifications = true
      }
    }
    
    -- Use our custom helper
    expect(function() helpers.assert_deep_equal(actual, expected) end).to_not.fail()
    
    -- Introduce a difference
    actual.users[1].permissions[1] = "admin"
    
    -- Should now fail
    expect(function() helpers.assert_deep_equal(actual, expected) end).to.fail()
  end)
end)
```

### Conditional Tests

```lua
-- conditional_tests_example.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Platform-specific functionality", function()
  -- Determine the operating system
  local is_windows = package.config:sub(1,1) == '\\'
  local is_unix = not is_windows
  
  -- Run tests conditionally based on platform
  if is_windows then
    it("uses Windows path separators", function()
      local path_separator = '\\'
      expect(path_separator).to.equal('\\')
    end)
    
    it("accesses Windows registry", function()
      local function check_registry() return true end
      expect(check_registry()).to.be.truthy()
    end)
  end
  
  if is_unix then
    it("uses Unix path separators", function()
      local path_separator = '/'
      expect(path_separator).to.equal('/')
    end)
    
    it("checks file permissions", function()
      local function check_permissions() return true end
      expect(check_permissions()).to.be.truthy()
    end)
  end
  
  -- Tests that run on all platforms
  it("works across all platforms", function()
    expect(true).to.be.truthy()
  end)
end)
```

## Test Organization Styles

### Behavior-Driven Development Style

```lua
-- bdd_style_example.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("User authentication", function()
  describe("When logging in with valid credentials", function()
    it("should return a valid session token", function()
      local login = function() return {token = "valid-token"} end
      local result = login()
      expect(result.token).to.exist()
      expect(result.token).to.equal("valid-token")
    end)
    
    it("should not return an error message", function()
      local login = function() return {token = "valid-token"} end
      local result = login()
      expect(result.error).to_not.exist()
    end)
  end)
  
  describe("When logging in with invalid credentials", function()
    it("should not return a token", function()
      local login = function() return {error = "Invalid credentials"} end
      local result = login()
      expect(result.token).to_not.exist()
    end)
    
    it("should return an appropriate error message", function()
      local login = function() return {error = "Invalid credentials"} end
      local result = login()
      expect(result.error).to.exist()
      expect(result.error).to.equal("Invalid credentials")
    end)
  end)
end)
```

### State-Based Testing Style

```lua
-- state_testing_example.lua
local firmo = require("firmo")
local describe, it, before, after, expect = firmo.describe, firmo.it, firmo.before, firmo.after, firmo.expect

describe("Shopping Cart", function()
  local cart
  
  before(function()
    -- Initialize with empty cart
    cart = {
      items = {},
      total = 0,
      add_item = function(self, item)
        table.insert(self.items, item)
        self.total = self.total + item.price
      end,
      remove_item = function(self, index)
        local item = self.items[index]
        if item then
          table.remove(self.items, index)
          self.total = self.total - item.price
          return true
        end
        return false
      end,
      clear = function(self)
        self.items = {}
        self.total = 0
      end
    }
  end)
  
  describe("Initial state", function()
    it("starts with no items", function()
      expect(#cart.items).to.equal(0)
    end)
    
    it("starts with zero total", function()
      expect(cart.total).to.equal(0)
    end)
  end)
  
  describe("After adding items", function()
    before(function()
      cart:add_item({name = "Product 1", price = 10})
      cart:add_item({name = "Product 2", price = 15})
    end)
    
    it("contains the correct number of items", function()
      expect(#cart.items).to.equal(2)
    end)
    
    it("calculates the correct total", function()
      expect(cart.total).to.equal(25)
    end)
    
    describe("After removing an item", function()
      before(function()
        cart:remove_item(1)
      end)
      
      it("contains one less item", function()
        expect(#cart.items).to.equal(1)
      end)
      
      it("updates the total correctly", function()
        expect(cart.total).to.equal(15)
      end)
    end)
    
    after(function()
      cart:clear()
    end)
  end)
  
  describe("After clearing", function()
    before(function()
      cart:add_item({name = "Product 1", price = 10})
      cart:clear()
    end)
    
    it("contains no items", function()
      expect(#cart.items).to.equal(0)
    end)
    
    it("resets total to zero", function()
      expect(cart.total).to.equal(0)
    end)
  end)
end)
```

## Conclusion

These examples demonstrate the flexibility and power of Firmo's core testing functionality. By effectively using `describe`, `it`, `before`, and `after`, you can create well-organized, maintainable tests that clearly document your code's behavior.

Key takeaways:
1. Use nested `describe` blocks to organize tests hierarchically
2. Use `before` and `after` hooks for setup and teardown
3. Keep tests focused on specific behaviors
4. Use tags to categorize tests for selective running
5. Create helpers for common testing patterns
6. Structure tests to reflect your application's architecture and behavior