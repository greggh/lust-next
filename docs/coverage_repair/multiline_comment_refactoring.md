# Multiline Comment Handling Refactoring

## Summary

This document outlines the refactoring performed to centralize multiline comment detection in the coverage module. Previously, both `patchup.lua` and `init.lua` contained their own implementations for detecting and handling multiline comments, leading to potential inconsistencies and code duplication. This refactoring creates a centralized API in the `static_analyzer.lua` module, making it the single source of truth for multiline comment detection.

## Problem

Prior to refactoring, there were multiple implementations for detecting multiline comments:

1. `patchup.lua` contained an `is_in_multiline_comment` function with two strategies:
   - Simple state tracking for single line detection
   - A more accurate approach that scanned from the beginning of the file

2. `init.lua` contained two implementations:
   - `process_multiline_comments` function using a two-pass algorithm for comment detection
   - Additional multiline comment handling during report generation using pattern matching

This duplication of code led to:
- Maintenance challenges when fixing bugs or improving the algorithm
- Potential inconsistencies in comment detection between different modules
- Unnecessary complexity for what should be a clear responsibility

## Solution

The refactoring centralizes all multiline comment detection in the `static_analyzer.lua` module by:

1. Implementing a comprehensive multiline comment detection API in `static_analyzer.lua`
2. Updating `patchup.lua` to use this API instead of its own implementation
3. Updating `init.lua` to use the same API for its multiline comment handling

### New API in static_analyzer.lua

The following functions were added to `static_analyzer.lua`:

```lua
M.create_multiline_comment_context()       -- Creates a context for comment tracking
M.process_line_for_comments()              -- Processes a single line to detect comments
M.find_multiline_comments()                -- Processes a content string to find all comments
M.update_multiline_comment_cache()         -- Updates the cache for a file's comment status
M.is_in_multiline_comment()                -- Main API function to check if a line is a comment
```

### Updated Implementation in patchup.lua

The `is_in_multiline_comment` function in `patchup.lua` was updated to use the new API:

```lua
local function is_in_multiline_comment(line, file_path, line_num, file_data)
  -- Use the centralized API from static_analyzer if file_path is available
  if file_path and static_analyzer and static_analyzer.is_in_multiline_comment then
    return static_analyzer.is_in_multiline_comment(file_path, line_num)
  end
  
  -- Fallback logic for backward compatibility
  ...
end
```

### Updated Implementation in init.lua

The multiline comment handling in `init.lua` was updated in several places:

1. The `process_multiline_comments` function was rewritten to use the API
2. The `is_comment_line` function was updated to use the API when possible
3. Multiline comment detection in the report generation code was updated to use the API

## Benefits

1. **Single Source of Truth**: All multiline comment detection logic is now in one place.
2. **Improved Maintenance**: Bug fixes and improvements to the detection algorithm only need to be made in one location.
3. **Consistency**: All components now use the same detection logic, ensuring consistent behavior.
4. **Performance**: The implementation includes caching to avoid re-processing the same files.
5. **Cleaner Code**: Removes duplicated complex code from multiple files.

## Backward Compatibility

The refactored code maintains backward compatibility by:

1. Including fallback logic when the static_analyzer API is not available
2. Maintaining the same function signatures to ensure existing code still works
3. Preserving behavior for edge cases and special conditions

## Testing

The refactored code should be tested with various Lua files containing different multiline comment patterns:

1. Standard multiline comments (`--[[` and `]]`)
2. Nested multiline comments
3. Mixed single-line and multiline comments
4. Comments with code
5. Code with string literals containing comment-like patterns

## Next Steps

- Consider further optimizations for large files
- Add more sophisticated detection for multiline strings vs. comments
- Improve the test suite with specific tests for multiline comment detection