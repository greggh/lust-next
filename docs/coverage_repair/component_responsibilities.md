# Component Responsibilities

This document outlines the clear responsibilities for each component within the coverage module system, ensuring separation of concerns and well-defined boundaries.

## Purpose

The purpose of this document is to define exactly what each component in the coverage module is responsible for, eliminating ambiguity and preventing responsibility overlap. This helps maintain a modular architecture where each component has a single, well-defined purpose.

## Core Component Responsibilities

### 1. Coverage Module (`init.lua`)

Primary responsibilities:
- Provide the public API for the coverage system
- Initialize and configure the coverage subsystems
- Manage coverage lifecycle (start, stop, reset)
- Coordinate data flow between components
- Select and manage coverage implementation approach (debug hook or instrumentation)
- Track line, block, and function coverage through explicit tracking functions
- Calculate coverage statistics
- Implement robust error handling and propagation
- Validate inputs and function parameters
- Interface with the reporting system
- Distinguish between execution and coverage tracking
- Process coverage data before reporting
- Support seamless switching between implementation approaches
- Provide consistent coverage data regardless of approach used

The coverage module acts as the central coordinator for the entire coverage system, managing the overall coverage lifecycle and providing the main API for external use. It abstracts away the implementation details of different coverage approaches, presenting a unified interface to users while enabling them to choose the most appropriate approach for their needs.

### 2. Debug Hook (`debug_hook.lua`)

Primary responsibilities:
- Set up and manage Lua debug hooks
- Track line executions through Lua's debug API
- Track function calls via the "call" debug hook
- Store execution data in the coverage_data structure
- Filter which files should be tracked
- Differentiate between execution and coverage tracking
- Initialize file data structures for tracking
- Decide if a line should be tracked as executable
- Implement error handling for debug hook operations
- Safely process debug events without crashing
- Handle errors in file path operations
- Validate patterns for file inclusion/exclusion
- Provide track_line, track_function and track_block functions for instrumentation
- Support explicit tracking through public API functions
- Implement robust error handling for all tracking operations
- Maintain consistent coverage data structures

The debug hook is the core execution tracking engine, capturing real-time execution information and maintaining the raw coverage data. It also provides a consistent API for both debug hook and instrumentation approaches, ensuring that coverage data is stored in a standardized format regardless of the tracking method used.

### 3. Static Analyzer (`static_analyzer.lua`)

Primary responsibilities:
- Parse Lua source code into AST using the parser module
- Generate code maps for source files
- Identify executable and non-executable lines
- Track code structure (functions, blocks, branches)
- Provide information about line executability
- Map positions in code to line numbers
- Cache parsed files for performance
- Perform timeout-protected analysis operations
- Detect and classify multiline comments
- Provide a centralized API for multiline comment detection

The static analyzer provides deep insights into the code structure to accurately classify lines and identify coverage boundaries.

### 4. File Manager (`file_manager.lua`)

Primary responsibilities:
- Discover files to include in coverage analysis
- Add uncovered files to the coverage report
- Apply include/exclude patterns to file paths
- Read source files from the filesystem
- Process discovered files
- Implement robust error handling for all file operations
- Validate all function parameters
- Properly propagate errors up the call stack
- Handle filesystem operation errors gracefully
- Provide detailed error context for debugging

The file manager handles all file discovery and management operations, determining which files should be included in coverage analysis.

### 5. Patchup (`patchup.lua`)

Primary responsibilities:
- Fix coverage data for non-executable lines
- Identify comments and structural code lines
- Remove incorrect coverage markings
- Patch files based on static analysis results
- Apply heuristics when static analysis is unavailable
- Use static_analyzer for multiline comment detection
- Handle multiple line_info formats (table, boolean, etc.)
- Implement comprehensive type checking before property access
- Provide detailed logging for debugging coverage issues
- Implement robust error handling for patching operations
- Properly propagate errors up the call stack

The patchup module ensures coverage accuracy by correcting non-executable lines that may have been incorrectly marked as covered. It includes specific handling for different data formats to prevent errors when processing coverage data.

### 6. Instrumentation (`instrumentation.lua`)

