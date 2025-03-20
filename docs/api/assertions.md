# Assertions API
This document describes the assertion functions provided by Firmo for verifying test conditions.

## Basic Assertions

### expect(value)
The foundation of Firmo's assertion system. Creates an assertion object for the given value.
**Parameters:**

- `value` (any): The value to make assertions about
**Returns:**

- An assertion object with chainable methods
**Example:**

```lua
expect(1 + 1).to.equal(2)
expect("hello").to.be.a("string")

```

### expect(value).to.exist()
Asserts that a value is not nil.
**Example:**

```lua
expect(user).to.exist()
expect(result).to_not.exist() -- Checks that result is nil

```

### expect(value).to.equal(expected, [epsilon])
Performs a deep comparison between the value and expected, ensuring they are equal.
**Parameters:**

- `expected` (any): The expected value
- `epsilon` (number, optional): For floating point comparisons, maximum allowable difference
**Example:**

```lua
expect(1 + 1).to.equal(2)
expect({a = 1, b = 2}).to.equal({a = 1, b = 2})
expect(0.1 + 0.2).to.equal(0.3, 0.0001) -- With epsilon for floating point

```

### expect(value).to.be(expected)
Checks equality using the `==` operator.
**Parameters:**

- `expected` (any): The expected value
**Example:**

```lua
expect(x).to.be(y) -- Same as x == y

```

### expect(value).to.be.truthy()
Asserts that a value is truthy (not nil and not false).
**Example:**

```lua
expect(1).to.be.truthy()
expect(true).to.be.truthy()
expect("").to.be.truthy() -- Empty string is truthy in Lua
expect(false).to_not.be.truthy()

```

### expect(value).to.be.a(type)
Asserts that a value is of the specified type.
**Parameters:**

- `type` (string|table): Type name as string or metatable for inheritance checks
**Example:**

```lua
expect(123).to.be.a("number")
expect("hello").to.be.a("string")
expect({}).to.be.a("table")
expect(MyClass:new()).to.be.a(MyClass) -- Metatable inheritance check

```

### expect(value).to.have(expected)
Asserts that a table contains the expected value.
**Parameters:**

- `expected` (any): The value to look for in the table
**Example:**

```lua
expect({1, 2, 3}).to.have(2)
expect({name = "Lua", type = "language"}).to.have("Lua")

```

### expect(fn).to.fail()
Asserts that a function throws an error when called.
**Parameters:**

- `fn` (function): The function to call
**Example:**

```lua
expect(function() error("Something went wrong") end).to.fail()
expect(function() return true end).to_not.fail()

```

### expect(fn).to.fail.with(pattern)
Asserts that a function throws an error matching the given pattern.
**Parameters:**

- `pattern` (string): Lua pattern to match against the error message
**Example:**

```lua
expect(function() error("Invalid input") end).to.fail.with("Invalid")

```

### expect(value).to.match(pattern)
Asserts that a string matches the given pattern.
**Parameters:**

- `pattern` (string): Lua pattern to match against the string
**Example:**

```lua
expect("hello world").to.match("hello")
expect("test123").to.match("%a+%d+")

```

## Table and Collection Assertions

### expect(table).to.contain.key(key)
Asserts that a table contains the specified key.
**Parameters:**

- `key` (any): The key to check for
**Example:**

```lua
expect({name = "test", id = 1}).to.contain.key("name")
expect({[1] = "a", [2] = "b"}).to.contain.key(1)

```

### expect(table).to.contain.keys(keys)
Asserts that a table contains all the specified keys.
**Parameters:**

- `keys` (table): An array of keys to check for
**Example:**

```lua
expect({a = 1, b = 2, c = 3}).to.contain.keys({"a", "b"})

```

### expect(table).to.contain.value(value)
Asserts that a table contains the specified value.
**Parameters:**

- `value` (any): The value to check for
**Example:**

```lua
expect({1, 2, 3, x = "test"}).to.contain.value(2)
expect({1, 2, 3, x = "test"}).to.contain.value("test")

```

### expect(table).to.contain.values(values)
Asserts that a table contains all the specified values.
**Parameters:**

- `values` (table): An array of values to check for
**Example:**

```lua
expect({1, 2, 3, x = "test"}).to.contain.values({1, 3})
expect({x = "a", y = "b"}).to.contain.values({"a", "b"})

```

### expect(table).to.contain.subset(superset)
Asserts that a table is a subset of the given superset.
**Parameters:**

- `superset` (table): The superset to check against
**Example:**

```lua
expect({a = 1}).to.contain.subset({a = 1, b = 2})

```

