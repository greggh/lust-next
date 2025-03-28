# Test Fixtures for Coverage Testing

This directory contains Lua modules used for testing the coverage system. These files provide consistent test cases for verifying all aspects of the coverage system.

## Available Fixtures

### simple_module.lua

A basic Lua module with simple functions for testing the core functionality of the coverage system:

- Basic function definitions
- Simple conditionals
- Basic loops
- Simple function calls

### complex_module.lua

A more complex Lua module with advanced features for testing edge cases:

- Multiline definitions
- Complex table constructors
- Nested conditionals
- Anonymous functions
- Closures
- Metatables
- Variable arguments
- Multiple return values

## Using Fixtures in Tests

These fixtures are designed to be used across all coverage test components to ensure consistency. For example:

```lua
-- In a test file
local simple_module = require("tests.coverage.fixtures.simple_module")
local result = simple_module.add(2, 3)
expect(result).to.equal(5)
```

## Test Cases

Each fixture is designed to test specific coverage scenarios:

1. **Line Coverage**: Verify which lines are executed
2. **Assertion Coverage**: Test which lines are verified by assertions
3. **Branch Coverage**: Test coverage of conditional branches
4. **Function Coverage**: Test coverage of function definitions
5. **Edge Cases**: Test coverage of complex Lua constructs

## Adding New Fixtures

When adding new fixtures, please follow these guidelines:

1. Include detailed comments explaining the purpose of each function
2. Cover a variety of Lua language features
3. Include edge cases that might challenge the coverage system
4. Document the fixture in this README

## Test Compatibility

These fixtures are designed to work with both the v2 and v3 coverage systems to support the migration process.