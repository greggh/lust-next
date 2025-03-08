-- Example demonstrating enhanced assertions in lust-next
package.path = "../?.lua;" .. package.path
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- This example shows all the enhanced assertions available in lust-next
describe("Enhanced Assertions Examples", function()
  
  -- Table assertions demonstration
  describe("Table Assertions", function()
    it("demonstrates key and value assertions", function()
      local user = {
        id = 1,
        name = "John",
        email = "john@example.com",
        roles = {"admin", "user"}
      }
      
      -- Check for specific key
      expect(user).to.contain.key("id")
      expect(user).to.contain.key("name")
      
      -- Check for multiple keys
      expect(user).to.contain.keys({"id", "name", "email"})
      
      -- Check for specific value
      expect(user).to.contain.value("John")
      
      -- Check for multiple values
      expect(user.roles).to.contain.values({"admin", "user"})
      
      -- Subset testing
      local partial_user = {id = 1, name = "John"}
      expect(partial_user).to.contain.subset(user)
      
      -- Exact keys testing
      expect({a = 1, b = 2}).to.contain.exactly({"a", "b"})
    end)
  end)
  
  -- String assertions demonstration
  describe("String Assertions", function()
    it("demonstrates string prefix and suffix testing", function()
      local text = "Hello, world!"
      
      -- Test string prefix
      expect(text).to.start_with("Hello")
      expect(text).to_not.start_with("World")
      
      -- Test string suffix
      expect(text).to.end_with("world!")
      expect(text).to_not.end_with("Hello")
      
      -- Multiple assertions on the same value
      expect(text).to.be.a("string")
      expect(text).to.start_with("Hello")
      expect(text).to.end_with("world!")
    end)
  end)
  
  -- Type assertions demonstration
  describe("Type Assertions", function()
    it("demonstrates advanced type checking", function()
      -- Basic callable check
      local function my_func() return true end
      expect(my_func).to.be_type("callable")
      
      -- Callable tables (with metatable)
      local callable_obj = setmetatable({}, {
        __call = function(self, ...) return "called" end
      })
      expect(callable_obj).to.be_type("callable")
      
      -- Comparable values
      expect(1).to.be_type("comparable")
      expect("abc").to.be_type("comparable")
      
      -- Iterable values
      expect({1, 2, 3}).to.be_type("iterable")
      expect({a = 1, b = 2}).to.be_type("iterable")
    end)
  end)
  
  -- Numeric comparisons demonstration
  describe("Numeric Assertions", function()
    it("demonstrates numeric comparison assertions", function()
      -- Greater than
      expect(10).to.be_greater_than(5)
      
      -- Less than
      expect(5).to.be_less_than(10)
      
      -- Between range (inclusive)
      expect(5).to.be_between(1, 10)
      expect(5).to.be_between(5, 10) -- Inclusive lower bound
      expect(10).to.be_between(5, 10) -- Inclusive upper bound
      
      -- Approximate equality (for floating point)
      expect(0.1 + 0.2).to.be_approximately(0.3, 0.0001)
      
      -- Multiple assertions on the same value
      local value = 7.5
      expect(value).to.be_greater_than(5)
      expect(value).to.be_less_than(10)
      expect(value).to.be_between(5, 10)
      expect(value).to.be_approximately(7.5, 0)
    end)
  end)
  
  -- Error assertions demonstration
  describe("Error Assertions", function()
    it("demonstrates error testing assertions", function()
      -- Function that throws an error
      local function divide(a, b)
        if b == 0 then
          error("Division by zero")
        end
        return a / b
      end
      
      -- Test that function throws any error
      expect(function() divide(10, 0) end).to.throw.error()
      
      -- Test for specific error message pattern
      expect(function() divide(10, 0) end).to.throw.error_matching("zero")
      
      -- Test error type
      expect(function() divide(10, 0) end).to.throw.error_type("string")
      
      -- Test that function doesn't throw
      expect(function() divide(10, 5) end).to_not.throw.error()
      
      -- Custom errors
      local function custom_error()
        error({
          code = 500,
          message = "Server error"
        })
      end
      
      expect(custom_error).to.throw.error_type("table")
    end)
  end)
  
  -- Real world example - API response validation
  describe("API Response Validation Example", function()
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
    
    it("validates complex API response structure", function()
      -- Basic response validation
      expect(api_response).to.contain.keys({"success", "data", "meta"})
      expect(api_response.success).to.be.truthy()
      
      -- Data structure validation
      expect(api_response.data).to.contain.keys({"users", "pagination"})
      
      -- Array length validation
      expect(#api_response.data.users).to.equal(3)
      
      -- Check specific values
      expect(api_response.data.pagination).to.contain.key("page")
      expect(api_response.data.pagination.page).to.equal(1)
      
      -- Check for a user with specific ID
      local found_user = false
      for _, user in ipairs(api_response.data.users) do
        if user.id == 2 then
          found_user = user
          break
        end
      end
      
      expect(found_user).to.exist()
      expect(found_user).to.contain.key("name")
      expect(found_user.name).to.equal("Bob")
      
      -- Type validations
      expect(api_response.meta.version).to.be.a("string")
      expect(api_response.meta.generated_at).to.start_with("2023")
    end)
  end)
end)

print("\nEnhanced assertions examples completed!")