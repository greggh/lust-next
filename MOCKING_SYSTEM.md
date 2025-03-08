# lust-next Mocking System

## Current Status

The mocking system in lust-next has a basic implementation with some features working and others that need to be completed. This document outlines the current state and implementation requirements for the mocking system.

## Existing Functionality

The following features are currently working:

1. **Basic mock functionality**: 
   - Creating mocks for object methods with simple return values
   - Restoring mocked methods

2. **Basic stub functionality**:
   - Creating standalone stubs that return specific values
   - Creating stubs with function implementations

## Implementation Requirements

The following features need to be fully implemented:

### Spy Functionality

1. **Function Call Tracking**:
   - Track when a function is called
   - Maintain a call count
   - Record arguments for each call

2. **Spy Methods**:
   - `called_with()` - Check if a function was called with specific arguments
   - `not_called()` - Check if a function was never called
   - `called_once()` - Check if a function was called exactly once
   - `called_times(n)` - Check if a function was called exactly n times
   - `last_call()` - Get the arguments from the most recent call

3. **Call Sequence Tracking**:
   - `called_before(other_spy)` - Check if one spy was called before another
   - `called_after(other_spy)` - Check if one spy was called after another

### Mock Functionality

1. **Expectation Setting**:
   - Set up expectations for method calls
   - `expect(method)` - Start defining expectations for a method
   - Fluent API for configuring expectations:
     - `.to.be.called.once()`
     - `.to.be.called.times(n)`
     - `.with(...args)`
     - `.and_return(value)`
     - `.after(other_method)`

2. **Call Verification**:
   - `verify_expectations()` - Verify that all expectations have been met
   - `verify_sequence()` - Verify that methods were called in a specific order

3. **Stub Management**:
   - `restore_stub(method)` - Restore a single stubbed method
   - Ensure proper cleanup of all stubs

### Stub Enhancement

1. **Stub Configuration**:
   - `.returns(value)` - Configure a stub to return a specific value
   - `.throws(error)` - Configure a stub to throw an error

### Context Management

1. **with_mocks Enhancement**:
   - Ensure proper cleanup of all mocks even when errors occur
   - Support for complex mock scenarios

## Implementation Plan

1. Start with the spy functionality as it's the foundation of the mocking system
2. Implement stub configuration methods
3. Add mock expectation functionality
4. Enhance the context management system
5. Complete the verification system

Once fully implemented, the mocking system will provide comprehensive functionality for test isolation and behavior verification in lust-next tests.