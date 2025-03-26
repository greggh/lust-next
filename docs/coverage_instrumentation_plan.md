# Comprehensive Plan: Instrumentation-Based Coverage System

## Overview

This document outlines a comprehensive plan to build a robust, instrumentation-based coverage system that properly distinguishes between three states of code:

1. **Covered** (Green): Code that has been executed AND verified by assertions
2. **Executed** (Orange): Code that has been executed but not verified by assertions
3. **Not Covered** (Red): Code that has not been executed at all

The current debug-hook based approach has significant limitations and will be completely replaced with a source code instrumentation approach that guarantees accurate tracking of all executed lines.

## Core Principles

1. **No Special Cases**: The system must work for all Lua files without any special case code for specific files or situations
2. **Automated Tracking**: The system must automatically track execution without manual marking
3. **Assertion Integration**: The system must automatically detect when executed code is verified by assertions
4. **Consistent Data Model**: The system must use a consistent data structure throughout
5. **Central Configuration**: The system must respect the central configuration system

## Architecture Components

### 1. Instrumentation Engine

#### Responsibilities
- Parse Lua source code
- Insert instrumentation statements at the beginning of each logical line
- Preserve original line numbering for error reporting
- Support source maps for accurate error reporting

#### Implementation Details
- Create a token-aware parser to accurately identify logical lines
- Insert `__coverage.track(file_id, line_number)` calls at the beginning of each logical line
- Generate source maps to map instrumented line numbers back to original line numbers
- Preserve comments and whitespace to maintain code readability

#### Key Files
- `lib/coverage/instrumentation/parser.lua`: Lua source code parser
- `lib/coverage/instrumentation/transformer.lua`: Code transformer that injects tracking statements
- `lib/coverage/instrumentation/sourcemap.lua`: Source map generator and handler

### 2. Module Loading Integration

#### Responsibilities
- Hook into Lua's module loading system
- Intercept module requires and instrument code before execution
- Support both file-based and string-based module loading
- Maintain a cache of instrumented modules for performance

#### Implementation Details
- Hook into `package.loaders` to intercept module loading
- Create custom loader that instruments code before execution
- Support loading from files and strings
- Implement caching to avoid re-instrumenting modules

#### Key Files
- `lib/coverage/loader/hook.lua`: Package loader hook
- `lib/coverage/loader/cache.lua`: Instrumented module cache

### 3. Coverage Tracking Runtime

#### Responsibilities
- Track executed lines during program execution
- Associate executed lines with specific modules
- Track assertion verification
- Store coverage data in a consistent format

#### Implementation Details
- Create a global `__coverage` table accessible from instrumented code
- Implement a lightweight tracking function with minimal overhead
- Support tracking of assertion verification
- Store data in a standardized format

#### Key Files
- `lib/coverage/runtime/tracker.lua`: Coverage tracking runtime
- `lib/coverage/runtime/data_store.lua`: Coverage data storage

### 4. Assertion Integration

#### Responsibilities
- Detect when assertions are executed
- Associate assertions with specific lines of code
- Mark verified lines as "covered" rather than just "executed"
- Track assertion metadata (type, message, etc.)

#### Implementation Details
- Hook into firmo's assertion system
- Capture assertion execution context (call stack, etc.)
- Associate assertions with the lines they verify
- Support custom assertion frameworks

#### Key Files
- `lib/coverage/assertion/hook.lua`: Assertion system hook
- `lib/coverage/assertion/analyzer.lua`: Assertion analysis and line association

### 5. Data Model

#### Responsibilities
- Define a consistent data structure for coverage information
- Support the three-state coverage model
- Provide utilities for manipulating coverage data
- Support merging coverage data from multiple runs

#### Implementation Details
- Define clear schemas for coverage data
- Implement utilities for manipulating coverage data
- Support merging coverage data from multiple runs
- Provide a clean API for accessing coverage data

#### Key Files
- `lib/coverage/model/schema.lua`: Data model schema definitions
- `lib/coverage/model/operations.lua`: Data model operations (merge, filter, etc.)

### 6. Reporting System

#### Responsibilities
- Generate human-readable reports from coverage data
- Support multiple output formats (HTML, JSON, LCOV, etc.)
- Visualize the three-state coverage model
- Provide summary statistics

#### Implementation Details
- Implement HTML reporter with three-color visualization
- Support JSON output for integration with other tools
- Support LCOV output for integration with common coverage tools
- Provide summary statistics for quick analysis

