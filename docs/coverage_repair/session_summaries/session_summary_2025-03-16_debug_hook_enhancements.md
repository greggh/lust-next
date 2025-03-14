# Session Summary: Debug Hook Enhancements

## Date: 2025-03-16

## Overview

In this session, we're focusing on enhancing the debug hook component of the coverage module to improve data collection, representation, and the distinction between execution and coverage. This work builds upon the completed static analyzer improvements, particularly the condition expression tracking implementation. The debug hook plays a critical role in capturing actual code execution during tests, and these enhancements will enable more accurate and detailed coverage metrics.

## Goals

1. **Improve Condition Tracking**:
   - Enhance condition outcome detection to work with our improved condition expression tracking
   - Implement accurate tracking of true/false paths in conditions
   - Fix the current heuristic-based approach with a more reliable mechanism

2. **Enhance Block Tracking**:
   - Improve the efficiency and accuracy of block execution tracking
   - Ensure proper integration with the static analyzer's enhanced block detection
   - Fix any issues with parent-child block relationship tracking

3. **Clarify Execution vs. Coverage**:
   - Improve data structures to better distinguish executed lines from covered lines
   - Enhance the public API to provide clearer access to different coverage metrics
   - Ensure consistency in terminology and representation

4. **Performance Improvements**:
   - Optimize the debug hook to minimize performance impact
   - Implement more efficient data structures for tracking coverage data
   - Add metrics for monitoring the performance of the debug hook itself

## Implementation Plan

### 1. Condition Outcome Tracking Enhancement

The current implementation uses a simple heuristic approach for detecting condition outcomes, which can be unreliable. We'll replace this with a more accurate approach that leverages our enhanced condition expression tracking:

```lua
-- Enhanced condition tracking function
function M.track_conditions_for_line(file_path, line_num, execution_result)
  -- Skip if condition tracking is disabled
  if not config.track_conditions then
    return nil
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Skip if we don't have file data or code map
  if not M.has_file(file_path) then
    return nil
  end
  
  local code_map = M.get_file_code_map(file_path)
  if not code_map then
    return nil
  end
  
  -- Ensure we have the static analyzer
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Use the static analyzer to find which conditions contain this line
  local conditions_for_line = static_analyzer.get_conditions_for_line(code_map, line_num)
  
  -- Track the conditions that were found
  local tracked_conditions = {}
  
  -- Mark each condition as executed
  for _, condition in ipairs(conditions_for_line) do
    -- Process and track this condition
    local condition_data = M.track_condition(file_path, condition, execution_result)
    if condition_data then
      table.insert(tracked_conditions, condition_data)
    end
  end
  
  return tracked_conditions
end
```

### 2. Block Execution Tracking Improvement

We'll enhance the block tracking to better handle complex nested structures and ensure proper parent-child relationships:

```lua
-- Enhanced block tracking with nested structure support
function M.track_blocks_for_line(file_path, line_num)
  if not config.track_blocks then
    return nil
  end
  
  local normalized_path = fs.normalize_path(file_path)
  
  -- Skip if we don't have file data or code map
  if not M.has_file(file_path) then
    return nil
  end
  
  local code_map = M.get_file_code_map(file_path)
  if not code_map then
    return nil
  end
  
  -- Ensure we have the static analyzer
  if not static_analyzer then
    static_analyzer = require("lib.coverage.static_analyzer")
  end
  
  -- Use the static analyzer to find which blocks contain this line
  local blocks_for_line = static_analyzer.get_blocks_for_line(code_map, line_num)
  
  -- Track the blocks that were found
  local tracked_blocks = {}
  
  -- Process each block
  for _, block in ipairs(blocks_for_line) do
    local block_data = M.track_block_execution(file_path, block)
    if block_data then
      table.insert(tracked_blocks, block_data)
    end
  end
  
  return tracked_blocks
end

-- Process a single block's execution
function M.track_block_execution(file_path, block)
  local normalized_path = fs.normalize_path(file_path)
  local logical_chunks = M.get_file_logical_chunks(file_path)
  
  -- Get or create block record
  local block_copy = logical_chunks[block.id]
  
  if not block_copy then
    -- Create a new block record with all needed metadata
    block_copy = {
      id = block.id,
      type = block.type,
      start_line = block.start_line,
      end_line = block.end_line,
      parent_id = block.parent_id,
      branches = table.copy(block.branches or {}),
      conditions = table.copy(block.conditions or {}),
      executed = true,
      execution_count = 1
    }
  else
    -- Update existing block record
    block_copy.executed = true
    block_copy.execution_count = (block_copy.execution_count or 0) + 1
  end
  
  -- Store the block
  M.add_block(file_path, block.id, block_copy)
  
  -- Process parent blocks
  if block.parent_id and block.parent_id ~= "root" then
    -- Get the parent block from the code map
    local parent_block
    for _, b in ipairs(code_map.blocks) do
      if b.id == block.parent_id then
        parent_block = b
        break
      end
    end
    
    -- Process the parent block if found
    if parent_block then
      M.track_block_execution(file_path, parent_block)
    end
  end
  
  -- Log verbose output
  if config.verbose and logger.is_verbose_enabled() then
    logger.verbose("Executed block", {
      block_id = block.id,
      type = block.type,
      start_line = block.start_line,
      end_line = block.end_line,
      execution_count = block_copy.execution_count
    })
  end
  
  return block_copy
end
```

