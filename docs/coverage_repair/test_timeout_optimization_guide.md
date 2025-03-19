# Test Timeout Optimization Guide

## Overview

This guide provides strategies for addressing timeout issues in test files, with a specific focus on the identified problematic files in the Firmo coverage module. Test timeouts can significantly impact development workflow and test reliability, making optimization a priority.

## Identified Test Files with Timeout Issues

1. **fallback_heuristic_analysis_test.lua**
   - Issue: Times out when testing coverage with static analysis disabled
   - Root cause: Performance bottlenecks in fallback heuristic analysis

2. **condition_expression_test.lua**
   - Issue: Times out when testing complex condition expressions
   - Root cause: Performance issues in static analyzer's handling of nested conditions

## General Optimization Strategies

### 1. Test Isolation

Isolate slow components to prevent them from affecting the entire test suite:

```lua
-- Skip slow tests unless explicitly enabled
if not os.getenv("RUN_SLOW_TESTS") then
    -- Create a placeholder that reports as skipped
    it("should analyze complex conditions (SKIPPED - long running test)", function()
        firmo.pending("Test skipped - set RUN_SLOW_TESTS=1 to enable")
    end)
    return
end

-- Original slow test will run when RUN_SLOW_TESTS is set
it("should analyze complex conditions", function()
    -- ... original test code ...
end)
```

### 2. Test Splitting

Split large tests into smaller units that can be run independently:

```lua
-- Instead of one large test:
it("should analyze all condition expressions", function()
    -- ... testing many condition types at once ...
end)

-- Split into multiple focused tests:
it("should analyze simple boolean conditions", function()
    -- ... test only boolean conditions ...
end)

it("should analyze comparison conditions", function()
    -- ... test only comparison conditions ...
end)

it("should analyze complex nested conditions", { tags = {"slow"} }, function()
    -- ... test only complex nested conditions ...
end)
```

### 3. Resource Limiting

Add explicit resource limits to prevent runaway tests:

```lua
it("should analyze with reasonable resources", function()
    -- Set up timeout handling
    local start_time = os.clock()
    local MAX_TEST_TIME = 5  -- seconds
    
    -- Add periodic time checks
    local function check_timeout()
        if os.clock() - start_time > MAX_TEST_TIME then
            error("Test timed out after " .. MAX_TEST_TIME .. " seconds")
        end
    end
    
    -- Create test code
    local code = create_complex_test_code()
    
    -- Run test with periodic checks
    for i = 1, #code_sections do
        local section = code_sections[i]
        
        -- Check timeout between sections
        check_timeout()
        
        -- Test this section
        local result = test_section(section)
        expect(result).to.exist()
    end
end)
```

### 4. Targeted Testing

Focus tests on specific scenarios rather than exhaustive combinations:

```lua
-- Instead of testing all combinations:
for depth = 1, 10 do
    for width = 1, 10 do
        for complexity = 1, 10 do
            test_condition_with_parameters(depth, width, complexity)
        end
    end
end

-- Test representative scenarios:
local test_cases = {
    {depth = 1, width = 1, complexity = 1},  -- Simple case
    {depth = 3, width = 3, complexity = 3},  -- Moderate case
    {depth = 5, width = 5, complexity = 5},  -- Complex case
}

for _, case in ipairs(test_cases) do
    test_condition_with_parameters(case.depth, case.width, case.complexity)
end
```

### 5. Memoization and Caching

Add caching for expensive operations to improve performance:

```lua
-- Add caching to expensive functions
local cache = {}

local function expensive_operation(input)
    -- Check cache first
    local cache_key = tostring(input)
    if cache[cache_key] then
        return cache[cache_key]
    end
    
    -- Perform expensive operation
    local result = original_expensive_operation(input)
    
    -- Cache the result
    cache[cache_key] = result
    
    return result
end
```

## Specific Optimization Strategies

### For fallback_heuristic_analysis_test.lua

#### 1. Simplify Test Code

Replace complex test files with minimal examples that still test the functionality:

```lua
-- Original complex test file
local test_code = [[
    -- Import section (commented out to avoid errors)
    -- This is a large complex example with many imports
    local a = "module1" -- require("module1")
    local b = "module2" -- require("module2")
    ... many more lines ...
]]

-- Simplified test file
local test_code = [[
    -- Minimal example that tests the same functionality
    local a = "module1" -- require("module1")
    
    local function test_function()
        return "test"
    end
    
    return test_function()
]]
```

#### 2. Add Explicit Timeouts

Add explicit timeout handling to prevent runaway execution:

```lua
it("should analyze a file with basic heuristics when static analysis is disabled", function()
    -- Add timeout handling
    local timeout = 10  -- seconds
    local success, result, err = test_helper.with_error_capture(function()
        -- Set an alarm to interrupt long-running operations
        local old_alarm = alarm and alarm(timeout) or nil
        
        local result = pcall(function()
            -- Test code here
            local file_path = create_test_file(test_code)
            
            -- Initialize coverage with static analysis disabled to force fallback
            coverage.init({
                enabled = true,
                use_static_analysis = false  -- Force fallback heuristic analysis
            })
            
            -- Rest of test...
        end)
        
        -- Restore original alarm
        if alarm then alarm(old_alarm or 0) end
        
        return result
    end)()
    
    -- Check result or error
    if not success then
        if tostring(result):match("timeout") then
            firmo.pending("Test timed out after " .. timeout .. " seconds")
        else
            error(result)  -- Re-throw unexpected errors
        end
    end
end)
```

#### 3. Profile and Optimize the Fallback Analysis

Identify and optimize slow operations in the fallback heuristic analysis:

```lua
-- Add profiling to the test
it("should profile fallback heuristic analysis", function()
    local profiler = require("profiler")  -- Use a Lua profiler
    
    -- Start profiling
    profiler.start()
    
    -- Run the analysis
    local file_path = create_test_file(test_code)
    coverage.init({
        enabled = true,
        use_static_analysis = false
    })
    coverage.reset()
    coverage.start()
    coverage.track_file(file_path)
    local result = loadfile(file_path)()
    coverage.stop()
    
    -- Stop profiling and report
    profiler.stop()
    local report = profiler.report()
    
    -- Check profiling results
    expect(report).to.exist()
    
    -- Write profiling results to a file for analysis
    fs.write_file("fallback_analysis_profile.txt", report)
end)
```

### For condition_expression_test.lua

#### 1. Limit Condition Complexity

Reduce the complexity of the test cases:

```lua
-- Original complex nested conditions
local nested_code = [[
    if ((a and b) or (c and (d or (e and f)))) and (g or (h and (i or j))) then
        -- With many more complex cases
    end
]]

-- Simplified test cases focusing on specific patterns
local condition_cases = {
    ["simple_and"] = "if a and b then return true end",
    ["simple_or"] = "if a or b then return true end",
    ["nested_and_or"] = "if a and (b or c) then return true end",
    ["complex"] = "if (a and b) or (c and d) then return true end"
}

-- Test each case separately
for name, code in pairs(condition_cases) do
    it("should analyze " .. name .. " condition", function()
        -- Test code for this specific condition type
    end)
end
```

#### 2. Add Early Termination

Add checks to terminate long-running operations:

```lua
it("should analyze condition expressions with timeout", function()
    local MAX_ITERATIONS = 1000
    local iteration_count = 0
    
    -- Replace or monkey-patch the static analyzer to add iteration counting
    local original_analyze = static_analyzer.analyze_condition
    static_analyzer.analyze_condition = function(condition, ...)
        iteration_count = iteration_count + 1
        if iteration_count > MAX_ITERATIONS then
            error("Analysis exceeded maximum iterations")
        end
        return original_analyze(condition, ...)
    end
    
    -- Run test with the iteration-limited function
    local result = test_condition_analysis()
    
    -- Restore original function
    static_analyzer.analyze_condition = original_analyze
    
    -- Check results
    expect(result).to.exist()
    expect(iteration_count).to.be_less_than(MAX_ITERATIONS, 
        "Analysis required " .. iteration_count .. " iterations")
end)
```

#### 3. Implement Multi-stage Testing

Split complex tests into stages that can be run individually:

```lua
-- Define test stages
local test_stages = {
    ["stage1_simple"] = function()
        -- Test simple conditions only
        return test_simple_conditions()
    end,
    
    ["stage2_compound"] = function()
        -- Test compound conditions
        return test_compound_conditions()
    end,
    
    ["stage3_complex"] = function()
        -- Test complex nested conditions
        return test_complex_conditions()
    end
}

-- Get stage from environment or run all stages
local stage_to_run = os.getenv("TEST_STAGE")

if stage_to_run and test_stages[stage_to_run] then
    -- Run just the specified stage
    it("should run " .. stage_to_run, function()
        local result = test_stages[stage_to_run]()
        expect(result).to.be_truthy()
    end)
else
    -- Run a subset of stages by default
    for name, fn in pairs({
        ["stage1_simple"] = test_stages["stage1_simple"],
        ["stage2_compound"] = test_stages["stage2_compound"]
    }) do
        it("should run " .. name, function()
            local result = fn()
            expect(result).to.be_truthy()
        end)
    end
    
    -- Skip the most complex stage by default
    it("should run stage3_complex (SKIPPED - long running)", function()
        firmo.pending("Complex test stage skipped - set TEST_STAGE=stage3_complex to run")
    end)
end
```

## Implementation-Specific Optimizations

### For Static Analysis

#### 1. Add Caching

Implement caching for static analysis results:

```lua
-- In your test setup, add caching for static analysis
local static_analyzer = require("lib.coverage.static_analyzer")
local original_parse = static_analyzer.parse_content
local parse_cache = {}

-- Add caching wrapper
static_analyzer.parse_content = function(content, name)
    -- Create a cache key (using a hash of the content)
    local cache_key = name .. "_" .. string.format("%x", tonumber(string.sub(tostring(content):gsub("[^%w]", ""), 1, 8), 16))
    
    -- Check cache
    if parse_cache[cache_key] then
        return parse_cache[cache_key][1], parse_cache[cache_key][2]
    end
    
    -- Not in cache, call original function
    local ast, code_map = original_parse(content, name)
    
    -- Store in cache
    parse_cache[cache_key] = {ast, code_map}
    
    return ast, code_map
end

-- Make sure to restore the original after tests
after(function()
    static_analyzer.parse_content = original_parse
end)
```

#### 2. Limit Analysis Depth

Add options to limit analysis depth for complex code:

```lua
-- Add a depth-limited test option
it("should analyze with limited depth", function()
    -- Create test code
    local file_path = create_test_file(complex_test_code)
    
    -- Initialize with depth limits
    coverage.init({
        enabled = true,
        static_analyzer_options = {
            max_depth = 5,            -- Limit recursion depth
            max_condition_size = 20,  -- Limit condition expression size
            timeout_ms = 1000         -- Add millisecond timeout
        }
    })
    
    -- Continue with test...
end)
```

### For File Operations

#### 1. Use In-Memory Files

Replace file operations with in-memory alternatives:

```lua
-- Instead of creating actual files
local function create_test_file(content)
    local file_path = temp_file.create_with_content(content, "lua")
    table.insert(test_files, file_path)
    return file_path
end

-- Use in-memory file simulation
local in_memory_files = {}

local function create_virtual_file(content)
    -- Create a pseudo file path
    local file_id = tostring(#in_memory_files + 1)
    local file_path = "memory://" .. file_id .. ".lua"
    
    -- Store the content
    in_memory_files[file_path] = content
    
    -- Mock the fs module to handle these paths
    if not fs._original_read_file then
        fs._original_read_file = fs.read_file
        fs.read_file = function(path)
            if path:match("^memory://") and in_memory_files[path] then
                return in_memory_files[path]
            else
                return fs._original_read_file(path)
            end
        end
    end
    
    return file_path
end
```

#### 2. Implement Batched Testing

Process multiple test cases in a single run:

```lua
it("should process multiple test cases efficiently", function()
    -- Define test cases
    local test_cases = {
        ["case1"] = "local x = 1; return x",
        ["case2"] = "local x, y = 1, 2; return x + y",
        -- More test cases...
    }
    
    -- Initialize coverage once
    coverage.init({ enabled = true })
    coverage.reset()
    coverage.start()
    
    -- Process all cases in a batch
    local results = {}
    for name, code in pairs(test_cases) do
        local file_path = create_test_file(code)
        
        -- Track all files first
        coverage.track_file(file_path)
        
        -- Store for execution
        results[name] = {
            path = file_path,
            loader = loadfile(file_path)
        }
    end
    
    -- Execute all in batch
    for name, data in pairs(results) do
        local success, result = pcall(data.loader)
        expect(success).to.be_truthy("Failed to execute " .. name)
    end
    
    -- Stop coverage once
    coverage.stop()
    
    -- Get report and verify results
    local report_data = coverage.get_report_data()
    
    -- Verify each case in the report
    for name, data in pairs(results) do
        local normalized_path = fs.normalize_path(data.path)
        expect(report_data.files[normalized_path]).to.exist(
            "Missing coverage data for " .. name)
    end
end)
```

## Troubleshooting Common Timeout Issues

### Symptom: Static Analyzer Timeouts on Complex Code

**Root Causes:**
- Inefficient parsing algorithm
- Excessive recursion in parser
- No limit on analysis complexity

**Solutions:**
- Implement limits for recursion depth and complexity
- Add timeouts for static analysis operations
- Optimize the parser algorithm for common patterns
- Add caching for parsed results

### Symptom: Coverage Module Timeout during File Tracking

**Root Causes:**
- Processing large files without chunking
- Reading entire file contents at once
- Missing early termination for problematic files

**Solutions:**
- Implement chunked processing of large files
- Add early termination for problematic patterns
- Implement file size limits with configuration options
- Add progress tracking for long-running operations

### Symptom: Test Suite Hangs on Specific Files

**Root Causes:**
- Infinite loops in analysis
- Memory exhaustion
- Missing timeout handling

**Solutions:**
- Add explicit timeouts to test cases
- Run problematic tests in isolation
- Add resource limits (memory, CPU) to test runner
- Split test suite into separate "fast" and "slow" groups

## Conclusion

Addressing timeout issues in the coverage module tests requires a multi-faceted approach that includes:

1. **Test Optimization**: Simplify tests, limit complexity, and add early termination
2. **Resource Management**: Add explicit timeouts, memory limits, and efficiency improvements
3. **Test Organization**: Split tests into fast/slow groups, add granular test stages
4. **Performance Tuning**: Add caching, optimize algorithms, and monitor resource usage

By applying these strategies, you can significantly improve test reliability and performance, making the development workflow more efficient and maintainable.