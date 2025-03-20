# Assertion Pattern Mapping for firmo

## Introduction

This guide provides a comprehensive reference for writing assertions in firmo. It includes detailed mappings from busted-style assertions to firmo's expect-style assertions, common mistakes to avoid, and examples of complex assertion patterns.

## Key Concepts

### Basic Structure

firmo uses **expect-style** assertions rather than assert-style assertions:

```lua
-- Expect-style (correct for firmo)
expect(actual_value).to.equal(expected_value)

-- Assert-style (from busted, NOT for use in firmo)
assert.equals(expected_value, actual_value)  -- DON'T USE THIS
```

### Core Components

1. **The expect function**: `expect(value)` starts an assertion chain
2. **Chainable properties**: `.to`, `.be`, `.a`, etc.
3. **Terminal methods**: `.equal()`, `.exist()`, `.fail()`, etc. that complete the assertion

### Parameter Order

The parameter order in firmo is the opposite of busted:
- In busted: `assert.equals(expected, actual)`
- In firmo: `expect(actual).to.equal(expected)`

The firmo convention follows the pattern: "expect what you have to equal what you want"

### Negating Assertions

For negating assertions, use `to_not` rather than separate functions:
```lua
expect(value).to_not.equal(other_value)
expect(value).to_not.be_truthy()
```

## Complete Assertion Pattern Mapping

| Busted-style                       | firmo style                     | Notes                             |
|------------------------------------|-------------------------------------|-----------------------------------|
| `assert.is_not_nil(value)`         | `expect(value).to.exist()`          | Checks if a value is not nil      |
| `assert.is_nil(value)`             | `expect(value).to_not.exist()`      | Checks if a value is nil          |
| `assert.equals(expected, actual)`  | `expect(actual).to.equal(expected)` | Note the reversed parameter order! |
| `assert.is_true(value)`            | `expect(value).to.be_truthy()`      | Checks if a value is truthy       |
| `assert.is_false(value)`           | `expect(value).to_not.be_truthy()`  | Checks if a value is falsey       |
| `assert.type_of(value, "string")`  | `expect(value).to.be.a("string")`   | Checks the type of a value        |
| `assert.is_string(value)`          | `expect(value).to.be.a("string")`   | Type check                        |
| `assert.is_number(value)`          | `expect(value).to.be.a("number")`   | Type check                        |
| `assert.is_table(value)`           | `expect(value).to.be.a("table")`    | Type check                        |
| `assert.same(expected, actual)`    | `expect(actual).to.equal(expected)` | Deep equality check               |
| `assert.matches(pattern, value)`   | `expect(value).to.match(pattern)`   | String pattern matching           |
| `assert.has_error(fn)`             | `expect(fn).to.fail()`              | Checks if a function throws error |
| `assert.is_function(value)`        | `expect(value).to.be.a("function")` | Function type check               |
| `assert.error_matches(msg, fn)`    | `expect(fn).to.fail(msg)`           | Check error message               |
| `assert.not_equals(a, b)`          | `expect(a).to_not.equal(b)`         | Inequality check                  |
| `assert.has_no_error(fn)`          | `expect(fn).to_not.fail()`          | Check function doesn't error      |

## Common Assertion Mistakes to Avoid

1. **Incorrect negation syntax**:
   ```lua
   -- WRONG:
   expect(value).not_to.equal(other_value)  -- "not_to" is not valid
   
   -- CORRECT:
   expect(value).to_not.equal(other_value)  -- use "to_not" instead
   ```

2. **Incorrect member access syntax**:
   ```lua
   -- WRONG:
   expect(value).to_be(true)  -- "to_be" is not a valid method
   expect(number).to_be_greater_than(5)  -- underscore methods need dot access
   
   -- CORRECT:
   expect(value).to.be(true)  -- use "to.be" not "to_be"
   expect(number).to.be_greater_than(5)  -- this is correct because it's a method
   ```

3. **Inconsistent operator order**:
   ```lua
   -- WRONG:
   expect(expected).to.equal(actual)  -- parameters reversed
   
   -- CORRECT:
   expect(actual).to.equal(expected)  -- what you have, what you expect
   ```

4. **Incorrect assertion type**:
   ```lua
   -- WRONG:
   expect(#table).to.be(0)  -- using .be() for numeric comparison
   
   -- CORRECT:
   expect(#table).to.equal(0)  -- use .equal() for numeric comparison
   ```

5. **Incorrect boolean assertions**:
   ```lua
   -- WRONG:
   expect(value == true).to.be_truthy()  -- redundant comparison
   expect(value).to.equal(true)  -- not recommended for boolean checks
   
   -- CORRECT:
   expect(value).to.be_truthy()  -- direct boolean check
   ```

## Extended Assertions

firmo includes a comprehensive set of extended assertions for more advanced testing needs:

### Collection Assertions

