# lust-next Mocking System Implementation Plan

## Overview

The mocking system for lust-next has been reimplemented with a more robust and modular design. This document outlines the implementation details and integration plan.

## Current Status

The following components have been successfully implemented and tested:

1. **Spy Module** (`src/spy.lua`):
   - Function call tracking with arguments
   - `called_with()` verification method
   - Call count verification methods (`called_times`, `not_called`, `called_once`)
   - Last call retrieval (`last_call()`)
   - Call sequence tracking (`called_before`, `called_after`)
   - Original functionality restoration

2. **Stub Module** (`src/stub.lua`):
   - Simple value stubs
   - Function implementation stubs
   - Return value configuration (`returns()`)
   - Error throwing configuration (`throws()`)

3. **Mock Module** (`src/mock.lua`):
   - Stubbing object methods
   - Method verification
   - Automatic restoration

4. **Context Management** (`mock.with_mocks`):
   - Error handling
   - Automatic cleanup

## Integration Plan

To integrate the modular mocking system into the main lust-next.lua file, follow these steps:

1. **Replace the existing mocking implementation** in lust-next.lua with the new modular approach:
   - Replace the spy functionality (around line 1460-1640)
   - Replace the stub functionality (around line 2350-2480)
   - Replace the mock functionality (around line 1980-2350)
   - Replace the with_mocks functionality (around line 2480-2500)

2. **Update the test file** (`tests/mocking_test.lua`) to use the new API structure:
   - The tests should now pass without using `pending()`
   - Verify that all features are working as expected

3. **Documentation Update**:
   - Update documentation to reflect the new functionality
   - Add examples for each feature
   - Clarify API differences and compatibility

## Completed Enhancements

The mocking system now includes these advanced features:

1. **Sequential Return Values**:
   - `returns_in_sequence()` method to define values returned in sequence
   - Multiple exhaustion behaviors:
     - Return nil (default)
     - Return custom fallback value 
     - Fall back to original implementation
     - Cycle through the sequence repeatedly
   - Sequence reset functionality via `reset_sequence()`
   - Support for both fixed values and dynamic functions in sequences
   - Example implementation in `examples/mock_sequence_returns_example.lua`

2. **Call Sequence Verification**:
   - Enhanced sequence verification with deterministic ordering
   - `was_called_before()` and `was_called_after()` methods for relative ordering
   - Support for verifying multiple call sequences in complex tests
   - Example implementation in `examples/mock_sequence_example.lua`

## Future Enhancements

Consider these enhancements for future iterations:

1. **Argument Matchers**:
   - Add more sophisticated argument matching capabilities
   - Allow custom matchers to be defined

2. **Expectation API**:
   - Add a fluent API for setting call expectations
   - Implement automatic verification of expectations

## Conclusion

The modular mocking system provides a robust foundation for testing with lust-next. By following this implementation plan, the mocking system will be fully integrated into lust-next while maintaining backward compatibility and adding powerful new features.