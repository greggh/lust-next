# Coverage System V3 Overhaul Plan

## Critical Issues with Current Coverage System

1. **Fundamental Distinction Failure**: The V2 system fails to properly distinguish between:
   - **Executed Lines**: Lines that run during tests
   - **Covered Lines**: Lines that are verified by assertions

2. **Incorrect Coverage Attribution**: 
   - V2 only marks the lines containing assertions as "covered"
   - The actual lines being tested (in source files like calculator.lua) remain marked as "executed" but not "covered"
   - Critical error in the call stack tracing logic

3. **HTML Report Inaccuracy**:
   - Reports show incorrect coverage data
   - Core code falsely appears "covered" when it's only "executed"

## V3 Architecture: Assertion-Based Line Coverage

### Core Principles

1. **Explicit Tracing**: Coverage must explicitly trace what code an assertion is testing
2. **Stack-Based Attribution**: Use stack traces to connect assertions to tested code
3. **Zero Special Cases**: All code must be handled uniformly
4. **Centralized Configuration**: All settings through central_config
5. **Performance Optimization**: Eliminate redundant processing and logging

### Components to Rebuild

1. **Coverage Tracker**:
   - Track execution via debug hooks
   - Maintain separate tables for executed vs. covered lines

2. **Assertion Integration**:
   - Capture call stack when assertions run
   - Identify which functions/lines an assertion verifies
   - Mark those lines as covered

3. **Debug Hook**:
   - Simplified line tracking without recursion
   - Efficient handling of function bodies

4. **Coverage Data Structure**:
   - Clean separation between executed and covered status
   - Optimized table structure to prevent memory bloat

5. **HTML Formatter**:
   - Three-state visualization with clear colors
   - Support for large files without timeouts
   - Accurate representation of covered vs. executed

## Implementation Plan

### Phase 1: Core Data Model Redesign

1. **New Coverage Data Structure**:
   ```lua
   {
     files = {
       [file_path] = {
         lines = {
           [line_number] = {
             executable = true|false,
             executed = true|false,
             covered = true|false,
             execution_count = number,
             assertion_count = number,
             covering_assertions = {
               -- References to assertions that covered this line
               [assertion_id] = {
                 test_file = string,
                 test_line = number,
                 assertion_type = string
               }
             }
           }
         }
       }
     },
     -- Global trackers
     executed_lines = { [file_path:line] = true },
     covered_lines = { [file_path:line] = true },
     
     -- Assertion registry
     assertions = {
       [assertion_id] = {
         test_file = string,
         test_line = number,
         assertion_type = string,
         covered_lines = {
           [file_path] = { line_numbers = {} }
         }
       }
     }
   }
   ```

2. **Execution Tracker**:
   - Track all executed lines without marking as covered
   - Record execution counts accurately
   - Store source file and line content

### Phase 2: Assertion-Coverage Connection

1. **Stack Tracer**:
   - New module to trace call stacks when assertions run
   - Identify which source files and lines were called
   - Connect assertions to the lines they verify

2. **Assertion Wrapper**:
   - Capture pre-assertion state
   - Run assertion
   - Compare post-assertion state
   - Mark relevant lines as covered

3. **Test Context Tracking**:
   - Track which test is running
   - Connect assertions to specific tests
   - Generate test-to-coverage mapping

### Phase 3: Debug Hook Rewrite

1. **Simplified Line Tracker**:
   - Track line execution without redundant recursion
   - Mark executed lines efficiently
   - Preserve covered status when re-executing

2. **Function Boundary Tracker**:
   - Track function entry/exit points
   - Record function structure without full scanning
   - Optimize function boundary detection

3. **Error Handler Integration**:
   - Better error capture during coverage
   - Record lines involved in error handling
   - Properly attribute error paths

### Phase 4: HTML Reporter Rewrite

1. **Three-State Visualizer**:
   - Clear visual distinction between states
   - High contrast, accessible colors
   - Clear labeling of coverage types

2. **Performance Optimization**:
   - Efficient rendering algorithm
   - Proper pagination for large files
   - Reduced memory consumption

3. **Interactive Features**:
   - Toggle between coverage views
   - Drill down into specific files
   - Filter by coverage state

## Implementation Details

### Coverage API

```lua
-- Start coverage with tracing enabled
function coverage.start(options)
  -- options.trace_assertions = true|false
  -- options.trace_depth = number (max stack frames to trace)
end

-- Mark line covered with assertion tracking
function coverage.mark_line_covered(file_path, line_number, assertion_data)
  -- assertion_data.test_file
  -- assertion_data.test_line
  -- assertion_data.assertion_type
end

-- Get detailed coverage data with assertion information
function coverage.get_detailed_report()
  -- Returns enhanced data structure with assertion-line connections
end
```

### Assertion Integration

