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
   - [ ] Extract match assertions (match)
   - [ ] Extract error assertions (error, fail)
   - [ ] Extract comparison assertions (gt, lt, gte, lte)
   - [ ] Extract collection assertions (include, empty)

2. **Implement Error Classification**
   - [ ] Add structured error objects for all assertion failures
   - [ ] Classify errors by type (equality, type, syntax)
   - [ ] Implement detailed context information

3. **Integration with Main Module**
   - [ ] Update firmo.lua to use the new module
   - [ ] Implement backward compatibility layer
   - [ ] Add migration utilities for deprecated patterns

### Phase 3: Testing and Documentation

1. **Comprehensive Test Suite**
   - [ ] Create tests for all assertion types
   - [ ] Test error propagation and classification
   - [ ] Verify backward compatibility
   - [ ] Add performance benchmarks

2. **Documentation**
   - [ ] Document all exported functions
   - [ ] Create migration guide
   - [ ] Add examples for all assertion types
   - [ ] Document error handling patterns

## Implementation Details

### Module Interface

```lua
local assertion = require("lib.assertion")

-- Basic expect function
local value = assertion.expect(5)

-- Chain-based assertions
value.to.equal(5)
value.to_not.equal(6)

-- Advanced assertions
value.to.be.a("number")
value.to.be_greater_than(3)
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