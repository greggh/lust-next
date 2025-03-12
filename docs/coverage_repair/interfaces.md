# Component Interfaces

This document defines the interfaces between different components in the coverage module system, specifying how they interact and share data.

## Purpose

The purpose of this document is to establish clear, well-defined interfaces between components in the coverage module, ensuring proper data handoff and interaction patterns. Well-defined interfaces allow components to evolve independently while maintaining system integrity.

## Core Data Structures

### 1. Coverage Data Structure

The primary data structure shared between components is the `coverage_data` structure:

```lua
coverage_data = {
  files = {}, -- Files indexed by normalized path
  lines = {}, -- Global lines indexed by file:line
  functions = {}, -- Global functions indexed by file:function
  blocks = {}, -- Global blocks indexed by file:block_id
  conditions = {} -- Global conditions indexed by file:condition_id
}
```

For each file, the structure contains:

```lua
files[file_path] = {
  lines = {}, -- Lines that are covered (validated by tests)
  _executed_lines = {}, -- Lines that were executed (not necessarily validated)
  functions = {}, -- Function execution tracking
  line_count = number, -- Total lines in file
  source = table, -- Source code lines
  source_text = string, -- Full source code
  executable_lines = {}, -- Whether each line is executable
  logical_chunks = {}, -- Block coverage information
  logical_conditions = {}, -- Condition coverage information
  code_map = table, -- Static analysis data
  ast = table, -- Abstract Syntax Tree
  discovered = boolean, -- Whether this file was discovered or executed
  needs_static_analysis = boolean -- Whether this file needs static analysis
}
```

### 2. Configuration System

The configuration system has been upgraded from a simple shared structure to a comprehensive centralized configuration system implemented in `lib/core/central_config.lua`. This system provides:

- Hierarchical configuration access with dot notation paths
- Schema validation for module configurations
- Change notification system for configuration changes
- Default value management with module registration
- File I/O operations for loading and saving configuration
- Integration with error handling and logging systems

The existing configuration module (`lib/core/config.lua`) has been updated to act as a bridge to the centralized configuration system while maintaining backward compatibility with existing code. It:

- Uses central_config when available
- Falls back to legacy methods when central_config is not available
- Maintains backward compatibility with existing code
- Preserves the same API for external users
- Registers core modules with central_config
- Sets up change listeners for reactive configuration changes

#### Coverage Module Configuration Schema:

```lua
central_config.register_module("coverage", {
  field_types = {
    enabled = "boolean",
    source_dirs = "table",
    include = "table",
    exclude = "table",
    discover_uncovered = "boolean",
    threshold = "number",
    debug = "boolean",
    track_self_coverage = "boolean",
    should_track_example_files = "boolean",
    verbose = "boolean",
    
    -- Static analysis options
    use_static_analysis = "boolean",
    branch_coverage = "boolean",
    cache_parsed_files = "boolean",
    track_blocks = "boolean",
    pre_analyze_files = "boolean",
    control_flow_keywords_executable = "boolean",
    
    -- Instrumentation options
    use_instrumentation = "boolean",
    instrument_on_load = "boolean", 
    cache_instrumented_files = "boolean",
    sourcemap_enabled = "boolean",
    max_file_size = "number",
    include_coverage_module = "boolean"
  },
  field_ranges = {
    threshold = {min = 0, max = 100},
    max_file_size = {min = 1000, max = 10000000}
  }
}, {
  -- Default values
  enabled = true,
  source_dirs = {"lib", "src"},
  include = {"**.lua"},
  exclude = {"**/test/**", "**/spec/**"},
  discover_uncovered = true,
  threshold = 80,
  debug = false,
  track_self_coverage = false,
  should_track_example_files = false,
  verbose = false,
  
  -- Static analysis defaults
  use_static_analysis = true,
  branch_coverage = true,
  cache_parsed_files = true,
  track_blocks = true,
  pre_analyze_files = false,
  control_flow_keywords_executable = true,
  
  -- Instrumentation defaults
  use_instrumentation = false,
  instrument_on_load = false,
  cache_instrumented_files = true,
  sourcemap_enabled = true,
  max_file_size = 500000,
  include_coverage_module = false
})
```

#### Quality Module Configuration Schema:

