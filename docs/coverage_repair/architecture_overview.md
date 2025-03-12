# Coverage Module Architecture Overview

This document provides a comprehensive overview of the coverage module architecture, including component relationships, data flow, and design principles.

## Purpose

The purpose of this document is to establish a clear architectural vision for the coverage module, ensuring all components work together cohesively. It serves as a reference for developers working on the coverage module and helps maintain architectural consistency throughout the implementation.

## High-Level Architecture

The coverage module follows a modular architecture with clear separation of concerns across multiple components. The system is designed to efficiently track code execution, distinguish between executed and covered code, and generate comprehensive reports.

```
+-----------------------+            +------------------------+
|                       |            |                        |
|    Test Runner        |            |   Coverage API         |
|    (run_all_tests)    |<---------->|   (lib/coverage/init)  |
|                       |            |                        |
+-----------------------+            +------------------------+
                                              ^
                                              |
                                              v
+------------------------+           +------------------------+           +------------------------+
|                        |           |                        |           |                        |
|  Debug Hook            |<--------->|  Static Analyzer       |<--------->|  File Manager         |
|  (debug_hook.lua)      |           |  (static_analyzer.lua) |           |  (file_manager.lua)   |
|                        |           |                        |           |                        |
+------------------------+           +------------------------+           +------------------------+
        ^                                      ^                                   ^
        |                                      |                                   |
        v                                      v                                   v
+------------------------+           +------------------------+           +------------------------+
|                        |           |                        |           |                        |
|  Patchup               |<--------->|  Instrumentation       |<--------->|  External Modules     |
|  (patchup.lua)         |           |  (instrumentation.lua) |           |  (filesystem, logging) |
|                        |           |                        |           |                        |
+------------------------+           +------------------------+           +------------------------+
                                              ^
                                              |
                                              v
                                    +------------------------+
                                    |                        |
                                    |  Reporting System      |
                                    |  (lib/reporting)       |
                                    |                        |
                                    +------------------------+
```

## Core Design Principles

1. **Separation of Concerns**: Each component has a clearly defined responsibility, preventing overlap and ensuring maintainability.

2. **Distinction Between Execution and Coverage**: The system distinguishes between lines that were executed (runtime) and lines that were covered by tests (validated), providing a more accurate view of test coverage.

3. **Multiple Implementation Approaches**: The system supports both debug hook (non-intrusive runtime monitoring) and instrumentation (source code transformation) approaches, allowing users to choose the most appropriate approach for their needs.

4. **Extensibility**: The architecture supports multiple report formats and coverage metrics (line, block, function coverage).

5. **Performance Optimization**: The system includes timeouts, caching, and optimized algorithms to handle large codebases efficiently.

6. **Graceful Fallbacks**: When advanced features like static analysis aren't available, the system falls back to simpler heuristics. However, core modules like error_handler must be available and do not have fallbacks.

7. **Accurate Coverage Classification**: The system carefully distinguishes between executable and non-executable lines using static analysis.

8. **Centralized Configuration**: The system utilizes a centralized configuration mechanism for consistent configuration access and validation across all components.

9. **Standardized Error Handling**: The system employs a standardized error handling approach with structured error objects, proper categorization, and integration with the logging system. The error_handler module is considered a core requirement, and all components must use its standardized patterns consistently.

10. **Implementation Flexibility**: The system allows for seamless switching between different implementation approaches, enabling users to balance performance, accuracy, and usability based on project needs.

## Data Flow

1. **Initialization Phase**:
   - Coverage module is initialized with configuration parameters
   - Implementation approach is selected (debug hook or instrumentation)
   - Static analyzer is configured
   - If using debug hook approach:
     - Debug hooks are registered
   - If using instrumentation approach:
     - Instrumentation module is configured
     - Lua loaders are hooked if runtime instrumentation is enabled

2. **Execution Phase**:
   - If using debug hook approach:
     - Debug hook captures line executions and function calls
     - Execution data is stored in the coverage_data structure
   - If using instrumentation approach:
     - Source code is transformed with tracking calls
     - Explicit tracking calls record execution data
     - Sourcemaps maintain the relationship between original and instrumented code
   - File sources are loaded and parsed for analysis