Primary responsibilities:
- Transform Lua source code with coverage tracking calls
- Provide both static and runtime instrumentation approaches
- Hook into Lua's loading functions (require, loadfile, dofile, load)
- Insert tracking code for line, block, and function coverage
- Generate sourcemaps for error reporting and debugging
- Cache instrumented files for performance optimization
- Provide configuration options for instrumentation behavior
- Offer different instrumentation strategies based on static analysis
- Filter files that should be instrumented based on predicates
- Handle module loading events through callbacks
- Generate statistics about instrumentation operations

The instrumentation module provides an alternative tracking approach to debug hooks by transforming source code to include explicit coverage tracking statements. This approach offers lower runtime overhead for large codebases and potential improvements in tracking complex code structures like nested functions and branching logic.

## Support Component Responsibilities

### 1. External Modules Integration

#### Filesystem Module (`lib.tools.filesystem`)
- Provides cross-platform file operations with structured error handling
- Performs comprehensive parameter validation for all operations
- Reads, writes, appends, copies, and moves files with robust error handling
- Creates and manages directories with proper parent directory creation
- Normalizes file paths and handles cross-platform differences
- Discovers files based on patterns with flexible inclusion/exclusion
- Returns structured error objects with detailed context information
- Implements proper error chaining to preserve error causality
- Properly manages resources with guaranteed cleanup
- Handles partial success scenarios gracefully (e.g., file copied but source deletion failed)

#### Logging Module (`lib.tools.logging`)
- Provides structured logging capabilities
- Configures log levels per module
- Records debug and error information
- Implements log buffering and rotation
- Supports structured parameter-based logging

#### Error Handler Module (`lib.tools.error_handler`)
- Creates structured error objects with categorization and severity
- Provides stack trace capture and contextual information
- Integrates with the logging system for error reporting
- Offers helpers for assertions and safe operations
- Supports error chaining for tracking root causes
- Acts as a core requirement for all modules in the system
- Provides standardized error handling patterns that must be used consistently
- Ensures proper error propagation throughout the codebase

#### Central Configuration Module (`lib.core.central_config`)
- Provides a global configuration store with hierarchical access
- Validates configuration against schemas
- Notifies components of configuration changes
- Handles loading and saving configuration from/to files
- Manages default values for all modules
- Offers a consistent interface for configuration access

### 2. Parser Module (`lib.tools.parser`)
- Parses Lua code into Abstract Syntax Trees (ASTs)
- Provides grammar definitions for Lua syntax
- Validates parsed code structures

## Component Boundaries

### Debug Hook / Static Analyzer Boundary
- Debug hook focuses on runtime execution tracking
- Static analyzer focuses on static code structure analysis
- They combine data to accurately classify executed lines

### Coverage Module / Reporting Boundary
- Coverage module focuses on collecting and processing coverage data
- Reporting module focuses on formatting and outputting reports
- Coverage module provides processed data to reporting system

### File Manager / Coverage Module Boundary
- File manager focuses on discovering and managing files
- Coverage module integrates this information into the coverage process
- File manager operates independently of coverage tracking

## Responsibility Overlap Areas

The following areas have some responsibility overlap that should be addressed during the repair process:

1. ✓ **Line Classification**: ~~Both debug_hook and static_analyzer classify lines as executable or non-executable.~~ This responsibility has been consolidated to the static_analyzer component. The debug_hook component now delegates line classification to static_analyzer.

2. ✓ **File Data Initialization**: ~~Both coverage init and debug_hook initialize file data structures.~~ This responsibility has been consolidated to the debug_hook component through a new public API (initialize_file). The coverage init module now uses this API instead of duplicating initialization logic.

3. ✓ **Block Tracking**: ~~Both coverage init and debug_hook contain logic for tracking code blocks.~~ This responsibility has been consolidated to the debug_hook component through a new public API (track_blocks_for_line). Both components now use this centralized API for consistent block tracking.

4. ✓ **Multiline Comments**: ~~Both patchup and coverage init include code for handling multiline comments.~~ This responsibility has been consolidated to the static_analyzer component through a comprehensive multiline comment detection API. Both patchup and coverage init now use this centralized API for consistent comment detection.

All identified responsibility overlaps have now been addressed through proper refactoring, creating clear component boundaries and significantly improving code maintainability.