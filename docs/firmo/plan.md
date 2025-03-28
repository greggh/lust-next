# V3 Coverage System Implementation Plan

## Overview

The v3 coverage system is a complete rewrite that replaces the debug hook approach with source code instrumentation. This provides more accurate coverage tracking and better performance.

## Important: No Debug Hooks

The v3 system MUST NOT use any debug hooks (debug.sethook, etc). Debug hooks are unreliable and cannot properly distinguish between executed and covered code. All coverage tracking MUST be done through source code instrumentation.

## Implementation Steps

1. ✅ Create Core Components
   - ✅ Create directory structure in lib/coverage/v3
   - ✅ Create test directory structure in tests/coverage/v3
   - ✅ Implement parser using existing LPegLabel parser
   - ✅ Implement transformer to add coverage tracking
   - ✅ Implement sourcemap for error reporting

2. ✅ Implement Module Loading
   - ✅ Create loader hook to intercept require calls
   - ✅ Add module instrumentation on load
   - ✅ Implement caching system for instrumented modules
   - ✅ Add configuration options
   - ✅ Handle circular dependencies

3. ✅ Implement Runtime Tracking
   - ✅ Create execution tracker
   - ✅ Create optimized data store
   - ✅ Implement three-state tracking (covered, executed, not covered)
   - ✅ Add persistence and recovery

4. Implement Assertion Integration
   - Create assertion analyzer
   - Track which lines are verified by assertions
   - Map assertions to covered code

5. Implement Reporting
   - Create HTML reporter with three-state visualization
   - Add JSON reporter for machine consumption
   - Add source code viewer
   - Add coverage statistics

6. Testing and Validation
   - Create comprehensive test suite
   - Add performance benchmarks
   - Test edge cases
   - Validate coverage accuracy

7. Documentation
   - Update API documentation
   - Add migration guide
   - Document configuration options
   - Add examples

## Architecture

The v3 system uses source code instrumentation:

1. When a module is loaded:
   - Parse the source code into an AST
   - Transform the AST to add coverage tracking
   - Generate instrumented code
   - Create source map
   - Cache the instrumented module

2. During execution:
   - Instrumented code calls tracking functions
   - Track which lines are executed
   - Track which lines are covered by assertions
   - Store data efficiently

3. After test run:
   - Process coverage data
   - Generate reports
   - Show three-state coverage

## Current Status

### Completed Components:
- ✅ Core directory structure
- ✅ Parser integration (using existing LPegLabel parser)
- ✅ AST transformer for adding tracking calls
- ✅ Source map implementation
- ✅ Module loader hook
- ✅ Module cache system
- ✅ Runtime tracking system
- ✅ Data store with three-state tracking

### In Progress:
- 🔄 Assertion integration
- 🔄 HTML reporter
- 🔄 Test suite development

### Not Started:
- ❌ JSON reporter
- ❌ Source code viewer
- ❌ Documentation updates
- ❌ Migration guide

## Migration

1. Remove all debug hook code
2. Replace with instrumentation
3. Update tests to use new system
4. Update documentation

## Success Criteria

The implementation is only complete when:
- No debug hooks are used anywhere
- All coverage tracking is done through instrumentation
- Three states are properly distinguished
- Performance is better than v2
- All tests pass
- Edge cases are handled