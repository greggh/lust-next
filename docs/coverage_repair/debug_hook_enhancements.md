# Debug Hook and Static Analyzer Integration Enhancements

## Overview

This document outlines improvements to enhance the integration between the debug hook and static analyzer modules in the coverage system. Based on analysis of the current implementation, these changes will improve line classification accuracy, executability determination, and overall coverage tracking.

## Current Implementation

The debug hook integrates with the static analyzer through several key functions:

1. **is_line_executable()**: A private function in debug_hook.lua that delegates to static_analyzer.is_line_executable()
2. **parse_content()**: Used to generate AST and code maps from source code
3. **track_line()**: Core function for tracking line execution and coverage
4. **classify_line_simple()**: Fallback for simple line classification without AST

The current architecture has a layered approach to determine if a line is executable:
1. First, it checks if executability is explicitly specified in options
2. Next, it uses static analysis via the code map if available
3. As a fallback, it uses simple line classification

## Key Integration Points

The system maintains a clear separation between:
- `_executed_lines`: All lines that were executed (runtime tracking)
- `covered_lines`: Lines that are both executed and executable (coverage metrics)

This distinction is crucial for accurate coverage reporting.

## Improvement Areas

### 1. Enhanced Static Analysis Integration in Track Line

```lua
-- In track_line function, update the static analysis section:
elseif static_analyzer and coverage_data.files[normalized_path].code_map then
  -- Use our enhanced line classification from static_analyzer
  -- with more detailed context information
  is_executable = static_analyzer.is_line_executable(
    coverage_data.files[normalized_path].code_map, 
    line_num,
    { 
      use_enhanced_classification = true,
      track_multiline_context = true
    }
  )
  
  -- Log detailed classification info for debugging
  if config.verbose and logger.is_debug_enabled() then
    logger.debug("Line classification from static analysis", {
      file = normalized_path:match("([^/]+)$") or normalized_path,
      line = line_num,
      is_executable = is_executable,
      source = "static_analyzer.is_line_executable",
      has_code_map = true
    })
  end
```

### 2. Improved Fallback Classification

```lua
-- When code map isn't available, use the enhanced classify_line_simple:
else
  -- Load static analyzer if not loaded
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Get source line from file_data if available
  local source_line = nil
  if coverage_data.files[normalized_path] and 
     coverage_data.files[normalized_path].source and
     coverage_data.files[normalized_path].source[line_num] then
    source_line = coverage_data.files[normalized_path].source[line_num]
  end
  
  -- Use enhanced line classification with context
  local line_type, context = static_analyzer.classify_line_simple_with_context(
    normalized_path, 
    line_num,
    source_line
  )
  
  is_executable = (
    line_type == static_analyzer.LINE_TYPES.EXECUTABLE or
    line_type == static_analyzer.LINE_TYPES.FUNCTION or
    line_type == static_analyzer.LINE_TYPES.BRANCH
  )
  
  -- Store classification context for future reference
  if not coverage_data.files[normalized_path].line_classification then
    coverage_data.files[normalized_path].line_classification = {}
  end
  coverage_data.files[normalized_path].line_classification[line_num] = {
    type = line_type,
    context = context
  }
```

### 3. Improved Code Map Generation

```lua
-- When initializing a file's code map:
if coverage_data.files[normalized_path].source_text then
  local ast, code_map, parsing_context = static_analyzer.parse_content(
    coverage_data.files[normalized_path].source_text, 
    file_path,
    { 
      track_multiline_constructs = true,
      enhanced_comment_detection = true
    }
  )
  
  if ast and code_map then
    coverage_data.files[normalized_path].code_map = code_map
    coverage_data.files[normalized_path].ast = ast
    coverage_data.files[normalized_path].parsing_context = parsing_context
    coverage_data.files[normalized_path].code_map_attempted = true
    
    -- Get executable lines map with enhanced detection
    coverage_data.files[normalized_path].executable_lines = 
      static_analyzer.get_executable_lines(code_map, {
        use_enhanced_detection = true
      })
    
    logger.debug("Generated enhanced code map", {
      file_path = normalized_path,
      has_blocks = code_map.blocks ~= nil,
      has_functions = code_map.functions ~= nil,
      has_conditions = code_map.conditions ~= nil,
      multiline_tracking = parsing_context and parsing_context.multiline_tracking ~= nil
    })
  end
}
```

### 4. Debug Visualizations

```lua
-- Add a new function to visualize line classification for debugging
function M.visualize_line_classification(file_path)
  local normalized_path = fs.normalize_path(file_path)
  if not coverage_data.files[normalized_path] then
    return nil, "File not tracked"
  end
  
  local file_data = coverage_data.files[normalized_path]
  local lines = {}
  
  for i = 1, file_data.line_count do
    local is_executed = file_data._executed_lines[i] or false
    local is_covered = file_data.lines[i] or false
    local is_executable = file_data.executable_lines[i] or false
    
    local line_type = "unknown"
    if file_data.line_classification and file_data.line_classification[i] then
      line_type = file_data.line_classification[i].type
    elseif file_data.code_map and file_data.code_map.lines and file_data.code_map.lines[i] then
      line_type = file_data.code_map.lines[i].type
    end
    
    local source = file_data.source[i] or ""
    
    table.insert(lines, {
      line_num = i,
      source = source,
      executed = is_executed,
      covered = is_covered,
      executable = is_executable,
      type = line_type
    })
  end
  
  return lines
end
```

### 5. Enhanced Error Recovery

```lua
-- Add to the error handling in initialize_file or parse_content calls:
local ast, code_map, err = error_handler.try(function()
  return static_analyzer.parse_content(file_data.source_text, file_path)
end)

if not ast or not code_map then
  -- Log the error
  logger.warn("Failed to generate code map for file", {
    file_path = normalized_path,
    error = err and error_handler.format_error(err) or "unknown error"
  })
  
  -- Try fallback methods for simpler classification
  local executable_lines = {}
  for i = 1, file_data.line_count do
    local line = file_data.source[i]
    if line and static_analyzer.classify_line_simple(line) == static_analyzer.LINE_TYPES.EXECUTABLE then
      executable_lines[i] = true
    end
  end
  
  file_data.executable_lines = executable_lines
  file_data.code_map_attempted = true
  file_data.code_map_failed = true
  file_data.code_map_error = err
end
```

## Implementation Approach

These improvements should be implemented in this order:

1. **Update Static Analyzer**:
   - Add the enhanced classify_line_simple_with_context function
   - Update is_line_executable to accept options parameter
   - Add parsing_context to parse_content return values

2. **Update Debug Hook**:
   - Enhance the track_line function with improved static analyzer integration
   - Add context storage for line classification
   - Update error handling in initialize_file

3. **Add Debug Visualizations**:
   - Add the visualize_line_classification function
   - Update the HTML formatter to display this information

4. **Testing**:
   - Create tests for the new line classification with context
   - Verify correct classification of multiline constructs
   - Test error recovery mechanisms

## Expected Benefits

These improvements will:

1. Increase accuracy of line classification
2. Properly handle multiline constructs (strings, comments)
3. Improve error recovery and diagnostic capabilities
4. Provide better debugging tools for coverage issues
5. Create a more detailed representation of code structure for reporting

## Compatibility Considerations

The changes should be implemented as optional enhancements that default to enabled, with fallbacks to the current behavior to ensure compatibility with existing code.

## Testing Strategy

Tests should verify:

1. Correct classification of complex code patterns
2. Proper handling of multiline strings and comments
3. Accurate tracking of control flow structures
4. Robustness in the presence of errors
5. Performance impact on large files