```lua
central_config.register_module("quality", {
  field_types = {
    enabled = "boolean",
    level = "number",
    threshold = "number",
    debug = "boolean",
    verbose = "boolean",
  },
  field_ranges = {
    level = {min = 0, max = 5},
    threshold = {min = 0, max = 100}
  }
}, {
  -- Default values
  enabled = true,
  level = 3,
  threshold = 80,
  debug = false,
  verbose = false,
})
```

#### Reporting Module Configuration Schema:

```lua
central_config.register_module("reporting", {
  field_types = {
    debug = "boolean",
    verbose = "boolean",
    report_dir = "string",
    report_suffix = "string",
    timestamp_format = "string",
    formats = "table"
  }
}, {
  -- Default values
  debug = false,
  verbose = false,
  report_dir = "./coverage-reports",
  report_suffix = "",
  timestamp_format = "%Y-%m-%d",
  formats = {
    coverage = {
      default = "html",
      path_template = nil
    },
    quality = {
      default = "html",
      path_template = nil
    },
    results = {
      default = "junit",
      path_template = nil
    }
  }
})
```

#### Async Module Configuration Schema:

```lua
central_config.register_module("async", {
  field_types = {
    default_timeout = "number",
    check_interval = "number",
    debug = "boolean",
    verbose = "boolean"
  },
  field_ranges = {
    default_timeout = {min = 1},
    check_interval = {min = 1}
  }
}, {
  -- Default values
  default_timeout = 1000, -- 1 second default timeout in ms
  check_interval = 10, -- Default check interval in ms
  debug = false,
  verbose = false
})
```

#### Parallel Module Configuration Schema:

```lua
central_config.register_module("parallel", {
  field_types = {
    workers = "number",
    timeout = "number",
    output_buffer_size = "number",
    verbose = "boolean",
    show_worker_output = "boolean",
    fail_fast = "boolean",
    aggregate_coverage = "boolean",
    debug = "boolean"
  },
  field_ranges = {
    workers = {min = 1, max = 64},
    timeout = {min = 1},
    output_buffer_size = {min = 1024}
  }
}, {
  -- Default values
  workers = 4,                 -- Default number of worker processes
  timeout = 60,                -- Default timeout in seconds per test file
  output_buffer_size = 10240,  -- Buffer size for capturing output
  verbose = false,             -- Verbose output flag
  show_worker_output = true,   -- Show output from worker processes
  fail_fast = false,           -- Stop on first failure
  aggregate_coverage = true,   -- Combine coverage data from all workers
  debug = false,               -- Debug mode
})
```

#### Watcher Module Configuration Schema:

```lua
central_config.register_module("watcher", {
  field_types = {
    check_interval = "number",
    watch_patterns = "table",
    default_directory = "string",
    debug = "boolean",
    verbose = "boolean"
  },
  field_ranges = {
    check_interval = {min = 0.1, max = 60}
  }
}, {
  -- Default values
  check_interval = 1.0, -- seconds
  watch_patterns = {
    "%.lua$",           -- Lua source files
    "%.txt$",           -- Text files
    "%.json$",          -- JSON files
  },
  default_directory = ".",
  debug = false,
  verbose = false
})
```

#### Configuration Access Pattern:

```lua
-- Get configuration value
local threshold = central_config.get("coverage.threshold", 80)

-- Set configuration value
central_config.set("coverage.threshold", 90)

-- Listen for configuration changes
central_config.on_change("coverage.threshold", function(path, old_value, new_value)
  -- Handle configuration change
end)
```

## Component Interfaces

### 1. Coverage Module → Debug Hook Interface

#### Core Functions:
- `debug_hook.set_config(config)`: Configures the debug hook with coverage settings
- `debug_hook.debug_hook(event, line)`: The actual debug hook function registered with Lua
- `debug_hook.reset()`: Resets coverage data
- `debug_hook.should_track_file(file_path)`: Determines if a file should be tracked
- `debug_hook.initialize_file(file_path, options)`: Initializes a file for coverage tracking
- `debug_hook.track_blocks_for_line(file_path, line_num)`: Tracks blocks that contain a specific line

