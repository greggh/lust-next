# Coverage System Data Structure Specification

One of the primary issues with the current coverage system is inconsistent data structures across different components. This document specifies the standardized data structure that will be used throughout the rebuilt coverage system.

## Core Principles

1. **Consistency**: The same data structure format will be used from initial data collection through reporting
2. **Clarity**: All fields have clear, self-documenting names
3. **Completeness**: The structure contains all data needed for all operations
4. **Validation**: The structure can be validated for correctness at any point

## Data Structure Definition

```lua
coverage_data = {
  -- Summary statistics for the entire codebase
  summary = {
    -- File statistics
    total_files = 0,           -- Total number of tracked files
    covered_files = 0,         -- Files with at least one covered line
    executed_files = 0,        -- Files with at least one executed line
    file_coverage_percent = 0, -- Percentage of files with at least one covered line
    
    -- Line statistics
    total_lines = 0,                -- Total number of lines across all files
    executable_lines = 0,           -- Total lines that can be executed
    executed_lines = 0,             -- Total lines that were executed
    covered_lines = 0,              -- Total lines that were covered (executed + validated)
    line_coverage_percent = 0,      -- Percentage of executable lines that were covered
    execution_coverage_percent = 0, -- Percentage of executable lines that were executed
    
    -- Function statistics
    total_functions = 0,            -- Total number of functions
    executed_functions = 0,         -- Functions that were executed at least once
    covered_functions = 0,          -- Functions that were covered
    function_coverage_percent = 0,  -- Percentage of functions covered
    
    -- Combined metrics
    overall_coverage_percent = 0,   -- Weighted average of line, function, and file coverage
  },
  
  -- Detailed data for each file
  files = {
    [normalized_path] = {
      -- File metadata
      path = "",             -- The normalized file path
      name = "",             -- The file name (without path)
      source = "",           -- Full source code content
      discovered = true,     -- Whether the file was discovered during tracking
      
      -- Line-specific data
      lines = {
        [line_number] = {
          executable = true|false,  -- Whether this line can be executed
          executed = true|false,    -- Whether this line was executed
          covered = true|false,     -- Whether this line was covered (executed + validated)
          execution_count = 0,      -- Number of times the line was executed
          line_type = "code|comment|blank|structure", -- Line classification
          content = "",             -- The line content (for reporting)
        },
        -- Additional lines...
      },
      
      -- Execution count mapping (for quick lookup)
      execution_counts = {
        [line_number] = count, -- Number of times each line was executed
      },
      
      -- Function data
      functions = {
        [function_id] = {
          name = "",               -- Function name (if available)
          start_line = 0,          -- Starting line number
          end_line = 0,            -- Ending line number
          executed = true|false,   -- Whether function was called
          covered = true|false,    -- Whether function was covered
          execution_count = 0,     -- Number of times called
        },
        -- Additional functions...
      },
      
      -- Block relationship data
      blocks = {
        [block_id] = {
          type = "function|if|for|while|do|repeat", -- Block type
          start_line = 0,          -- Starting line number
          end_line = 0,            -- Ending line number
          parent_id = "",          -- ID of parent block (for nesting)
          executed = true|false,   -- Whether block was executed
          execution_count = 0,     -- Number of times block was executed
          children = {             -- Child block IDs
            -- block_ids
          }
        },
        -- Additional blocks...
      },
      
      -- File statistics (matches the summary format)
      total_lines = 0,
      executable_lines = 0,
      executed_lines = 0,
      covered_lines = 0,
      line_coverage_percent = 0,
      execution_coverage_percent = 0,
      total_functions = 0,
      executed_functions = 0,
      covered_functions = 0,
      function_coverage_percent = 0,
    },
    -- Additional files...
  }
}
```

## Key Fields Explained

### Line Status Fields

- **executable**: A line that contains actual code that can be executed (not a comment, blank line, or certain structural elements)
- **executed**: A line that was executed at least once during test runs
- **covered**: A line that was both executed AND validated by a test

### Line Types

- **code**: Executable code line
- **comment**: Single or multi-line comment
- **blank**: Empty or whitespace-only line
- **structure**: Syntax element like 'end', 'else', 'until', etc.

### Block Types

- **function**: A function declaration block
- **if**: An if-then-else block
- **for**: A for loop block
- **while**: A while loop block
- **do**: A do-end block
- **repeat**: A repeat-until block

## Validation Rules

To ensure data integrity, the following validation rules should be applied:

1. Every path key in the `files` table must be normalized and consistent
2. Every line number key in the `lines` table must be a positive integer
3. For each file, the statistics (like `total_lines`) must match the actual data in the file
4. `covered_lines` must be less than or equal to `executed_lines`
5. `executed_lines` must be less than or equal to `executable_lines`
6. Sum of per-file statistics must match the corresponding global summary values
7. If a line is marked as `covered`, it must also be marked as `executed` and `executable`

## Usage Throughout the System

This data structure will be used consistently throughout all components:

1. **Debug Hook**: Will directly populate this structure when tracking execution
2. **Static Analyzer**: Will add line classification data to this structure
3. **Coverage Processor**: Will calculate statistics based on this structure
4. **Formatters**: Will generate reports directly from this structure without transformation

## Recommended Implementation Approach

To ensure consistency across the codebase:

1. Create a validation module that can verify the structure
2. Implement helper functions for common operations (e.g., marking a line as executed)
3. Create a standardized initialization function to ensure all fields are populated
4. Add clear documentation throughout the code referencing this specification

By strictly adhering to this data structure throughout the coverage system, we'll eliminate the inconsistencies that have plagued the current implementation.