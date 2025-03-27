# Firmo Architecture

## Overview (Updated 2025-03-27)

Firmo is a comprehensive testing framework for Lua projects that provides BDD-style nested test blocks, detailed assertions, setup/teardown hooks, advanced mocking, asynchronous testing, code coverage analysis, and test quality validation.

## Core Architecture

The framework is built with modularity and extensibility in mind, with a clear separation of concerns:

```
firmo.lua                  # Main entry point and public API
|
├── lib/                   # Core framework modules
│   ├── core/              # Fundamental components
│   │   ├── central_config.lua   # Centralized configuration system
│   │   ├── version.lua    # Version information
│   │   └── utils.lua      # Core utilities
│   │
│   ├── assertion/         # Assertion system
│   │   ├── expect.lua     # Expect-style assertions
│   │   └── matchers/      # Individual matcher implementations
│   │
│   ├── coverage/          # Code coverage system
│   │   ├── init.lua       # Coverage API and lifecycle management
│   │   ├── instrumentation/  # Code instrumentation system
│   │   │   ├── init.lua   # Instrumentation setup
│   │   │   ├── transformer.lua # Code transformation
│   │   │   └── sourcemap.lua   # Source mapping
│   │   ├── runtime/       # Runtime coverage tracking
│   │   │   ├── data_store.lua  # Coverage data storage
│   │   │   └── tracker.lua     # Execution tracking
│   │   └── report/        # Report generation
│   │       ├── html.lua   # HTML report formatter
│   │       ├── json.lua   # JSON report formatter
│   │       └── lcov.lua   # LCOV report formatter
│   │
│   ├── tools/             # Utility tools
│   │   ├── logging/       # Structured logging system
│   │   ├── error_handler.lua # Standardized error handling
│   │   ├── filesystem.lua    # Filesystem operations
│   │   ├── benchmark.lua     # Performance benchmarking
│   │   ├── codefix.lua       # Code quality checking and fixing
│   │   ├── watcher.lua       # File watching for live reload
│   │   └── parser.lua        # Lua code parsing
│   │
│   ├── mocking/           # Mocking system
│   │   ├── spy.lua        # Function spying
│   │   ├── stub.lua       # Function stubbing
│   │   └── mock.lua       # Object mocking
│   │
│   ├── quality/           # Test quality validation
│   │   ├── init.lua       # Quality API
│   │   ├── rules/         # Quality rule definitions
│   │   └── report/        # Quality report generators
│   │
│   └── reporting/         # Test reporting
│       ├── init.lua       # Report coordination
│       └── formatters/    # Report formatters
│           ├── html.lua   # HTML test reports
│           ├── json.lua   # JSON test reports
│           └── junit.lua  # JUnit XML reports
│
├── scripts/               # Utilities and runners
│   ├── runner.lua         # Test runner
│   └── tools/             # Development tools
│
└── test.lua               # Main test runner script
```

## Key Components

### 1. Central Configuration System

The central configuration system (`lib/core/central_config.lua`) is the backbone of the framework, providing a unified way to configure all aspects of the system. It:

- Loads configuration from `.firmo-config.lua` files
- Provides sensible defaults for all settings
- Handles configuration merging from multiple sources
- Exposes a consistent API for all modules to access configuration

The central_config module MUST be used by all other modules to retrieve configuration values, ensuring consistency across the framework.

```lua
-- Example of proper configuration usage
local central_config = require("lib.core.central_config")
local config = central_config.get_config()

-- Access configuration values
local track_all = config.coverage.track_all_executed
local include_pattern = config.coverage.include
local exclude_pattern = config.coverage.exclude
```

### 2. Instrumentation-Based Coverage System

The coverage system has been completely redesigned to use code instrumentation rather than debug hooks. This provides:

- More accurate coverage tracking
- Support for complex code patterns
- Better performance
- Detailed execution data
- Three-state coverage model (covered, executed, not covered)

#### 2.1 Key Coverage Components

- **Instrumentation Module** (`lib/coverage/instrumentation/`): Transforms Lua code to insert tracking statements
- **Data Store** (`lib/coverage/runtime/data_store.lua`): Stores and manages coverage data
- **Assertion Integration** (`lib/coverage/assertion/hook.lua`): Connects assertions to code they verify
- **Report Generators** (`lib/coverage/report/`): Generate coverage reports in various formats