#### Coverage Data Access Functions:
- `debug_hook.get_coverage_data()`: Returns the raw coverage data structure (legacy, use accessor functions instead)
- `debug_hook.get_files()`: Returns all files in coverage data
- `debug_hook.get_file_data(file_path)`: Returns data for a specific file
- `debug_hook.has_file(file_path)`: Checks if a file exists in coverage data
- `debug_hook.get_file_source(file_path)`: Gets source lines for a file
- `debug_hook.get_file_source_text(file_path)`: Gets source text for a file
- `debug_hook.get_file_covered_lines(file_path)`: Gets covered lines for a file
- `debug_hook.get_file_executed_lines(file_path)`: Gets executed lines for a file
- `debug_hook.get_file_executable_lines(file_path)`: Gets executable lines for a file
- `debug_hook.get_file_functions(file_path)`: Gets function data for a file
- `debug_hook.get_file_logical_chunks(file_path)`: Gets logical chunks (blocks) for a file
- `debug_hook.get_file_logical_conditions(file_path)`: Gets logical conditions for a file
- `debug_hook.get_file_code_map(file_path)`: Gets code map for a file
- `debug_hook.get_file_ast(file_path)`: Gets AST for a file
- `debug_hook.get_file_line_count(file_path)`: Gets line count for a file

#### Coverage Data Modification Functions:
- `debug_hook.set_line_covered(file_path, line_num, covered)`: Sets covered status for a line
- `debug_hook.set_line_executed(file_path, line_num, executed)`: Sets executed status for a line
- `debug_hook.set_line_executable(file_path, line_num, executable)`: Sets executable status for a line
- `debug_hook.set_function_executed(file_path, func_key, executed)`: Sets executed status for a function
- `debug_hook.add_function(file_path, func_key, func_data)`: Adds a function to coverage data
- `debug_hook.set_block_executed(file_path, block_id, executed)`: Sets executed status for a block
- `debug_hook.add_block(file_path, block_id, block_data)`: Adds a block to coverage data
- `debug_hook.track_line(file_path, line_num)`: Explicitly marks a line as executed (for instrumentation)
- `debug_hook.track_function(file_path, func_name, line_start, line_end)`: Tracks function execution
- `debug_hook.track_block(file_path, block_id, line_start, line_end)`: Tracks block execution

#### Coverage Information Functions:
- `debug_hook.was_line_executed(file_path, line_num)`: Checks if a line was executed
- `debug_hook.was_line_covered(file_path, line_num)`: Checks if a line was covered by tests

Notes:
- The debug_hook component no longer performs line classification itself but delegates this responsibility to the static_analyzer component
- The debug_hook component is now the single source of truth for file data initialization through the initialize_file API
- The debug_hook component is now the single source of truth for block tracking through the track_blocks_for_line API
- All access to coverage_data should now go through the accessor functions instead of direct access

#### Data Flow:
- Coverage module passes configuration to debug_hook
- Coverage module accesses coverage data through debug_hook's accessor functions
- Coverage module modifies coverage data through debug_hook's modifier functions
- Coverage module registers debug_hook with Lua's debug system

### 2. Coverage Module → Static Analyzer Interface

#### Functions:
- `static_analyzer.init(options)`: Initializes the static analyzer with options
- `static_analyzer.parse_file(file_path)`: Parses a file and returns its AST and code map
- `static_analyzer.parse_content(content, file_path)`: Parses content directly
- `static_analyzer.get_executable_lines(code_map)`: Returns which lines are executable
- `static_analyzer.is_line_executable(code_map, line_num)`: Checks if a specific line is executable
- `static_analyzer.classify_line_simple(line_text, config)`: Simple line classification without a code map
- `static_analyzer.get_blocks_for_line(code_map, line_num)`: Gets blocks containing a line
- `static_analyzer.get_conditions_for_line(code_map, line_num)`: Gets conditions on a line
- `static_analyzer.get_code_map_for_ast(ast, file_path)`: Generates a code map from an AST
- `static_analyzer.clear_cache()`: Clears the parser cache

#### Data Flow:
- Coverage module initializes static_analyzer with configuration
- Coverage module requests parsed files from static_analyzer
- Static analyzer returns code maps and executability information
- Coverage module integrates this information with runtime execution data

### 3. Coverage Module → File Manager Interface

#### Functions:
- `file_manager.discover_files(config)`: Discovers files matching patterns
- `file_manager.add_uncovered_files(coverage_data, config)`: Adds uncovered files to coverage data
- `file_manager.count_files(files_table)`: Counts files in a table

#### Data Flow:
- Coverage module passes configuration to file_manager
- File manager returns discovered files
- Coverage module incorporates uncovered files into coverage data

