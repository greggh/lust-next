# Coverage Module Tests

This directory contains tests for the lust-next code coverage system. The coverage module tracks test execution to measure code coverage metrics and provide visualized reports.

## Directory Contents

- **coverage_error_handling_test.lua** - Tests for coverage module error handling
- **coverage_module_test.lua** - Tests for the core coverage module functionality
- **coverage_test_minimal.lua** - Minimal tests for basic coverage capabilities
- **coverage_test_simple.lua** - Simple tests for common coverage scenarios
- **fallback_heuristic_analysis_test.lua** - Tests for fallback analysis methods
- **large_file_coverage_test.lua** - Tests for handling large source files

### Subdirectories

- **hooks/** - Tests for debug hook functionality
- **instrumentation/** - Tests for code instrumentation functionality
  - **instrumentation_module_test.lua** - Tests for the instrumentation module
  - **instrumentation_test.lua** - Tests for instrumentation techniques
  - **single_test.lua** - Standalone test for instrumentation verification

## Coverage System Architecture

The lust-next coverage system consists of multiple components:

- **debug_hook.lua** - Core line tracking functionality using debug hooks
- **file_manager.lua** - File discovery integrated with filesystem module
- **patchup.lua** - Handling non-executable lines and edge cases
- **instrumentation.lua** - Source code transformation approach
- **static_analyzer.lua** - AST-based code analysis

## Coverage Types

The coverage module provides different types of coverage metrics:

- **Line coverage** - Tracks which lines were executed
- **Function coverage** - Tracks which functions were called
- **Block coverage** - Tracks execution of code blocks (if/else, loops)
- **Statement coverage** - Tracks individual statements within lines

## Running Tests

To run all coverage tests:
```
lua test.lua tests/coverage/
```

To run a specific coverage test:
```
lua test.lua tests/coverage/coverage_module_test.lua
```

To run instrumentation tests:
```
lua test.lua tests/coverage/instrumentation/
```

See the [Coverage API Documentation](/docs/api/coverage.md) for more information.