3. **Analysis Phase**:
   - Static analyzer processes source code to identify executable lines
   - Patchup module fixes non-executable lines
   - Block and function coverage is calculated
   - For instrumentation approach:
     - Sourcemaps are used to map instrumented line numbers back to original line numbers

4. **Reporting Phase**:
   - Coverage data is processed for statistics
   - Reports are generated in various formats
   - Data from both approaches is presented consistently

## Key System States

1. **Inactive**: Coverage module is loaded but not tracking
2. **Active**: Coverage is actively tracking code execution
3. **Stopped**: Coverage has finished tracking and is ready for reporting

## Integration Points

1. **Test Runner Integration**: The coverage module integrates with the test runner to start/stop tracking and generate reports.

2. **Reporting System Integration**: The coverage module provides data to the reporting system for formatting and output.

3. **External Tools Integration**: Reports are generated in standard formats (HTML, LCOV, Cobertura, JSON) for integration with external tools.

## Technical Challenges Addressed

1. **Multiline Comment Handling**: The system uses a sophisticated approach to accurately identify and handle multiline comments.

2. **Code Structure Recognition**: The static analyzer identifies blocks, functions, and control flow to provide accurate coverage metrics.

3. **Large File Support**: The system includes optimizations to handle large files efficiently, with proper timeout protection.

4. **Accurate Line Classification**: The system carefully determines which lines are executable to avoid falsely reporting coverage.

5. **Comprehensive Error Handling**: The system implements structured error handling with categorization, severity levels, and proper propagation throughout all components.

6. **Robust Input Validation**: All functions validate their inputs with detailed error messages and contextual information for debugging.

## Current Architecture Strengths

1. **Modular Design**: Clear component separation with well-defined interfaces.
2. **Dual Implementation Approaches**: Supports both debug hook (runtime monitoring) and instrumentation (source code transformation) approaches, providing flexibility for different use cases.
3. **Hybrid Approach**: Combines runtime tracking with static analysis for accuracy.
4. **Detailed Metrics**: Supports line, function, and block coverage for comprehensive testing metrics.
5. **Robust Error Handling**: Structured error system with categorization, severity levels, proper propagation, and integration with logging.
6. **Defensive Programming**: Comprehensive input validation and safe operation patterns throughout the codebase.
7. **Centralized Configuration**: Utilizes a global configuration store with standardized access patterns and validation.
8. **Standardized Systems**: Core systems (error handling, logging, configuration) follow consistent patterns across the codebase.
9. **Sourcemap Support**: Provides sourcemap capability for mapping between instrumented and original code, enabling better error reporting and debugging.

## Current Architecture Weaknesses

1. **Complex Debug Hook Logic**: The debug hook module contains complex conditional logic that's difficult to maintain.
2. **Redundant Code Paths**: Some code paths are duplicated across modules.
3. **Tight Coupling**: Some components have tight coupling that complicates isolated testing.
4. **Indirect Data Access**: Some components access data through multiple layers of indirection.
5. **Incomplete Integration**: The centralized configuration and error handling systems need to be integrated across all modules.

## Planned Architectural Improvements

These weaknesses will be addressed through the repair plan, which includes:
1. Refactoring the debug hook to simplify its logic
2. Consolidating redundant code paths
3. Reducing coupling through better-defined interfaces
4. Creating more direct data access paths
5. Project-wide integration of the centralized configuration system 
6. Project-wide integration of the standardized error handling system

## Component Isolation Progress

Component isolation has been completed by addressing all identified responsibility overlaps:

1. **Clarified Line Classification Responsibility**: The static_analyzer component is now the definitive source for line classification, including executable line determination. This has eliminated duplicate logic and potential inconsistencies.

2. **Improved File Data Initialization**: The debug_hook component now serves as the single source of truth for file data initialization through a standardized API. Other components use this API rather than implementing their own initialization logic.

3. **Centralized Block Tracking**: The debug_hook component now provides a unified implementation for block tracking through a public API, ensuring consistent block tracking behavior throughout the system.

