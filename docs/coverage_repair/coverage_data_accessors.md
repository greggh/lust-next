# Coverage Data Accessor Functions

This document provides detailed information about the accessor functions for the coverage_data structure, including examples and usage guidelines.

## Overview

The coverage_data structure is the core data structure used by the coverage module to track execution and test coverage information. To improve encapsulation, maintainability, and robustness, all access to this structure should go through the accessor functions defined in debug_hook.lua instead of direct access.

## Accessor Function Categories

The accessor functions are organized into four main categories:

1. **Coverage Data Access Functions**: For retrieving data from the coverage structure
2. **Coverage Data Modification Functions**: For modifying data in the coverage structure
3. **Coverage Information Functions**: For checking coverage status
4. **Core Functions**: Legacy and utility functions

## Coverage Data Access Functions

### Basic File Operations

```lua
-- Check if a file exists in coverage data
local has_file = debug_hook.has_file(file_path)

-- Get all files in coverage data
local all_files = debug_hook.get_files()

-- Get data for a specific file
local file_data = debug_hook.get_file_data(file_path)
```

### File Content Access

```lua
-- Get source lines for a file
local source_lines = debug_hook.get_file_source(file_path)

-- Get source text for a file
local source_text = debug_hook.get_file_source_text(file_path)

-- Get line count for a file
local line_count = debug_hook.get_file_line_count(file_path)
```

### Coverage Status Access

```lua
-- Get covered lines for a file
local covered_lines = debug_hook.get_file_covered_lines(file_path)

-- Get executed lines for a file
local executed_lines = debug_hook.get_file_executed_lines(file_path)

-- Get executable lines for a file
local executable_lines = debug_hook.get_file_executable_lines(file_path)
```

### Analysis Data Access

```lua
-- Get function data for a file
local functions = debug_hook.get_file_functions(file_path)

-- Get logical chunks (blocks) for a file
local logical_chunks = debug_hook.get_file_logical_chunks(file_path)

-- Get logical conditions for a file
local logical_conditions = debug_hook.get_file_logical_conditions(file_path)
```

### Static Analysis Access

```lua
-- Get code map for a file
local code_map = debug_hook.get_file_code_map(file_path)

-- Get AST for a file
local ast = debug_hook.get_file_ast(file_path)
```

## Coverage Data Modification Functions

### Line Status Modification

```lua
-- Set covered status for a line
debug_hook.set_line_covered(file_path, line_num, true)

-- Set executed status for a line
debug_hook.set_line_executed(file_path, line_num, true)

-- Set executable status for a line
debug_hook.set_line_executable(file_path, line_num, false)
```

### Function Modification

```lua
-- Set executed status for a function
debug_hook.set_function_executed(file_path, func_key, true)

-- Add a function to coverage data
local func_data = {
  name = "example_function",
  line = 42,
  executed = false,
  params = {"param1", "param2"}
}
debug_hook.add_function(file_path, "42:example_function", func_data)
```

### Block Modification

```lua
-- Set executed status for a block
debug_hook.set_block_executed(file_path, block_id, true)

-- Add a block to coverage data
local block_data = {
  id = "block_1",
  type = "function_body",
  start_line = 42,
  end_line = 50,
  parent_id = "root",
  branches = {},
  executed = false
}
debug_hook.add_block(file_path, "block_1", block_data)
```

## Coverage Information Functions

```lua
-- Check if a line was executed
local was_executed = debug_hook.was_line_executed(file_path, line_num)

-- Check if a line was covered by tests
local was_covered = debug_hook.was_line_covered(file_path, line_num)
```

## Legacy Function

The original get_coverage_data() function is maintained for backward compatibility, but new code should use the accessor functions instead:

```lua
-- Legacy function (avoid using in new code)
local coverage_data = debug_hook.get_coverage_data()
```

## Best Practices

1. **Always use accessor functions**: Never access the coverage_data structure directly.

2. **Check for existence before access**: Use has_file() before accessing file-specific data.

3. **Handle empty returns**: Accessor functions return empty tables or nil when data doesn't exist, so handle these cases appropriately.

4. **Use path normalization consistently**: All accessor functions handle path normalization internally, but make sure to use consistent path formats.

5. **Initialization**: Use initialize_file() to create new file entries rather than creating them directly.

6. **Setters vs adders**: Use set_* functions to update existing entries and add_* functions to create new entries.

## Examples

### Example 1: Tracking line execution

```lua
-- Initialize file if needed
if not debug_hook.has_file(file_path) then
  debug_hook.initialize_file(file_path)
end

-- Mark line as executed
debug_hook.set_line_executed(file_path, line_num, true)

-- Only if line is executable, mark it as covered
local code_map = debug_hook.get_file_code_map(file_path)
if code_map and static_analyzer.is_line_executable(code_map, line_num) then
  debug_hook.set_line_covered(file_path, line_num, true)
  debug_hook.set_line_executable(file_path, line_num, true)
end
```

### Example 2: Working with blocks

```lua
-- Get logical chunks for the file
local logical_chunks = debug_hook.get_file_logical_chunks(file_path)

-- Iterate through blocks to find ones containing a line
for block_id, block_data in pairs(logical_chunks) do
  if line_num >= block_data.start_line and line_num <= block_data.end_line then
    -- Mark the block as executed
    debug_hook.set_block_executed(file_path, block_id, true)
    
    -- If the block has a parent, mark it as executed too
    if block_data.parent_id and block_data.parent_id ~= "root" then
      debug_hook.set_block_executed(file_path, block_data.parent_id, true)
    end
  end
end
```

### Example 3: Accessing coverage information

```lua
-- Get coverage statistics for a file
local file_path = "lib/some_module.lua"
local covered_lines = debug_hook.get_file_covered_lines(file_path)
local executable_lines = debug_hook.get_file_executable_lines(file_path)

-- Count covered executable lines
local covered_count = 0
local executable_count = 0
for line_num, is_executable in pairs(executable_lines) do
  if is_executable then
    executable_count = executable_count + 1
    if covered_lines[line_num] then
      covered_count = covered_count + 1
    end
  end
end

-- Calculate coverage percentage
local coverage_percent = executable_count > 0 
  and (covered_count / executable_count * 100) 
  or 0
```

## Migration from Direct Access

If you have existing code that directly accesses coverage_data, here's how to migrate it:

### Before:
```lua
-- Direct access to coverage_data
local file_data = coverage_data.files[normalized_path]
local source_lines = file_data.source
local covered_lines = file_data.lines
```

### After:
```lua
-- Using accessor functions
local file_data = debug_hook.get_file_data(file_path)
local source_lines = debug_hook.get_file_source(file_path)
local covered_lines = debug_hook.get_file_covered_lines(file_path)
```

## Conclusion

Using the accessor functions instead of direct access to the coverage_data structure improves code encapsulation, maintainability, and robustness. These accessor functions provide a stable interface for interacting with the coverage data while hiding implementation details and protecting against common errors like missing initialization or inconsistent path handling.