### 4. Coverage Module → Patchup Interface

#### Functions:
- `patchup.patch_all(coverage_data)`: Patches all files in coverage data
- `patchup.patch_file(file_path, file_data)`: Patches a specific file's coverage data

#### Data Flow:
- Coverage module passes coverage data to patchup
- Patchup fixes non-executable lines and returns the number of patched lines
- Coverage module updates its data with the patched information

### 5. Coverage Module → Instrumentation Interface

#### Module Configuration Functions:
- `instrumentation.set_config(config)`: Configures the instrumentation module with options
- `instrumentation.get_config()`: Returns the current configuration
- `instrumentation.set_instrumentation_predicate(predicate)`: Sets the function that determines if a file should be instrumented
- `instrumentation.set_module_load_callback(callback)`: Sets the callback function for module loading events
- `instrumentation.clear_cache()`: Clears the instrumentation and sourcemap caches
- `instrumentation.prepare_environment(options)`: Sets up an instrumented environment with _ENV preservation

#### Core Instrumentation Functions:
- `instrumentation.instrument_file(file_path, options)`: Transforms a file by adding coverage tracking
- `instrumentation.instrument_require()`: Instruments the require function to track module loading
- `instrumentation.hook_loaders()`: Hooks into Lua's loadfile, dofile, and load functions
- `instrumentation.translate_error(err)`: Translates error messages using sourcemaps

#### Sourcemap Functions:
- `instrumentation.get_sourcemap(file_path)`: Returns the sourcemap for a file
- `instrumentation.get_stats()`: Returns statistics about instrumentation operations

#### Line Transformation Functions:
- `instrument_line(line, file_path, line_num, is_executable, block_info)`: Applies tracking transforms to a line of code
- `generate_sourcemap(original_source, instrumented_source, file_path)`: Creates sourcemap for mapping between original and instrumented code

#### Data Flow:
- Coverage module initializes and configures instrumentation
- Coverage module selects between debug hook and instrumentation approaches
- If using instrumentation:
  - Coverage module calls instrumentation.set_config to configure behavior
  - Coverage module sets up instrumentation predicate based on should_track_file rules
  - If instrument_on_load is enabled:
    - Instrumentation hooks into Lua's loading functions (loadfile, dofile, load)
    - When files are loaded, they're automatically instrumented
    - Instrumented code calls back to coverage module's track_line, track_block, and track_function functions
  - If not using instrument_on_load:
    - Coverage module pre-instruments specific files (e.g., already loaded modules)
    - Instrumented code calls back to coverage module's tracking functions
- Instrumented code transformation process:
  1. Static analyzer identifies executable lines, blocks, and functions
  2. Instrumentation adds tracking calls at the beginning of executable lines
  3. Instrumentation adds block tracking for control structures
  4. Instrumentation adds function tracking for function definitions
  5. Sourcemap is generated to map between original and instrumented lines
  6. Transformed code is cached for better performance
- Error handling is enhanced with sourcemap translation
- Performance statistics are tracked for evaluation

#### Tracking Functions (in coverage.lua):
- `coverage.track_line(file_path, line_num)`: Tracks a line as executed and covered
- `coverage.track_block(file_path, line_num, block_id, block_type)`: Tracks a block as executed
- `coverage.track_function(file_path, line_num, func_name)`: Tracks a function as executed

#### Implementation Details:
- The instrumentation module has been fully implemented with a modular design
- Source code transformation adds explicit tracking calls for line, block, and function coverage
- Sourcemap functionality provides original line numbers in error messages
- Caching system reduces overhead for repeated runs
- Integration with static analyzer for accurate line classification
- Fallback to basic heuristics when static analysis is unavailable
- Comprehensive configuration options for fine-tuning behavior
- Advanced file transformations handle complex code patterns
- Extensive testing validates functionality, performance, and accuracy

#### Strengths and Trade-offs:
- **Strengths:**
  - More accurate block and branch coverage
  - More detailed function tracking
  - Lower runtime overhead for large codebases
  - Better handling of complex code patterns
  - Improved performance for repeated runs
  - Detailed sourcemaps for error reporting
- **Trade-offs:**
  - Higher setup overhead
  - Higher memory usage due to code transformation and caching
  - More complex implementation
  - For very small projects, may be less efficient than debug hook approach