### 3. Execution vs. Coverage Distinction

We'll improve the data structures and API to better distinguish between execution and coverage:

```lua
-- Enhanced data structures
coverage_data = {
  files = {},                  -- File metadata and content
  executed_lines = {},         -- All lines that were executed (raw execution data)
  covered_lines = {},          -- Lines that are both executed and executable (coverage data)
  functions = {
    executed = {},             -- Functions that were executed
    covered = {}               -- Functions that are considered covered (executed + assertions)
  },
  blocks = {
    executed = {},             -- Blocks that were executed
    covered = {}               -- Blocks that are considered covered (execution + assertions)
  },
  conditions = {
    executed = {},             -- Conditions that were executed
    true_outcome = {},         -- Conditions that executed the true path
    false_outcome = {},        -- Conditions that executed the false path
    fully_covered = {}         -- Conditions where both outcomes were executed
  }
}

-- Improved accessors to distinguish execution from coverage
function M.get_file_executed_lines(file_path)
  -- Return lines that were actually executed
end

function M.get_file_covered_lines(file_path)
  -- Return lines that are considered covered for metrics
end

function M.get_condition_coverage_status(file_path, condition_id)
  -- Return detailed status including execution and outcome coverage
end
```

### 4. Performance Monitoring

We'll add performance monitoring to track the debug hook's impact:

```lua
-- Performance metrics
local performance_metrics = {
  hook_calls = 0,
  hook_execution_time = 0,
  hook_errors = 0,
  last_call_time = 0,
  average_call_time = 0
}

-- Enhanced debug hook with performance monitoring
function M.debug_hook(event, line)
  -- Skip if we're already processing a hook
  if processing_hook then
    return
  end
  
  -- Record start time for performance tracking
  local start_time = os.clock()
  performance_metrics.hook_calls = performance_metrics.hook_calls + 1
  
  -- Set flag to prevent recursion
  processing_hook = true
  
  -- Original hook logic with try/catch
  local success, result = error_handler.try(function()
    -- Main hook logic
  end)
  
  -- Clear processing flag
  processing_hook = false
  
  -- Performance tracking
  local end_time = os.clock()
  local execution_time = end_time - start_time
  performance_metrics.hook_execution_time = performance_metrics.hook_execution_time + execution_time
  performance_metrics.last_call_time = execution_time
  performance_metrics.average_call_time = performance_metrics.hook_execution_time / performance_metrics.hook_calls
  
  -- Track errors
  if not success then
    performance_metrics.hook_errors = performance_metrics.hook_errors + 1
    logger.debug("Debug hook error", {
      error = error_handler.format_error(result),
      location = "debug_hook",
      execution_time = execution_time
    })
  end
end

-- Public API for performance metrics
function M.get_performance_metrics()
  return {
    hook_calls = performance_metrics.hook_calls,
    total_execution_time = performance_metrics.hook_execution_time,
    average_call_time = performance_metrics.average_call_time,
    last_call_time = performance_metrics.last_call_time,
    error_count = performance_metrics.hook_errors
  }
end
```

## Testing Strategy

We'll create comprehensive tests to verify our enhancements:

1. **Condition Tracking Tests**:
   - Test accurate detection of true/false outcomes
   - Test nested and compound conditions
   - Verify proper parent-child relationship handling

2. **Block Tracking Tests**:
   - Test tracking of various block types
   - Verify proper parent-child relationship handling
   - Test execution count tracking

3. **Execution vs. Coverage Tests**:
   - Test the distinction between executed and covered lines
   - Verify proper executability detection
   - Test edge cases like comments within code

4. **Performance Tests**:
   - Benchmark hook execution time
   - Test with large files to ensure scalability
   - Compare performance before and after enhancements

## Expected Outcomes

By implementing these enhancements, we expect to achieve:

1. More accurate condition coverage metrics with proper outcome tracking
2. Better block coverage representation with clear parent-child relationships
3. Clearer distinction between execution and coverage for better user understanding
4. Improved performance and scalability with larger codebases

These improvements will form the foundation for the advanced coverage visualization features planned for Phase 3 of the project.