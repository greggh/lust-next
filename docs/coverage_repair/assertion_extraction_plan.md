# Assertion Module Extraction Plan (2025-03-11)

## Overview

During the coverage module repair work, we discovered a circular dependency issue between the main `lust-next.lua` file and `module_reset.lua`. This circular dependency made it difficult to use the assertion functions from `lust-next.lua` in `module_reset.lua`. 

To address this architectural issue, we need to extract all assertions to a separate, standalone module that can be required by both `lust-next.lua` and any other modules that need assertions without creating circular dependencies.

## Current Problem

The current architecture has several issues:

1. **Circular Dependencies**: When `module_reset.lua` tries to use assertion functions from `lust-next.lua`, it creates a circular dependency because `lust-next.lua` also requires `module_reset.lua`.

2. **Inconsistent Assertion Usage**: Due to this circular dependency, we had to create duplicate assertion functions in `module_reset.lua`, which violates our goal of having a single, consistent source of assertions.

3. **Scattered Assertion Implementations**: Currently, assertion functions exist in multiple places (error_handler.lua, lust-next.lua, module_reset.lua), making maintenance difficult.

## Solution: Assertion Module Extraction

We will create a new, standalone assertions module that will serve as the authoritative source for all assertion functions in the codebase.

### Implementation Steps

1. **Create a new assertions.lua module**:
   - Create `lib/core/assertions.lua` as a standalone module
   - Move all assertion functions from `lust-next.lua` to this new module
   - Include basic assertions (equal, is_true, is_false, etc.)
   - Include type assertions (is_exact_type, is_instance_of, is_type_or_nil)
   - Ensure all assertion functions return true on success for chaining

2. **Update lust-next.lua**:
   - Change `lust-next.lua` to require `assertions.lua`
   - Re-export all assertion functions through `lust_next.assert`
   - Maintain backward compatibility with existing code

3. **Update module_reset.lua**:
   - Remove temporary assertion functions from `module_reset.lua`
   - Require `assertions.lua` directly instead of trying to access them through `lust-next.lua`
   - Use assertions from the assertions module for validation

4. **Update error_handler.lua**:
   - Remove all remaining assertion functions from `error_handler.lua`
   - Update documentation to direct users to `assertions.lua` instead

5. **Update documentation**:
   - Update API documentation to reflect the new assertions module
   - Add examples of how to use assertions directly from the assertions module
   - Create a migration guide for any code that was using assertions from other modules

### Benefits

1. **Eliminates Circular Dependencies**: By extracting assertions to their own module, we break the circular dependency chain.

2. **Centralizes Assertion Logic**: All assertion functions will be defined in a single place, making maintenance easier.

3. **Improves Consistency**: Ensures all modules use the same assertion implementations.

4. **Enhances Maintainability**: Makes it easier to add new assertions or modify existing ones.

## Implementation Timeline

1. **Phase 1: Extraction (Priority: HIGH)**
   - Create `assertions.lua` module
   - Move all assertion functions from `lust-next.lua`
   - Ensure backward compatibility
   - Target completion: Immediately after error handler work

2. **Phase 2: Integration (Priority: HIGH)**
   - Update `module_reset.lua` to use assertions directly
   - Update `lust-next.lua` to re-export assertions
   - Verify all tests pass with the new structure
   - Target completion: 1 day after Phase 1

3. **Phase 3: Cleanup (Priority: MEDIUM)**
   - Remove assertion functions from `error_handler.lua`
   - Update documentation
   - Add usage examples
   - Target completion: 1 day after Phase 2

4. **Phase 4: Validation (Priority: HIGH)**
   - Comprehensive testing of assertion functions
   - Run the full test suite to verify no regressions
   - Create specialized tests for assertions module
   - Target completion: 1 day after Phase 3

## Success Criteria

The assertions module extraction will be considered successful when:

1. All assertions are defined in a single `assertions.lua` module
2. No circular dependencies exist in the codebase
3. All modules are using assertions from the assertions module
4. All tests pass with the new structure
5. Documentation is updated to reflect the changes

## Related Work

This work is closely related to the ongoing coverage module repair project, specifically:

1. **Error Handler Implementation**: The assertions extraction should be done after the error handler implementation is complete.
2. **Module Structure Cleanup**: This work aligns with our broader goal of improving the module structure and reducing coupling between modules.

## Conclusion

Extracting assertions to a standalone module will resolve the circular dependency issues we've encountered and improve the overall architecture of the codebase. By centralizing all assertion functions, we'll also improve consistency and maintainability, making it easier to add new assertions or modify existing ones in the future.