# Firmo Development Roadmap

## Overview

This document outlines the comprehensive development plan for the Firmo testing framework, including both ongoing work and future goals. The plan is organized by priority, with the instrumentation-based coverage system being the highest priority task.

## Part 1: Instrumentation-Based Coverage System (Highest Priority)

### Overview

The current debug-hook based coverage system has significant limitations and will be completely replaced with a source code instrumentation approach that guarantees accurate tracking of all executed lines. The new system will properly distinguish between three states of code:

1. **Covered** (Green): Code that has been executed AND verified by assertions
2. **Executed** (Orange): Code that has been executed but not verified by assertions
3. **Not Covered** (Red): Code that has not been executed at all

### Core Principles

1. **No Special Cases**: The system must work for all Lua files without any special case code
2. **Automated Tracking**: The system must automatically track execution without manual marking
3. **Assertion Integration**: The system must automatically detect when executed code is verified by assertions
4. **Consistent Data Model**: The system must use a consistent data structure throughout
5. **Central Configuration**: The system must respect the central configuration system

### Architecture Components

1. **Instrumentation Engine**: Parse Lua source code and insert tracking statements
2. **Module Loading Integration**: Hook into Lua's module loading system
3. **Coverage Tracking Runtime**: Track executed lines during program execution
4. **Assertion Integration**: Detect when assertions are executed and associate with specific lines
5. **Data Model**: Define a consistent data structure for coverage information
6. **Reporting System**: Generate reports from coverage data

### Implementation Plan

#### Phase 1: Core Instrumentation (6 days)

1. **Days 1-2: Parser and Transformer**
   - Implement Lua source code parser
   - Implement code transformer
   - Create basic instrumentation tests

2. **Days 3-4: Module Loading**
   - Implement module loader hooks
   - Build instrumented module cache
   - Create loader tests

3. **Days 5-6: Runtime Tracking**
   - Implement runtime tracking system
   - Build basic data storage
   - Create runtime tests

#### Phase 2: Integration and Data Model (4 days)

4. **Days 7-8: Assertion Integration**
   - Implement assertion hooks
   - Build assertion analyzer
   - Create assertion tests

5. **Days 9-10: Data Model and Storage**
   - Implement data model schema
   - Build data model operations
   - Create data model tests

#### Phase 3: Reporting and API (3 days)

6. **Days 11-12: Reporting System**
   - Implement HTML reporter
   - Build JSON reporter
   - Create reporting tests

7. **Day 13: Public API and Integration**
   - Implement public API
   - Build central config integration
   - Create integration tests

#### Phase 4: Testing and Documentation (2 days)

8. **Days 14-15: Testing and Documentation**
   - Conduct comprehensive testing
   - Write usage documentation
   - Create examples

### Success Criteria

The implementation is ONLY successful when:
- HTML report shows THREE distinct states with clear visual separation
- ZERO lines are marked "covered" when they are merely "executed"
- No test timeouts or performance issues occur during report generation

## Part 2: Quality Module Completion (Medium Priority)

### Overview

The Quality module validates that tests meet specified quality criteria across five progressive levels. While the API has been defined, the implementation is incomplete.

### Remaining Components

1. **Quality Rules Implementation**:
   - Complete implementation of all quality rules across levels 1-5
   - Build rule validation logic
   - Implement detailed reporting of rule violations

2. **Integration with Test Runner**:
   - Integrate quality validation with test running
   - Implement quality checking for individual test files
   - Add support for quality validation in the CLI

3. **Reporting System**:
   - Complete the HTML report formatter
   - Implement JSON reporting
   - Create summary reporting functionality

4. **Configuration Integration**:
   - Complete integration with central_config
   - Add support for custom rule definitions
   - Implement quality level validation

### Implementation Timeline (5 days)

1. **Day 1-2: Core Rule Implementation**
   - Implement level 1-3 quality rules
   - Create rule validation framework
   - Build rule testing harness