#### 2.2 Coverage Data Flow

1. **Instrumentation**: When a module is loaded, its code is transformed to include tracking statements
2. **Execution Tracking**: As the code runs, execution data is stored in the data_store
3. **Coverage Tracking**: When assertions are made, coverage data is recorded
4. **Data Processing**: At the end of the test run, data is processed and normalized
5. **Report Generation**: Coverage reports are generated based on the processed data

### 3. Assertion System

The assertion system provides a fluent, expect-style API for making assertions:

```lua
expect(value).to.exist()
expect(actual).to.equal(expected)
expect(value).to.be.a("string")
expect(value).to.be_truthy()
```

The assertion system is integrated with the coverage system to track which lines are verified by assertions (covered) versus just executed.

### 4. Mocking System

The mocking system provides comprehensive capabilities for isolating tests from dependencies:

- **Spies**: Track function calls without changing behavior
- **Stubs**: Replace functions with test implementations
- **Mocks**: Create mock objects with customized behavior
- **Sequence Mocking**: Define sequences of return values
- **Verification**: Verify call counts, arguments, and order

### 5. Error Handling

All errors in the framework use a standardized error handling pattern:

```lua
-- Error creation
local err = error_handler.validation_error(
  "Invalid parameter",
  {parameter_name = "file_path", operation = "track_file"}
)

-- Error propagation
return nil, err

-- Error handling
local success, result, err = error_handler.try(function()
  return some_operation()
end)

if not success then
  logger.error("Operation failed", {
    error = error_handler.format_error(result)
  })
  return nil, result
end
```

### 6. Quality Validation

The quality module validates that tests meet specified quality criteria:

- Multiple quality levels (from basic to complete)
- Customizable quality rules
- Quality report generation
- Integration with the test runner

### 7. Utility Modules

Several utility modules provide supporting functionality:

- **Filesystem**: Cross-platform file operations
- **Logging**: Structured, level-based logging
- **Watcher**: File monitoring for live reloading
- **Benchmark**: Performance measurement and analysis
- **CodeFix**: Code quality checking and fixing
- **Parser**: Lua code parsing and analysis

## Component Status

### Completed Components

- ✅ Assertion system
- ✅ Mocking system
- ✅ Central configuration system
- ✅ Error handling patterns
- ✅ Filesystem module
- ✅ Structured logging system
- ✅ Test runner

### In-Progress Components

- 🔄 Instrumentation-based coverage system (final stages)
- 🔄 Enhanced HTML report visualization
- 🔄 Quality validation module (partially implemented)
- 🔄 File watcher module (partially implemented)
- 🔄 CodeFix module (partially implemented)
- 🔄 Benchmark module (partially implemented)

### Interaction Between Components

```
                        +----------------+
                        | central_config |<-------+
                        +-------+--------+        |
                                |                 |
            +------------------+-----------------+|
            |                  |                 ||
+-----------v----------+ +-----v------+   +------v+-----+
|  Coverage System     | |  Quality   |   |  Reporting  |
| (instrumentation)    | |  Module    |   |  System     |
+-----------+----------+ +-----+------+   +------+------+
            |                  |                 |
            v                  v                 v
      +-----------+      +-----------+    +-----------+
      | Assertion |<---->|   Test    |<-->|  Mocking  |
      |  System   |      |  Runner   |    |  System   |
      +-----------+      +-----+-----+    +-----------+
                               |
                         +----+-----+
                         | Utilities |
                         +----------+
```

## Key Architectural Principles

1. **No Special Case Code**: All solutions must be general purpose without special handling for specific files or situations
2. **Consistent Error Handling**: All modules use structured error objects with standardized patterns
3. **Central Configuration**: All modules retrieve configuration from the central_config system
4. **Clean Abstractions**: Components interact through well-defined interfaces
5. **Extensive Documentation**: All components have comprehensive API documentation, guides, and examples

## Module Dependencies

- **Core Modules**: central_config, version, utils, error_handler
- **Assertion**: core, error_handler
- **Coverage**: core, central_config, error_handler, filesystem, assertion
- **Mocking**: core, error_handler
- **Quality**: core, central_config, error_handler
- **Reporting**: core, central_config, error_handler, filesystem
- **Utilities**: core, error_handler