### expect(table).to.contain.exactly(keys)
Asserts that a table contains exactly the specified keys, no more and no less.
**Parameters:**

- `keys` (table): An array of keys that should be in the table
**Example:**

```lua
expect({a = 1, b = 2}).to.contain.exactly({"a", "b"})

```

### expect(value).to.have_length(length)
Asserts that a string or table has a specific length.
**Parameters:**

- `length` (number): The expected length
**Example:**

```lua
expect("hello").to.have_length(5) -- String length
expect({1, 2, 3}).to.have_length(3) -- Array length
expect({}).to.have_length(0) -- Empty collection

```

### expect(value).to.have_size(size)
Alias for have_length. Asserts that a string or table has a specific size.
**Parameters:**

- `size` (number): The expected size
**Example:**

```lua
expect("world").to.have_size(5) -- String size
expect({1, 2, 3, 4}).to.have_size(4) -- Array size

```

### expect(value).to.be.empty()
Asserts that a string or table is empty.
**Example:**

```lua
expect("").to.be.empty() -- Empty string
expect({}).to.be.empty() -- Empty table
expect({1, 2, 3}).to_not.be.empty() -- Non-empty array
expect({a = 1}).to_not.be.empty() -- Non-empty object

```

### expect(table).to.have_property(property_name[, expected_value])
Asserts that an object has a specific property, optionally with a specific value.
**Parameters:**

- `property_name` (string): The name of the property to check for
- `expected_value` (any, optional): The expected value of the property
**Example:**

```lua
local obj = {name = "John", age = 30}
expect(obj).to.have_property("name") -- Just check property exists
expect(obj).to.have_property("age", 30) -- Check property has specific value
expect(obj).to_not.have_property("address") -- Check property doesn't exist

```

### expect(table).to.match_schema(schema)
Asserts that an object matches a specified schema of property types or values.
**Parameters:**

- `schema` (table): A table specifying property types or exact values
**Example:**

```lua
local user = {
  name = "John",
  age = 30,
  is_active = true,
  roles = {"admin", "user"}
}

-- Type checking schema
expect(user).to.match_schema({
  name = "string",
  age = "number",
  is_active = "boolean",
  roles = "table"
})

-- Value checking schema
expect(user).to.match_schema({
  name = "John",
  is_active = true
})

-- Mixed schema (type and value checks)
expect(user).to.match_schema({
  name = "string", -- Type check
  age = 30,        -- Exact value check
  is_active = true -- Exact value check
})

```

## String Assertions

### expect(string).to.start_with(prefix)
Asserts that a string starts with the given prefix.
**Parameters:**

- `prefix` (string): The expected prefix
**Example:**

```lua
expect("hello world").to.start_with("hello")

```

### expect(string).to.end_with(suffix)
Asserts that a string ends with the given suffix.
**Parameters:**

- `suffix` (string): The expected suffix
**Example:**

```lua
expect("hello world").to.end_with("world")

```

### expect(string).to.be.uppercase()
Asserts that a string contains only uppercase characters.
**Example:**

```lua
expect("HELLO").to.be.uppercase()
expect("Hello").to_not.be.uppercase()
expect("").to.be.uppercase() -- Empty string is considered uppercase

```

### expect(string).to.be.lowercase()
Asserts that a string contains only lowercase characters.
**Example:**

```lua
expect("hello").to.be.lowercase()
expect("Hello").to_not.be.lowercase()
expect("").to.be.lowercase() -- Empty string is considered lowercase

```

## Type Assertions

### expect(value).to.be_type(expected_type)
Asserts that a value is of a specific advanced type.
**Parameters:**

- `expected_type` (string): The expected type, which can be one of:
  - `"callable"`: Functions or tables with __call metamethod
  - `"comparable"`: Values that can be compared with the < operator
  - `"iterable"`: Values that can be iterated with pairs()
**Example:**

```lua
expect(function() end).to.be_type("callable")
expect(5).to.be_type("comparable")
expect({}).to.be_type("iterable")

```

## Numeric Assertions

### expect(number).to.be_greater_than(value)
Asserts that a number is greater than the specified value.
**Parameters:**

- `value` (number): The value to compare against
**Example:**

```lua
expect(5).to.be_greater_than(3)

```

### expect(number).to.be_less_than(value)
Asserts that a number is less than the specified value.
**Parameters:**

- `value` (number): The value to compare against
**Example:**

```lua
expect(3).to.be_less_than(5)

```

### expect(number).to.be_between(min, max)
Asserts that a number is between the specified minimum and maximum values (inclusive).
**Parameters:**

- `min` (number): The minimum value (inclusive)
- `max` (number): The maximum value (inclusive)
**Example:**