2. **Day 3: Advanced Rules and Runner Integration**
   - Implement level 4-5 quality rules
   - Integrate with test runner
   - Add CLI support

3. **Day 4: Reporting System**
   - Implement HTML reporting
   - Build JSON reporting
   - Create summary reporting

4. **Day 5: Configuration and Documentation**
   - Complete central_config integration
   - Create comprehensive documentation
   - Add examples and usage guides

## Part 3: Watcher Module Completion (Medium Priority)

### Overview

The Watcher module provides file system monitoring capabilities for continuous testing and automatic reloading. While the API has been defined, the implementation is incomplete.

### Remaining Components

1. **Core Watching Functionality**:
   - Complete file change detection
   - Implement efficient timestamp checking
   - Build directory monitoring

2. **Event System**:
   - Implement event dispatching for file changes
   - Add support for event filtering
   - Create debounce functionality

3. **Integration with Test Runner**:
   - Integrate with test runner for continuous testing
   - Add support for selective test re-running
   - Implement watch mode in the CLI

4. **Configuration Integration**:
   - Complete integration with central_config
   - Add support for pattern matching
   - Implement watch options

### Implementation Timeline (5 days)

1. **Days 1-2: Core Watching Implementation**
   - Implement file change detection
   - Build directory monitoring
   - Create efficient timestamp checking

2. **Days 3-4: Event System and Runner Integration**
   - Implement event dispatching
   - Build debounce functionality
   - Integrate with test runner

3. **Day 5: Configuration and Documentation**
   - Complete central_config integration
   - Create comprehensive documentation
   - Add examples and usage guides

## Part 4: Benchmark Module Completion (Medium Priority)

### Overview

The Benchmark module provides comprehensive utilities for measuring and analyzing the performance of Lua code. While the API has been defined, the implementation is incomplete.

### Remaining Components

1. **Core Benchmarking Functionality**:
   - Complete time measurement functions
   - Implement statistical analysis
   - Build memory usage tracking

2. **Comparison and Reporting**:
   - Implement benchmark comparison
   - Build result formatting
   - Create visualization utilities

3. **Integration with Test Framework**:
   - Integrate with test runner
   - Add support for performance testing
   - Implement benchmark suite running

4. **Configuration Integration**:
   - Complete integration with central_config
   - Add support for benchmark options
   - Implement environment detection

### Implementation Timeline (5 days)

1. **Days 1-2: Core Benchmarking Implementation**
   - Implement time measurement functions
   - Build memory usage tracking
   - Create statistical analysis

2. **Days 3-4: Comparison and Reporting**
   - Implement benchmark comparison
   - Build result formatting
   - Create HTML and JSON output

3. **Day 5: Integration and Documentation**
   - Integrate with test runner
   - Complete central_config integration
   - Create comprehensive documentation

## Part 5: CodeFix Module Completion (Medium Priority)

### Overview

The CodeFix module provides code quality checking and fixing capabilities, integrating with external tools like StyLua and Luacheck while also providing custom fixers. While the API has been defined, the implementation is incomplete.

### Remaining Components

1. **Core Fixing Functionality**:
   - Complete integration with StyLua
   - Implement Luacheck integration
   - Build custom fixers

2. **File Operations**:
   - Implement safe file modification
   - Build backup functionality
   - Create change tracking

3. **Integration with Test Framework**:
   - Integrate with pre-test hooks
   - Add support for automatic fixing
   - Implement fix verification

4. **Configuration Integration**:
   - Complete integration with central_config
   - Add support for tool-specific options
   - Implement file inclusion/exclusion patterns

### Implementation Timeline (5 days)

1. **Days 1-2: External Tool Integration**
   - Implement StyLua integration
   - Build Luacheck integration
   - Create tool execution wrappers

2. **Day 3: Custom Fixers**
   - Implement trailing whitespace fixer
   - Build unused variable fixer
   - Create string concatenation optimizer

3. **Day 4: File Operations**
   - Implement safe file modification
   - Build backup functionality
   - Create change tracking

