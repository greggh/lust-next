# Assertion Module Extraction Plan

## Overview

This document outlines the plan for extracting assertion functions into a standalone module. This extraction is critical for resolving circular dependencies and implementing consistent error handling across the entire framework.

## Current State

The current implementation has several issues:

1. **Circular Dependencies**: Assertion functions are tightly coupled with the main firmo module, causing circular dependencies
2. **Inconsistent Error Handling**: Error patterns vary across different assertion methods
3. **Complex Error Propagation**: The assertion chain makes error tracing difficult

## Implementation Plan

### Phase 1: Module Creation and Basic Functions

1. **Create Basic Module Structure**
   - [ ] Create `lib/assertion.lua` with proper documentation
   - [ ] Implement basic expect() function
   - [ ] Set up proper error handling with error_handler

2. **Extract Core Assertion Types**
   - [ ] Extract equality assertions (equal, same)
   - [ ] Extract type assertions (a, type_of)
   - [ ] Extract truthiness assertions (truthy, falsy)
   - [ ] Extract existence assertions (exist, nil)

3. **Set Up Chain Mechanism**
   - [ ] Implement to/to_not chain for all assertions
   - [ ] Set up proper reset() functionality
   - [ ] Ensure proper error context propagation

### Phase 2: Advanced Assertions and Integration

1. **Extract Advanced Assertions**
   - [x] Extract match assertions (match)
   - [x] Extract error assertions (error, fail)
   - [x] Extract comparison assertions (gt, lt, gte, lte)
   - [x] Extract collection assertions (include, empty)

2. **Implement Extended Assertions**
   - [x] Add collection assertions (have_length, have_size, be.empty)
   - [x] Add numeric assertions (be.positive, be.negative, be.integer)
   - [x] Add string assertions (be.uppercase, be.lowercase)
   - [x] Add object structure assertions (have_property, match_schema)
   - [x] Add function behavior assertions (change, increase, decrease)
   - [x] Add alias assertions for clarity (deep_equal)

3. **Implement Error Classification**
   - [x] Add structured error objects for all assertion failures
   - [x] Classify errors by type (equality, type, syntax)
   - [x] Implement detailed context information

4. **Integration with Main Module**
   - [x] Update firmo.lua to use the new module
   - [x] Implement backward compatibility layer
   - [x] Add migration utilities for deprecated patterns

### Phase 3: Testing and Documentation

1. **Comprehensive Test Suite**
   - [x] Create tests for all assertion types
   - [x] Test error propagation and classification
   - [x] Verify backward compatibility
   - [x] Add performance benchmarks

2. **Documentation**
   - [x] Document all exported functions
   - [x] Create migration guide
   - [x] Add examples for all assertion types
   - [x] Document error handling patterns
   - [x] Update assertion pattern mapping with new assertions

## Implementation Details

### Module Interface

```lua
local assertion = require("lib.assertion")

-- Basic expect function
local value = assertion.expect(5)

-- Chain-based assertions
value.to.equal(5)
value.to_not.equal(6)

-- Type assertions
value.to.be.a("number")
value.to.be.integer()

-- Comparison assertions
value.to.be_greater_than(3)
value.to.be.positive()

-- Collection assertions (for strings and arrays)
assertion.expect("hello").to.have_length(5)
assertion.expect({1, 2, 3}).to.have_size(3)
assertion.expect({}).to.be.empty()

-- String assertions
assertion.expect("HELLO").to.be.uppercase()
assertion.expect("hello").to.be.lowercase()

-- Object structure assertions
assertion.expect({name = "John"}).to.have_property("name", "John")
assertion.expect({name = "John", age = 30}).to.match_schema({name = "string", age = "number"})

-- Function behavior assertions
local obj = {count = 0}
assertion.expect(function() obj.count = obj.count + 1 end).to.increase(function() return obj.count end)
```

### Error Handling Integration

```lua
-- Error object structure
{
  message = "Expected 5 to equal 6",
  category = "assertion_error",
  severity = "error",
  context = {
    expected = 6,
    actual = 5,
    assertion_type = "equality",
    source_location = "test.lua:123"
  }
}
```

## Success Criteria

The assertion module extraction will be considered successful when:

1. All assertion functions work correctly with the same API
2. Error handling is consistent across all assertion types
3. Circular dependencies are resolved
4. Tests pass with the new implementation
5. Documentation is complete and accurate
6. Performance is equivalent or better than the original implementation

## Status

As of 2025-03-20, the assertion module extraction and enhancement project has been successfully completed:

1. ✅ The standalone assertion module has been created and integrated
2. ✅ All core and extended assertions have been implemented
3. ✅ Comprehensive tests have been added for all assertions
4. ✅ Documentation has been updated with examples and usage patterns
5. ✅ Error handling has been standardized across all assertions

The extended assertions now available include:
- Collection assertions: have_length, have_size, be.empty
- Numeric assertions: be.positive, be.negative, be.integer
- String assertions: be.uppercase, be.lowercase
- Object structure assertions: have_property, match_schema
- Function behavior assertions: change, increase, decrease
- Alias assertions: deep_equal