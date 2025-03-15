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

```text

### expect(value).to.exist()
Asserts that a value is not nil.
**Example:**

```lua
expect(user).to.exist()
expect(result).to_not.exist() -- Checks that result is nil

```text

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

```text

### expect(value).to.be(expected)
Checks equality using the `==` operator.
**Parameters:**

- `expected` (any): The expected value
**Example:**

```lua
expect(x).to.be(y) -- Same as x == y

```text

### expect(value).to.be.truthy()
Asserts that a value is truthy (not nil and not false).
**Example:**

```lua
expect(1).to.be.truthy()
expect(true).to.be.truthy()
expect("").to.be.truthy() -- Empty string is truthy in Lua
expect(false).to_not.be.truthy()

```text

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

```text

### expect(value).to.have(expected)
Asserts that a table contains the expected value.
**Parameters:**

- `expected` (any): The value to look for in the table
**Example:**

```lua
expect({1, 2, 3}).to.have(2)
expect({name = "Lua", type = "language"}).to.have("Lua")

```text

### expect(fn).to.fail()
Asserts that a function throws an error when called.
**Parameters:**

- `fn` (function): The function to call
**Example:**

```lua
expect(function() error("Something went wrong") end).to.fail()
expect(function() return true end).to_not.fail()

```text

### expect(fn).to.fail.with(pattern)
Asserts that a function throws an error matching the given pattern.
**Parameters:**

- `pattern` (string): Lua pattern to match against the error message
**Example:**

```lua
expect(function() error("Invalid input") end).to.fail.with("Invalid")

```text

### expect(value).to.match(pattern)
Asserts that a string matches the given pattern.
**Parameters:**

- `pattern` (string): Lua pattern to match against the string
**Example:**

```lua
expect("hello world").to.match("hello")
expect("test123").to.match("%a+%d+")

```text

## Table Assertions

### expect(table).to.contain.key(key)
Asserts that a table contains the specified key.
**Parameters:**

- `key` (any): The key to check for
**Example:**

```lua
expect({name = "test", id = 1}).to.contain.key("name")
expect({[1] = "a", [2] = "b"}).to.contain.key(1)

```text

### expect(table).to.contain.keys(keys)
Asserts that a table contains all the specified keys.
**Parameters:**

- `keys` (table): An array of keys to check for
**Example:**

```lua
expect({a = 1, b = 2, c = 3}).to.contain.keys({"a", "b"})

```text

### expect(table).to.contain.value(value)
Asserts that a table contains the specified value.
**Parameters:**

- `value` (any): The value to check for
**Example:**

```lua
expect({1, 2, 3, x = "test"}).to.contain.value(2)
expect({1, 2, 3, x = "test"}).to.contain.value("test")

```text

### expect(table).to.contain.values(values)
Asserts that a table contains all the specified values.
**Parameters:**

- `values` (table): An array of values to check for
**Example:**

```lua
expect({1, 2, 3, x = "test"}).to.contain.values({1, 3})
expect({x = "a", y = "b"}).to.contain.values({"a", "b"})

```text

### expect(table).to.contain.subset(superset)
Asserts that a table is a subset of the given superset.
**Parameters:**

- `superset` (table): The superset to check against
**Example:**

```lua
expect({a = 1}).to.contain.subset({a = 1, b = 2})

```text

### expect(table).to.contain.exactly(keys)
Asserts that a table contains exactly the specified keys, no more and no less.
**Parameters:**

- `keys` (table): An array of keys that should be in the table
**Example:**

```lua
expect({a = 1, b = 2}).to.contain.exactly({"a", "b"})

```text

## String Assertions

### expect(string).to.start_with(prefix)
Asserts that a string starts with the given prefix.
**Parameters:**

- `prefix` (string): The expected prefix
**Example:**

```lua
expect("hello world").to.start_with("hello")

```text

### expect(string).to.end_with(suffix)
Asserts that a string ends with the given suffix.
**Parameters:**

- `suffix` (string): The expected suffix
**Example:**

```lua
expect("hello world").to.end_with("world")

```text

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

```text

## Numeric Assertions

### expect(number).to.be_greater_than(value)
Asserts that a number is greater than the specified value.
**Parameters:**

- `value` (number): The value to compare against
**Example:**

```lua
expect(5).to.be_greater_than(3)

```text

### expect(number).to.be_less_than(value)
Asserts that a number is less than the specified value.
**Parameters:**

- `value` (number): The value to compare against
**Example:**

```lua
expect(3).to.be_less_than(5)

```text

### expect(number).to.be_between(min, max)
Asserts that a number is between the specified minimum and maximum values (inclusive).
**Parameters:**

- `min` (number): The minimum value (inclusive)
- `max` (number): The maximum value (inclusive)
**Example:**

```lua
expect(5).to.be_between(1, 10)
expect(5).to.be_between(5, 10) -- Boundary value check

```text

### expect(number).to.be_approximately(target, delta)
Asserts that a number is approximately equal to the target value within the specified delta.
**Parameters:**

- `target` (number): The target value to compare against
- `delta` (number): The maximum allowed difference (default: 0.0001)
**Example:**

```lua
expect(0.1 + 0.2).to.be_approximately(0.3, 0.0001)

```text

## Error Assertions

### expect(fn).to.throw.error()
Asserts that a function throws an error when called.
**Parameters:**

- `fn` (function): The function to call
**Example:**

```lua
expect(function() error("Something went wrong") end).to.throw.error()

```text

### expect(fn).to.throw.error_matching(pattern)
Asserts that a function throws an error matching the given pattern.
**Parameters:**

- `pattern` (string): Lua pattern to match against the error message
**Example:**

```lua
expect(function() error("Invalid input") end).to.throw.error_matching("Invalid")

```text

### expect(fn).to.throw.error_type(type)
Asserts that a function throws an error of the specified type.
**Parameters:**

- `type` (string): The expected error type ("string", "table", etc.)
**Example:**

```lua
expect(function() error("string error") end).to.throw.error_type("string")
expect(function() error({code = 404}) end).to.throw.error_type("table")

```text

## Negation
All assertions can be negated by using `to_not` instead of `to`.
**Example:**

```lua
expect(1).to_not.equal(2)
expect("hello").to_not.be.a("number")
expect({}).to_not.have(5)

```text