The instrumentation approach provides an alternative to the debug hook approach with different performance characteristics and capabilities. Users can choose between approaches based on their specific needs and codebase characteristics.

### 6. Coverage Module → Reporting Interface

#### Functions:
- `reporting.configure()`: Configures the reporting system
- `reporting.format_coverage(data, format)`: Formats coverage data in a specific format
- `reporting.save_coverage_report(file_path, data, format)`: Saves a coverage report

#### Data Flow:
- Coverage module processes raw coverage data into report data
- Coverage module passes report data to reporting system
- Reporting system generates and saves formatted reports

### 7. Multiline Comment Detection Interface

#### Functions:
- `static_analyzer.is_in_multiline_comment(file_path, line_num)`: Determines if a line is part of a multiline comment
- `static_analyzer.find_multiline_comments(content)`: Scans content and returns multiline comment ranges
- `static_analyzer.update_multiline_comment_cache(file_path)`: Updates the cache of multiline comments for a file
- `static_analyzer.create_multiline_comment_context()`: Creates a new comment tracking context
- `static_analyzer.process_line_for_comments(line_text, line_num, context)`: Processes a single line to detect comments

#### Data Flow:
- Static analyzer processes source code to identify multiline comment boundaries
- Patchup module uses static_analyzer.is_in_multiline_comment to identify comment lines
- Coverage module uses static_analyzer.is_in_multiline_comment in its process_multiline_comments function
- Coverage module ensures proper coverage exclusion for commented code
- Static analyzer caches comment detection results for improved performance

## Interface Stability

The following interfaces are considered stable and should not be changed without careful consideration:

1. **Public API (init.lua)**: External functions like `init()`, `start()`, `stop()`, `reset()`, `report()`, and `save_report()`.

2. **Coverage Data Structure**: The structure of the `coverage_data` object should remain backward compatible.

3. **Debug Hook Registration**: The mechanism for registering and using the debug hook function.

4. **Centralized Configuration API**: The core API functions of the central_config module (`get()`, `set()`, `register_module()`, etc.) should remain stable as they will be used throughout the codebase.

5. **Error Handler API**: The core API functions of the error_handler module (`create()`, `throw()`, `assert()`, etc.) should remain stable as they will be used throughout the codebase.

## Interface Improvement Opportunities

The following interfaces have been identified as candidates for improvement:

1. ✓ **Coverage Data Access**: ~~Currently, some components directly access the coverage_data structure. This should be replaced with accessor functions.~~ This has been addressed by implementing comprehensive accessor functions in the debug_hook component, ensuring all coverage data access goes through a well-defined API.

2. ✓ **Line Classification**: ~~The responsibility for determining if a line is executable is split between components and should be consolidated.~~ This has been addressed by consolidating line classification to the static_analyzer component.

3. ✓ **File Data Initialization**: ~~Multiple components initialize file data, leading to potential inconsistencies.~~ This has been addressed by centralizing file initialization in the debug_hook component with a public API.

4. ✓ **Block Tracking**: ~~Multiple components implement block tracking logic independently.~~ This has been addressed by centralizing block tracking in the debug_hook component.

5. ✓ **Multiline Comment Handling**: ~~Multiple components implement multiline comment detection and handling.~~ This has been addressed by centralizing multiline comment detection in the static_analyzer component.

6. ✓ **Error Handling**: ~~Error handling is inconsistent across components, with some using pcall directly and others assuming error_handler might not be available.~~ This has been addressed by implementing a standardized error handling system throughout the codebase. The error_handler module is now treated as a required component, with consistent error handling patterns across all modules:

   **Phase 1: Core Module Implementation** ✓
   - Removed all fallback code in coverage/init.lua
   - Enhanced debug_hook.lua with proper error handling ✓
     - Added missing track_line function for instrumentation support
     - Implemented track_function and track_block with proper error handling
     - Added full type checking throughout the module
     - Fixed boolean indexing issues in patchup module
   - Updated file_manager.lua with comprehensive error handling
   - Standardized error categories, severity levels, and propagation patterns
   - Implemented consistent input validation across all functions
   - Fixed test suite to properly test error handling

   **Phase 2: Module Integration** (In Progress)
   - ✅ Updated module_reset.lua with comprehensive error handling (2025-03-11)
     - Replaced temporary validation functions with error_handler patterns
     - Added detailed error context with operation-specific information
     - Enhanced error propagation with operation names
     - Converted direct error calls to structured error_handler.throw
     - Added safe try/catch patterns for print operations
   - ✅ Enhanced filesystem.lua with standardized error handling (2025-03-11)
     - Added direct error_handler dependency to ensure availability
     - Implemented comprehensive parameter validation for file operations
     - Enhanced safe_io_action with try/catch patterns
     - Added structured error objects with operation context
     - Implemented error chaining to preserve original causes
     - Added special handling for partial success scenarios
   - Convert remaining coverage modules to use standardized error handling
   - Apply consistent error patterns to all tools and utilities
   - Create comprehensive documentation for error handling system