```lua
-- Length/size assertions for strings and tables
expect("hello").to.have_length(5)     -- check string length
expect({1, 2, 3}).to.have_length(3)   -- check array length
expect("world").to.have_size(5)       -- alias for have_length

-- Empty checks
expect("").to.be.empty()              -- check if string is empty
expect({}).to.be.empty()              -- check if table is empty
expect({1, 2}).to_not.be.empty()      -- check table has elements
```

### Numeric Assertions

```lua
-- Numeric property assertions
expect(5).to.be.positive()            -- check if number is positive
expect(-5).to.be.negative()           -- check if number is negative
expect(10).to.be.integer()            -- check if number is an integer
expect(3.14).to_not.be.integer()      -- check number is not an integer
```

### String Assertions

```lua
-- String property checks
expect("HELLO").to.be.uppercase()     -- check if string is all uppercase
expect("hello").to.be.lowercase()     -- check if string is all lowercase
expect("Mixed").to_not.be.uppercase() -- check string is not all uppercase
```

### Object Structure Assertions

```lua
-- Property checking
expect({name = "John"}).to.have_property("name")             -- check property exists
expect({name = "John"}).to.have_property("name", "John")     -- check property value
expect({user = {id = 1}}).to.have_property("user")           -- check nested property

-- Schema validation
expect({name = "John", age = 30}).to.match_schema({
  name = "string",                    -- type checking
  age = "number"                      -- type checking
})

expect({status = "active", count = 5}).to.match_schema({
  status = "active",                  -- exact value matching
  count = "number"                    -- type checking
})
```

### Function Behavior Assertions

```lua
-- Function behavior testing
local obj = {count = 0}

-- Check if function changes a value
expect(function() obj.count = obj.count + 1 end).to.change(function() return obj.count end)

-- Check if function increases a value
expect(function() obj.count = obj.count + 1 end).to.increase(function() return obj.count end)

-- Check if function decreases a value
expect(function() obj.count = obj.count - 1 end).to.decrease(function() return obj.count end)
```

### Deep Equality Assertions

```lua
-- Deep equality checking (alias for equal with clearer intent)
local obj1 = {a = 1, b = {c = 2}}
local obj2 = {a = 1, b = {c = 2}}
expect(obj1).to.deep_equal(obj2)      -- explicit deep comparison
```

## Detailed Assertion Examples

### Basic Assertions

```lua
-- Existence checks
expect(value).to.exist()              -- passes if value is not nil
expect(nil_value).to_not.exist()      -- passes if value is nil

-- Equality checks
expect(5).to.equal(5)                 -- passes for same values
expect({a = 1}).to.equal({a = 1})     -- passes for tables with same contents
expect("hello").to.equal("hello")     -- passes for identical strings

-- Boolean checks
expect(true).to.be_truthy()           -- passes for true
expect(1).to.be_truthy()              -- passes for non-false, non-nil values
expect(false).to_not.be_truthy()      -- passes for false
expect(nil).to_not.be_truthy()        -- passes for nil

-- Type checks
expect(5).to.be.a("number")           -- passes for numbers
expect("hello").to.be.a("string")     -- passes for strings
expect({}).to.be.a("table")           -- passes for tables
expect(function() end).to.be.a("function") -- passes for functions
```

### Table Assertions

```lua
-- Table content checks
local table1 = {a = 1, b = 2, c = 3}
local table2 = {a = 1, b = 2, c = 3}
expect(table1).to.equal(table2)       -- passes for tables with identical contents

-- Table membership checks
local fruit = {"apple", "banana", "orange"}
expect(fruit[1]).to.equal("apple")    -- check specific index
expect(#fruit).to.equal(3)            -- check table length

-- Table key checks
local person = {name = "Alice", age = 30}
expect(person.name).to.equal("Alice") -- check specific property
expect(person.age).to.be.a("number")  -- check property type

-- Nested tables
local nested = {
  user = {
    details = {
      name = "Bob",
      role = "admin"
    }
  }
}
expect(nested.user.details.name).to.equal("Bob")
expect(nested.user.details.role).to.equal("admin")
```

### Function Assertions

```lua
-- Error checking
local function throws_error()
  error("Something went wrong")
end

expect(throws_error).to.fail()        -- passes if function throws any error
expect(throws_error).to.fail("Something went wrong") -- checks error message

-- No error checking
local function no_error()
  return true
end

expect(no_error).to_not.fail()        -- passes if function doesn't throw error

-- Function return value checking
local function get_five()
  return 5
end

expect(get_five()).to.equal(5)        -- check return value
```

### String Assertions

```lua
-- String pattern matching
expect("hello world").to.match("hello")           -- substring match
expect("error code: 123").to.match("%d+")         -- pattern match for digits
expect("test@example.com").to.match("%w+@%w+%.%w+") -- email pattern

-- String length checks
expect(#"hello").to.equal(5)                      -- string length check

-- String case checks
local greeting = "Hello"
expect(greeting:lower()).to.equal("hello")        -- convert to lowercase
expect(greeting:upper()).to.equal("HELLO")        -- convert to uppercase
```

### Advanced Assertion Patterns