4. **Centralized Multiline Comment Detection**: The static_analyzer component now provides a comprehensive API for multiline comment detection. Both patchup.lua and init.lua use this centralized API, ensuring consistent classification of comment lines throughout the coverage system.

5. **Reduced Direct Data Access**: Components now access shared data structures through well-defined interfaces rather than direct manipulation, improving maintainability and reducing tight coupling.

6. **Enhanced Instrumentation Architecture** (2025-03-12): The instrumentation module has been significantly enhanced with:
   - Robust cycle detection for require() instrumentation to prevent recursion
   - Multiple tracking tables to manage module loading state (currently_instrumenting, instrumented_modules)
   - Recursion depth monitoring with a maximum depth limit
   - Improved module exclusion with pattern-based matching
   - Error handling with state cleanup for all operations
   - Isolated code execution with protected calls
   - Module boundary awareness to prevent self-instrumentation
   
   While our current implementation includes significant improvements, we've also created a comprehensive plan for a complete architectural solution in instrumentation_module_require_fix_plan.md that would provide stronger isolation and boundary protection.

These improvements have successfully addressed all responsibility overlaps identified during the code audit, creating a cleaner architecture with clear component boundaries and well-defined responsibilities.

## Framework-level Architectural Improvements

In addition to component-specific improvements, several framework-level architectural enhancements have been implemented:

1. **Centralized Configuration System** (2025-03-11): Created a global configuration system in `lib/core/central_config.lua` that provides:
   - Hierarchical configuration access with dot notation paths
   - Schema validation for module configurations
   - Change notification system for configuration changes
   - Default value management with module registration
   - File I/O operations for loading and saving configuration
   - Integration with other framework systems
   
   This system will replace the previous approach of passing configuration separately to each component, ensuring consistent configuration access, validation, and notification across the entire lust-next framework.

2. **Standardized Error Handling System** (2025-03-11): Implemented a comprehensive error handling system in `lib/tools/error_handler.lua` that provides:
   - Structured error objects with categorization and severity levels
   - Stack trace capture and error chaining
   - Integration with the logging system
   - Helper functions for common error handling patterns
   - Consistent interfaces for creating and handling errors
   
   This system replaces direct error() calls throughout the codebase with structured error handling that provides better context and diagnostics.
   
   As of 2025-03-11, a significant architectural decision was made to enforce the error_handler as a **required dependency** rather than an optional one. This means:
   - The error_handler module is now a direct requirement with no conditional loading
   - All fallback code that handled cases without error_handler has been removed
   - Error handling patterns are consistently applied throughout the codebase
   - All components assume the error_handler module will always be available
   
   This decision simplifies the code, makes error handling more consistent, and improves maintainability by eliminating redundant fallback code paths.

3. **Planned Assertion Module Extraction** (2025-03-11): During work on the coverage module repair, we discovered circular dependency issues between lust-next.lua and module_reset.lua. To address this architectural issue, we've created a comprehensive plan to extract all assertion functions to a standalone module:
   - Create lib/core/assertions.lua as the central repository for all assertion functions
   - Move existing assertion functions from lust-next.lua to the new module
   - Ensure assertions can be used by any module without circular dependencies
   - Remove any duplicate assertion functions from other modules
   
   This will improve the overall architecture by eliminating circular dependencies, centralizing assertion logic, and ensuring consistent assertion behavior throughout the framework.

4. **Enhanced Filesystem Error Handling** (2025-03-11): To improve robustness and error diagnostics, we've implemented structured error handling in the filesystem module:
   - Added direct error_handler dependency to ensure it's always available
   - Implemented standardized validation patterns for all parameters
   - Created structured error objects with proper categorization (IO, VALIDATION)
   - Added comprehensive error context with operation-specific information
   - Implemented error chaining to preserve original causes
   - Used try/catch patterns for all risky operations
   - Enhanced resource cleanup with proper error propagation
   - Added special handling for partial success scenarios (e.g., file copied but deletion failed)
   
   These improvements significantly enhance the robustness and maintainability of the filesystem module, a critical component used throughout the framework.

These framework-level architectural improvements lay the foundation for more reliable, maintainable, and consistent code across the entire lust-next project.