4. **Day 5: Integration and Documentation**
   - Integrate with test framework
   - Complete central_config integration
   - Create comprehensive documentation

## Part 6: HTML Coverage Report Enhancements (Medium Priority)

### Overview

Enhance the HTML coverage report to provide more detailed information and better visualization.

### Planned Improvements

1. **Three-State Visualization**:
   - Distinct colors for covered, executed, and not covered lines
   - Clear legend explaining the three states
   - Line highlighting for better visibility

2. **Execution Count Display**:
   - Show execution count for each line
   - Provide visual indication of heavily executed lines
   - Add execution statistics

3. **File Navigation**:
   - Implement file tree navigation
   - Add search functionality
   - Create directory summary views

4. **Filtering and View Options**:
   - Filter by coverage status
   - Filter by file pattern
   - Toggle display options

### Implementation Timeline (3 days)

1. **Days 1-2: Core Visualization Improvements**
   - Implement three-state visualization
   - Add execution count display
   - Enhance syntax highlighting

2. **Day 3: Navigation and Filtering**
   - Implement file tree navigation
   - Add filtering functionality
   - Create directory summary views

## Part 7: Interactive Module Completion (Medium Priority)

### Overview

The Interactive module provides a text-based user interface (TUI) for running tests, filtering, and debugging interactively. While the API has been defined, the implementation is incomplete.

### Remaining Components

1. **Core Interactive Shell**:
   - Complete command parsing and execution
   - Implement tab completion
   - Build history management

2. **Test Control Functionality**:
   - Implement test filtering by pattern
   - Build test focusing by file or group
   - Create test tagging integration

3. **Watch Mode Integration**:
   - Integrate with file watcher
   - Implement automatic test re-running
   - Add file change notifications

4. **Configuration Integration**:
   - Complete integration with central_config
   - Add support for customization
   - Implement persistent configuration

### Implementation Timeline (5 days)

1. **Days 1-2: Core Shell Implementation**
   - Implement command parsing and execution
   - Build tab completion
   - Create history management

2. **Days 3-4: Test Control and Watch Mode**
   - Implement test filtering
   - Build focusing capabilities
   - Integrate with file watcher

3. **Day 5: Configuration and Documentation**
   - Complete central_config integration
   - Create comprehensive documentation
   - Add examples and usage guides

## Timeline Summary

| Module | Priority | Timeline | Status |
|--------|----------|----------|--------|
| Instrumentation-Based Coverage | Highest | 15 days | In Progress |
| Quality Module | Medium | 5 days | Partially Implemented |
| Watcher Module | Medium | 5 days | Partially Implemented |
| Benchmark Module | Medium | 5 days | Partially Implemented |
| CodeFix Module | Medium | 5 days | Partially Implemented |
| HTML Coverage Report Enhancements | Medium | 3 days | Partially Implemented |
| Interactive Module | Medium | 5 days | Partially Implemented |

## Overall Roadmap

1. **Current Focus (April 2025)**:
   - Complete instrumentation-based coverage system
   - Enhance HTML coverage reporting
   - Complete Quality module

2. **Next Phase (May 2025)**:
   - Complete Watcher module
   - Complete Benchmark module
   - Complete CodeFix module
   - Enhance documentation and examples

3. **Future Work (June 2025)**:
   - Add branch coverage analysis
   - Implement performance profiling
   - CI/CD integration enhancements

## Success Criteria

For each module, success criteria include:

1. **Functionality**: All planned features fully implemented
2. **Integration**: Properly integrated with other modules
3. **Documentation**: Comprehensive API documentation, guides, and examples
4. **Testing**: Full test coverage
5. **Quality**: Adherence to project coding standards and architectural principles

## Conclusion

This comprehensive plan outlines both immediate priorities and short-term goals for the Firmo testing framework. The instrumentation-based coverage system remains the highest priority, but work on other modules will proceed in parallel with one module being completed approximately each week.