```lua
expect(5).to.be_between(1, 10)
expect(5).to.be_between(5, 10) -- Boundary value check

```

### expect(number).to.be_approximately(target, delta)
Asserts that a number is approximately equal to the target value within the specified delta.
**Parameters:**

- `target` (number): The target value to compare against
- `delta` (number): The maximum allowed difference (default: 0.0001)
**Example:**

```lua
expect(0.1 + 0.2).to.be_approximately(0.3, 0.0001)

```

### expect(number).to.be.positive()
Asserts that a number is greater than zero.
**Example:**

```lua
expect(5).to.be.positive()
expect(0.1).to.be.positive()
expect(0).to_not.be.positive() -- Zero is not positive
expect(-5).to_not.be.positive()

```

### expect(number).to.be.negative()
Asserts that a number is less than zero.
**Example:**

```lua
expect(-5).to.be.negative()
expect(-0.1).to.be.negative()
expect(0).to_not.be.negative() -- Zero is not negative
expect(5).to_not.be.negative()

```

### expect(number).to.be.integer()
Asserts that a number is an integer (whole number with no decimal part).
**Example:**

```lua
expect(5).to.be.integer()
expect(-10).to.be.integer()
expect(0).to.be.integer()
expect(5.5).to_not.be.integer()
expect(-0.1).to_not.be.integer()

```

## Error Assertions

### expect(fn).to.throw.error()
Asserts that a function throws an error when called.
**Parameters:**

- `fn` (function): The function to call
**Example:**

```lua
expect(function() error("Something went wrong") end).to.throw.error()

```

### expect(fn).to.throw.error_matching(pattern)
Asserts that a function throws an error matching the given pattern.
**Parameters:**

- `pattern` (string): Lua pattern to match against the error message
**Example:**

```lua
expect(function() error("Invalid input") end).to.throw.error_matching("Invalid")

```

### expect(fn).to.throw.error_type(type)
Asserts that a function throws an error of the specified type.
**Parameters:**

- `type` (string): The expected error type ("string", "table", etc.)
**Example:**

```lua
expect(function() error("string error") end).to.throw.error_type("string")
expect(function() error({code = 404}) end).to.throw.error_type("table")

```

## Function Behavior Assertions

### expect(fn).to.change(value_fn[, change_fn])
Asserts that executing a function changes the value returned by the value function.
**Parameters:**

- `fn` (function): The function to execute
- `value_fn` (function): A function that returns the value to check
- `change_fn` (function, optional): A function to validate the nature of the change
**Example:**

```lua
local obj = {count = 0}

-- Check if a function changes a value
expect(function() obj.count = obj.count + 1 end).to.change(function() return obj.count end)

-- With custom change validator
expect(function() obj.count = obj.count + 5 end).to.change(
  function() return obj.count end,
  function(before, after) return after - before == 5 end
)

```

### expect(fn).to.increase(value_fn)
Asserts that executing a function increases the numeric value returned by the value function.
**Parameters:**

- `fn` (function): The function to execute
- `value_fn` (function): A function that returns the numeric value to check
**Example:**

```lua
local counter = {value = 10}

-- Check if a function increases a value
expect(function() counter.value = counter.value + 1 end).to.increase(function() return counter.value end)

-- Checks for any increase, not a specific amount
expect(function() counter.value = counter.value * 2 end).to.increase(function() return counter.value end)

```

### expect(fn).to.decrease(value_fn)
Asserts that executing a function decreases the numeric value returned by the value function.
**Parameters:**

- `fn` (function): The function to execute
- `value_fn` (function): A function that returns the numeric value to check
**Example:**

```lua
local counter = {value = 10}

-- Check if a function decreases a value
expect(function() counter.value = counter.value - 1 end).to.decrease(function() return counter.value end)

-- Checks for any decrease, not a specific amount
expect(function() counter.value = counter.value / 2 end).to.decrease(function() return counter.value end)

```

### expect(value).to.deep_equal(expected)
Alias for equal that explicitly indicates deep equality comparison.
**Parameters:**

- `expected` (any): The expected value to compare against
**Example:**

```lua
local obj1 = {a = 1, b = {c = 2}}
local obj2 = {a = 1, b = {c = 2}}
local obj3 = {a = 1, b = {c = 3}}

expect(obj1).to.deep_equal(obj2) -- Objects with identical deep structure
expect(obj1).to_not.deep_equal(obj3) -- Objects with different nested values

```

## Negation
All assertions can be negated by using `to_not` instead of `to`.
**Example:**

```lua
expect(1).to_not.equal(2)
expect("hello").to_not.be.a("number")
expect({}).to_not.have(5)

```