#### Complex Boolean Logic

```lua
-- Multiple conditions
local x, y = 5, 10
expect(x < y and x > 0).to.be_truthy()

-- Custom messages using separate assertions
if not (x < y) then
  error("Expected x to be less than y")
end
expect(x > 0).to.be_truthy()
```

#### Checking Multiple Properties

```lua
-- Check multiple properties of a table
local user = {id = 123, name = "Alice", active = true}

expect(user.id).to.be.a("number")
expect(user.name).to.be.a("string")
expect(user.active).to.be_truthy()

-- Check properties existence
expect(user.id).to.exist()
expect(user.name).to.exist()
expect(user.nonexistent).to_not.exist()  -- for properties that shouldn't exist
```

#### Assertions with Mocks and Spies

```lua
local firmo = require "firmo"
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local spy = firmo.spy

describe("Spy assertions", function()
  it("should check if function was called", function()
    local fn = spy(function(x) return x * 2 end)
    
    fn(5)  -- Call the function
    
    expect(fn.calls).to.exist()
    expect(#fn.calls).to.equal(1)          -- function was called once
    expect(fn.calls[1].args[1]).to.equal(5) -- first arg of first call was 5
    expect(fn.calls[1].result).to.equal(10) -- result of first call was 10
  end)
  
  it("should check call count", function()
    local fn = spy(function() end)
    
    fn()
    fn()
    fn()
    
    expect(#fn.calls).to.equal(3)  -- function was called three times
  end)
end)
```

#### Custom Assertion Helpers

```lua
-- Helper for checking objects with specific properties
local function expect_valid_user(user)
  expect(user).to.be.a("table")
  expect(user.id).to.be.a("number")
  expect(user.name).to.be.a("string")
  expect(user.email).to.be.a("string")
  expect(user.email).to.match("%w+@%w+%.%w+")  -- basic email pattern
  return true
end

it("should have valid user objects", function()
  local user1 = {id = 1, name = "Alice", email = "alice@example.com"}
  local user2 = {id = 2, name = "Bob", email = "bob@example.com"}
  
  expect(expect_valid_user(user1)).to.be_truthy()
  expect(expect_valid_user(user2)).to.be_truthy()
end)
```

## Complete Test File Example

Here's a complete example of a well-structured test file:

```lua
-- Import firmo
local firmo = require "firmo"

-- Import test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test lifecycle hooks
local before, after = firmo.before, firmo.after

-- Import module to test
local calculator = require "calculator"

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
  end)
  
  -- Test group for subtraction functionality
  describe("subtraction", function()
    it("should subtract two numbers", function()
      expect(calc:subtract(5, 3)).to.equal(2)
    end)
    
    it("should handle negative results", function()
      expect(calc:subtract(3, 5)).to.equal(-2)
    end)
  end)
  
  -- Test group for division functionality with error handling
  describe("division", function()
    it("should divide two numbers", function()
      expect(calc:divide(6, 3)).to.equal(2)
    end)
    
    it("should throw error when dividing by zero", function()
      local divide_by_zero = function()
        return calc:divide(5, 0)
      end
      
      expect(divide_by_zero).to.fail()
    end)
  end)
end)
```

## Troubleshooting Common Test Issues

### Test Doesn't Run At All

1. **Check imports**: Ensure you've imported test functions correctly:
   ```lua
   local describe, it, expect = firmo.describe, firmo.it, firmo.expect
   ```

2. **No explicit run call**: Ensure you don't have any `firmo.run()` or similar calls in the test file

3. **Command line**: Make sure you're running tests with the correct command:
   ```bash
   lua test.lua tests/your_test_file.lua
   ```

### Assertion Failures

1. **Parameter order**: Remember, `expect(actual).to.equal(expected)` not the other way around

2. **Missing methods**: Use only documented assertion methods, check spelling carefully

3. **Chain syntax**: Make sure you're using `.to.be.a()` not `.to_be_a()`

4. **Comparing tables**: Complex tables might need custom comparison logic; firmo does basic deep comparison

### Setup/Teardown Issues

1. **Proper hooks**: Use `before`/`after`, not `before_all`/`after_all`

2. **Hook scope**: Hooks are scoped to their `describe` block

3. **Variable scope**: Variables defined in before/after hooks are only available within that describe block

## Conclusion

The expect-style assertions in firmo provide a readable, chainable way to express test expectations. By following the patterns in this guide, you'll write consistent, maintainable tests that clearly communicate your code's intended behavior.

Remember these key points:

1. Use `expect(actual).to.equal(expected)` with the correct parameter order
2. Use `to_not` for negation, not `not_to` 
3. Use `.to.be.a("type")` for type checks
4. Use proper local imports and lifecycle hooks
5. Tests are run by the test runner, not by explicit calls in the test file

For more examples, refer to the test files in the `tests/` directory, especially `assertions_test.lua`, `expect_assertions_test.lua`, and `mocking_test.lua`.

## Last Updated

2025-03-20