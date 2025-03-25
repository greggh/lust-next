# HTML Coverage Report Generation Flow

This document outlines the flow of data through the coverage reporting system when generating HTML reports.

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  test.lua       │────▶│  runner.lua     │────▶│  firmo.lua      │
│  CLI interface  │     │  Test execution │     │  Test framework │
│                 │     │                 │     │                 │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│                 │     │                 │     │                 │
│  html.lua       │◀────│  reporting/     │◀────│  coverage/      │
│  HTML formatter │     │  init.lua       │     │  init.lua       │
│                 │     │  Format handling│     │  Data collection│
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                                               │
         │                                               ▼
         │                                      ┌─────────────────┐
         │                                      │                 │
         │                                      │  debug_hook.lua │
         │                                      │  Line tracking  │
         │                                      │                 │
         │                                      └─────────────────┘
         │                                               │
         │                                               ▼
         │                                      ┌─────────────────┐
         │                                      │                 │
         │                                      │  patchup.lua    │
         │                                      │  Data fixing    │
         │                                      │                 │
         │                                      └─────────────────┘
         │                                               │
         │                                               ▼
         │                                      ┌─────────────────┐
         │                                      │                 │
         │                                      │static_analyzer  │
         │                                      │Line classification│
         │                                      │                 │
         │                                      └─────────────────┘
         ▼                                               │
┌─────────────────┐                             ┌─────────────────┐
│                 │                             │                 │
│  HTML Report    │◀────────────────────────────│  report_data    │
│  coverage data  │                             │  Structured data│
│  visualization  │                             │                 │
└─────────────────┘                             └─────────────────┘
```

## Data Flow Through Key Components

1. **test.lua** - Command-line entry point
   - Parses user arguments
   - Forwards arguments to runner.lua 
   - Handles `--coverage` and `--format=html` flags

2. **runner.lua** - Test execution
   - Loads the firmo test framework
   - Initializes coverage module if requested
   - Executes test files
   - Handles report generation after test execution

3. **coverage/init.lua** - Coverage data collection
   - Configures and starts coverage tracking
   - Registers debug hooks for tracking line execution
   - Processes and normalizes coverage data 
   - Generates report data structure

4. **debug_hook.lua** - Line tracking
   - Hooks into Lua debug events
   - Tracks line executions
   - Records execution counts
   - Maintains block relationship data

5. **patchup.lua** - Data correction
   - Fixes coverage data after collection
   - Classifies lines (executable, comment, structure)
   - Corrects block relationship data
   - Filters out non-executable lines

6. **static_analyzer.lua** - Code analysis
   - Parses code to determine line types
   - Identifies block boundaries
   - Handles multiline comments
   - Determines function boundaries

7. **reporting/init.lua** - Report generation
   - Determines which formatter to use
   - Handles report file paths
   - Validates coverage data before formatting
   - Saves formatted output to file

8. **html.lua** - HTML formatting
   - Converts coverage data to HTML representation
   - Adds syntax highlighting and formatting
   - Visualizes line coverage with colors
   - Shows execution counts and block relationships

## Report Data Structure

The key data structure passed between components is the coverage report data:

```lua
report_data = {
  -- Overall summary statistics
  summary = {
    total_files = 10,
    covered_files = 8,
    total_lines = 500,
    covered_lines = 400,
    total_functions = 50,
    covered_functions = 40,
    file_coverage_percent = 80.0,
    line_coverage_percent = 80.0,
    function_coverage_percent = 80.0,
    overall_coverage_percent = 80.0
  },
  
  -- Per-file coverage data
  files = {
    ["/path/to/file.lua"] = {
      -- File statistics
      total_lines = 100,
      covered_lines = 80,
      executable_lines = 90,
      coverage_percent = 88.9,
      
      -- Line data
      lines = {
        [1] = { 
          covered = true,
          executable = true, 
          executed = true,
          count = 5,  -- execution count
          source = "local x = 10"  -- source code
        },
        -- more lines...
      },
      
      -- Block relationship data
      blocks = {
        ["block_1"] = {
          start_line = 10,
          end_line = 20,
          parent = nil,  -- root block
          children = { "block_2", "block_3" }
        },
        ["block_2"] = {
          start_line = 12,
          end_line = 15,
          parent = "block_1",
          children = {}
        },
        -- more blocks...
      },
      
      -- Function data
      functions = {
        ["function_1"] = {
          name = "example_function",
          start_line = 5,
          end_line = 25,
          covered = true,
          execution_count = 3
        },
        -- more functions...
      }
    },
    -- more files...
  }
}
```

## Key Issues and Fixes

1. **Runner.lua Report Generation Fix**:
   - Added report generation to `run_file` function
   - Previously only present in `run_all`
   - Now generates reports for single file test runs

2. **Format Parameter Handling**:
   - Fixed to use user-specified formats
   - Properly handles `--format=html` flag

3. **Line Data Structure**:
   - Changed from boolean to table structure
   - Ensures each line has proper properties

4. **Block Relationship Fixes**:
   - Enhanced path normalization
   - Improved parent-child relationship tracking
   - Added relationship fixing in the coverage.stop() function

These fixes ensure HTML reports are correctly generated with the appropriate structure and content.