#### Key Files
- `lib/coverage/report/html.lua`: HTML report generator
- `lib/coverage/report/json.lua`: JSON report generator
- `lib/coverage/report/lcov.lua`: LCOV report generator
- `lib/coverage/report/summary.lua`: Summary report generator

### 7. Public API

#### Responsibilities
- Provide a clean, simple API for controlling coverage
- Support starting and stopping coverage
- Support generating reports
- Support configuration

#### Implementation Details
- Implement a simple, clean API
- Support configuration via central_config
- Support starting and stopping coverage
- Support generating reports

#### Key Files
- `lib/coverage/init.lua`: Main entry point and API definition
- `lib/coverage/config.lua`: Configuration integration

## Implementation Plan

### Phase 1: Core Instrumentation (3 weeks)

1. **Week 1: Parser and Transformer**
   - Implement Lua source code parser
   - Implement code transformer
   - Create basic instrumentation tests

2. **Week 2: Module Loading**
   - Implement module loader hooks
   - Build instrumented module cache
   - Create loader tests

3. **Week 3: Runtime Tracking**
   - Implement runtime tracking system
   - Build basic data storage
   - Create runtime tests

### Phase 2: Integration and Data Model (2 weeks)

4. **Week 4: Assertion Integration**
   - Implement assertion hooks
   - Build assertion analyzer
   - Create assertion tests

5. **Week 5: Data Model and Storage**
   - Implement data model schema
   - Build data model operations
   - Create data model tests

### Phase 3: Reporting and API (2 weeks)

6. **Week 6: Reporting System**
   - Implement HTML reporter
   - Build JSON reporter
   - Create reporting tests

7. **Week 7: Public API and Integration**
   - Implement public API
   - Build central config integration
   - Create integration tests

### Phase 4: Testing and Documentation (1 week)

8. **Week 8: Testing and Documentation**
   - Conduct comprehensive testing
   - Write usage documentation
   - Create examples

## Technical Challenges and Solutions

### Challenge 1: Accurate Line Tracking

**Problem:** Accurately tracking execution of every logical line in Lua code is challenging due to language features like function calls appearing in the middle of expressions.

**Solution:** Rather than relying on debug hooks, we'll instrument the code directly to insert tracking calls at the beginning of each logical line. This guarantees that every line execution is tracked, regardless of context.

### Challenge 2: Performance Overhead

**Problem:** Instrumenting every line with a function call can introduce significant performance overhead.

**Solution:**
- Use a lightweight tracking function with minimal operations
- Implement a caching system to avoid re-instrumenting modules
- Provide options to exclude certain files or directories from instrumentation
- Support disabling coverage for performance-critical sections

### Challenge 3: Assertion Association

**Problem:** Associating assertions with the specific lines they verify is complex, especially for assertions that test return values from function calls.

**Solution:**
- Implement call stack analysis to trace assertions back to the code they verify
- Support explicit marking of lines verified by assertions in complex cases
- Provide a way to annotate code to help with assertion association
- Implement heuristics to intelligently associate assertions with lines

### Challenge 4: Source Maps

**Problem:** Instrumentation can change line numbers, causing confusion when errors occur.

**Solution:**
- Generate source maps that map instrumented line numbers back to original line numbers
- Intercept error handlers to translate line numbers using source maps
- Preserve original code structure as much as possible to minimize changes to line numbers

## Integration with Existing Codebase

The new coverage system will integrate with the existing Firmo codebase in the following ways:

1. **Test Runner Integration**: The system will integrate with the test runner to automatically enable coverage for tests.
2. **Assertion Integration**: The system will integrate with the assertion module to track which lines are verified.
3. **Configuration Integration**: The system will use central_config for configuration.
4. **Error Handling Integration**: The system will integrate with the error handler to provide source mapped error messages.

## Migration Strategy

1. **Phase Out Debug Hook Approach**: The debug hook approach will be completely removed.
2. **Incremental Adoption**: The instrumentation approach will be incrementally adopted, starting with core modules.
3. **Compatibility Layer**: A compatibility layer will be provided for any code that depends on the old API.
4. **Documentation Updates**: All documentation will be updated to reflect the new approach.

## Conclusion

This comprehensive instrumentation-based approach will provide accurate, reliable coverage information with clear distinction between covered, executed, and not covered code. By directly instrumenting the code rather than relying on debug hooks, we guarantee accurate tracking of all executed lines. By integrating with the assertion system, we can automatically track which lines are verified by assertions, providing a true three-state coverage model.