7. ✓ **Configuration Propagation**: ~~Configuration is passed separately to each component rather than through a centralized mechanism.~~ This has been addressed by implementing a centralized configuration system (central_config.lua) that provides hierarchical configuration access, validation, and notification. Project-wide integration of this system is now complete, with the legacy config.lua module deprecated and marked for removal:
   
   **Phase 1: Core Framework Integration** ✓
   - Updated lib/core/config.lua to act as a bridge to central_config
   - Maintained backward compatibility for existing code
   - Registered core modules with the central_config system
   - Implemented change listeners for dynamic reconfiguration
   
   **Phase 2: Module Integration** (Completed ✓)
   - Updated coverage module to use central_config directly ✓
     - Implemented lazy loading to avoid circular references
     - Established prioritized configuration sources
     - Added two-way synchronization of configuration changes
     - Implemented dynamic reconfiguration through change listeners
     - Enhanced reset and debugging functionality
     - Integrated with centralized format settings
   - Updated quality module to use central_config directly ✓
     - Applied same patterns as coverage module
     - Added enhanced support for report path templates
     - Implemented full_reset() and debug_config() functions
   - Updated reporting module to use central_config directly ✓
     - Created comprehensive DEFAULT_CONFIG with report options
     - Enhanced format functions to use central configuration
     - Added support for report path templates
     - Improved auto_save_reports with central configuration integration
     - Implemented reset(), full_reset(), and debug_config() functions 
   - Updated async module to use central_config directly ✓
     - Added schema validation with range constraints for timeouts
     - Enhanced wait_until() to use configurable check_interval
     - Updated set_timeout() for two-way synchronization
     - Improved logging with structured debug information
     - Added reset(), full_reset(), and debug_config() functions
   - Updated parallel module to use central_config directly ✓
     - Added schema with range constraints for worker count and timeouts
     - Enhanced CLI integration to update central_config with command-line options
     - Implemented automatic module initialization with configure()
     - Added two-way synchronization with centralized configuration
     - Improved logging with structured parameter information
     - Added reset(), full_reset(), and debug_config() functions
   - Updated watcher module to use central_config directly ✓
     - Moved watch_patterns to configuration system
     - Added schema validation with range constraints for check_interval
     - Enhanced add_patterns() to synchronize with central_config
     - Updated file checking to use centralized configuration
     - Added special handling for watch_patterns array
     - Implemented reset(), full_reset(), and debug_config() functions
   - Updated interactive CLI module to use central_config directly ✓
     - Created DEFAULT_CONFIG with comprehensive CLI options
     - Added schema validation for UI-specific settings (prompt, colors)
     - Updated CLI commands to synchronize with central_config
     - Enhanced prompt and output handling with customization options
     - Added special handling for array settings (watch_dirs, patterns)
     - Added support for persistent configuration between sessions
     - Implemented reset(), full_reset(), and debug_config() functions
   
   **Phase 3: Formatter Integration** (Completed ✓)
   - **Core Formatters Integration** (Completed ✓)
     - Schema definition and registration for all formatters ✓
     - HTML formatter: Added theme support and configuration options ✓
     - JSON formatter: Added pretty-printing and metadata control ✓
     - Summary formatter: Added colorization and detail level control ✓
   - **XML-based Formatters Integration** (Completed ✓)
     - JUnit formatter: Added schema version and XML formatting support ✓
     - Cobertura formatter: Added path normalization and package organization options ✓
   - **Specialized Formatters Integration** (Completed ✓)
     - LCOV formatter: Added path normalization, function line tracking, and checksums ✓
     - TAP formatter: Added version configuration and diagnostic display options ✓
     - CSV formatter: Added delimiter, quoting, and field selection configuration ✓
   
   #### Formatter Configuration Schemas:
   
   ```lua
   -- HTML Formatter
   {
     theme = "dark",               -- "dark" or "light" theme
     show_line_numbers = true,     -- Show line numbers in source view
     collapsible_sections = true,  -- Allow sections to be collapsed
     highlight_syntax = true,      -- Apply syntax highlighting
     asset_base_path = nil,        -- Path to assets (optional)
     include_legend = true         -- Show legend explaining colors
   }
   
   -- JSON Formatter
   {
     pretty = false,             -- Pretty-print JSON output
     schema_version = "1.0",     -- Schema version to include
     include_metadata = true     -- Include metadata in output
   }
   
   -- Summary Formatter
   {
     detailed = false,           -- Show detailed file information
     show_files = true,          -- Include file list in output
     colorize = true,            -- Use ANSI colors in output
     min_coverage_warn = 70,     -- Warning threshold percentage
     min_coverage_ok = 80        -- Success threshold percentage
   }
   
   -- JUnit Formatter
   {
     schema_version = "2.0",     -- JUnit schema version
     include_timestamp = true,   -- Include timestamp attribute
     include_hostname = true,    -- Include hostname attribute
     include_system_out = true,  -- Include system-out section
     add_xml_declaration = true, -- Add XML declaration
     format_output = false       -- Format XML with indentation
   }
   
   -- Cobertura Formatter
   {
     schema_version = "4.0",     -- Cobertura schema version
     include_packages = true,    -- Group files by package
     include_branches = true,    -- Include branch coverage info
     include_line_counts = true, -- Include line count attributes
     add_xml_declaration = true, -- Add XML declaration
     format_output = false,      -- Format XML with indentation
     normalize_paths = true,     -- Normalize file paths
     include_sources = true      -- Include sources section
   }
   
   -- LCOV Formatter
   {
     normalize_paths = true,        -- Convert absolute paths to relative paths
     include_function_lines = true, -- Include function line information
     use_actual_execution_counts = false, -- Use actual execution count instead of binary 0/1
     include_checksums = false,     -- Include checksums in line records
     exclude_patterns = {}          -- Patterns for files to exclude from report
   }
   
   -- TAP Formatter
   {
     version = 13,                  -- TAP version (12 or 13)
     include_yaml_diagnostics = true, -- Include YAML diagnostics for failures
     include_summary = true,        -- Include summary comments at the end
     include_stack_traces = true,   -- Include stack traces in diagnostics
     default_skip_reason = "Not implemented yet", -- Default reason for skipped tests
     indent_yaml = 2                -- Number of spaces to indent YAML blocks
   }
   
   -- CSV Formatter
   {
     delimiter = ",",               -- Field delimiter character
     quote = "\"",                  -- Quote character for fields
     double_quote = true,           -- Double quotes for escaping
     include_header = true,         -- Include header row
     include_summary = false,       -- Include summary row at end
     date_format = "%Y-%m-%dT%H:%M:%S", -- Date format for timestamps
     fields = {                     -- Fields to include in output (in order)
       "test_id", "test_suite", "test_name", "status", "duration", 
       "message", "error_type", "details", "timestamp"
     }
   }
   ```
   **Phase 4: Transitioning Away from Legacy Config** (Completed ✓)
   - Deprecated lib/core/config.lua with clear warning messages
   - Created a redirector bridge that forwards calls to central_config
   - Updated error_handler.lua to use central_config directly
   - Updated lust-next.lua to use central_config directly
   - Updated test files to use central_config directly
   - Added CLI handling for central_config in parse_args
   - Added help text for central_config options
   
   **Phase 5: Testing and Verification** (Planned)

7. ⚠️ **Error Handling**: ~~Error handling is inconsistent across components with different approaches and error reporting.~~ PARTIALLY ADDRESSED:
   - ✓ Created standardized error handling system (error_handler.lua) with structured error objects
   - ✓ Implemented categorization, severity levels, and logging integration
   - ❌ CRITICAL ISSUE (2025-04-11): Discovered fundamental flaw in implementation - assumes error_handler might not be available
   - ❌ Found 38 instances of conditional error handler checks with 32 fallback blocks
   - ⚠️ Currently creating detailed implementation plan to address these issues

These improvement opportunities are being addressed during the repair process to create cleaner, more maintainable interfaces.