```lua
-- In assertion.lua
function expect_with_coverage(value)
  -- Capture pre-assertion state
  local pre_state = get_execution_state()
  
  -- Create expectation
  local expectation = create_expectation(value)
  
  -- Wrap all assertion methods to record coverage
  wrap_with_coverage_tracking(expectation)
  
  return expectation
end

-- Coverage tracking wrapper
function wrap_with_coverage_tracking(method, pre_state)
  return function(...)
    -- Run assertion
    local result = method(...)
    
    -- Compare with pre-state to find lines called during assertion
    local covered_lines = compare_execution_states(pre_state, get_execution_state())
    
    -- Mark lines as covered
    for file_path, lines in pairs(covered_lines) do
      for _, line_number in ipairs(lines) do
        coverage.mark_line_covered(file_path, line_number, {
          test_file = debug.getinfo(2).source,
          test_line = debug.getinfo(2).currentline,
          assertion_type = method.name
        })
      end
    end
    
    return result
  end
end
```

### Stack State Capture

```lua
-- Get current execution state
function get_execution_state()
  local state = {
    stack = {},
    executed_lines = {}
  }
  
  -- Capture stack frames
  local level = 1
  while true do
    local info = debug.getinfo(level, "Sln")
    if not info then break end
    
    table.insert(state.stack, {
      file = info.source:sub(2),
      line = info.currentline,
      name = info.name,
      what = info.what
    })
    
    level = level + 1
  end
  
  -- Capture executed lines
  state.executed_lines = table.copy(coverage.get_executed_lines())
  
  return state
end

-- Compare execution states to find what changed
function compare_execution_states(before, after)
  local covered_lines = {}
  
  for file_line in pairs(after.executed_lines) do
    if not before.executed_lines[file_line] then
      local file, line = file_line:match("(.+):(%d+)")
      if file and line then
        line = tonumber(line)
        if not covered_lines[file] then
          covered_lines[file] = {}
        end
        table.insert(covered_lines[file], line)
      end
    end
  end
  
  return covered_lines
end
```

## Migration Strategy

1. **Side-by-Side Development**:
   - Develop V3 in a new "v3" subdirectory
   - Don't replace V2 until V3 is fully tested
   - Provide compatibility layer for smooth transition

2. **Incremental Testing**:
   - Test each component separately
   - Run with minimal test cases first
   - Compare results with expected coverage

3. **Performance Benchmarking**:
   - Measure baseline performance with V2
   - Track performance improvements in V3
   - Ensure V3 is faster than V2

4. **Documentation**:
   - Document architecture decisions
   - Provide clear API guidelines
   - Update CLAUDE.md with V3 requirements

## Success Criteria

1. **Accurate Three-State Visualization**:
   - Executed vs. Covered distinction is accurate
   - HTML report correctly shows all three states
   - No false "covered" lines in core code

2. **Performance**:
   - Reports generate in under 30 seconds
   - Memory usage stays below 500MB
   - No timeouts on large codebases

3. **Correctness**:
   - All tests pass with V3 coverage
   - Edge cases (comments, multiline strings) handled correctly
   - Zero special-case code

4. **API Compatibility**:
   - Existing code continues to work
   - No breaking changes to public API
   - Clear migration path for edge cases

## Timeline

1. **Phase 1**: Core Data Model Redesign - 1 week
   - ✓ Initial architecture created
   - ✓ Basic directory structure set up
   - ✓ Data model module implemented
   - ✓ Stack capture module implemented
   - ✓ Configuration integration module implemented
   - ✓ Main API module implemented
   
2. **Phase 2**: Assertion-Coverage Connection - 1 week
   - ✓ Assertion tracker module implemented
   - ✓ Test context management module implemented
   - ✓ Stack tracer integration with assertions
   - ✓ Connection between assertions and covered code
   - ✓ Test-to-source mapping

3. **Phase 3**: Debug Hook Rewrite - 1 week
   - ✓ Line hook implementation
   - ✓ Call hook implementation
   - ✓ Error hook implementation

4. **Phase 4**: HTML Reporter Rewrite - 1 week
   - ✓ Three-state visualization
   - ✓ High-contrast color scheme
   - ✓ Performance optimizations
   - ✓ Interactive file browser
   - ✓ Assertion tooltips

5. **Testing & Integration**: 1 week
   - ✓ Testing with minimal_coverage_test.lua
   - ✓ Integration with test framework
   - ✓ Verification against calculator.lua
   - ✓ Test script implementation

## Non-Negotiable Requirements

1. NO SPECIAL CASE CODE - All solutions must be general purpose
2. USE CENTRAL_CONFIG - All configuration through the central system
3. ACCURATE STATE DISTINCTION - Executed vs. Covered must be accurate
4. PERFORMANCE FIRST - No compromises on report generation speed
5. CLEAN ARCHITECTURE - No shortcuts, proper abstraction layers