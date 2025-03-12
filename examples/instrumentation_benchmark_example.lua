-- Instrumentation approach benchmarking example for lust-next coverage
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local benchmark = require("lib.tools.benchmark")

-- Create a sample file with configurable complexity for benchmarking
local function create_test_file(complexity)
    local temp_dir = os.tmpname():gsub("([^/]+)$", "")
    local file_path = temp_dir .. "/benchmark_test_" .. complexity .. ".lua"
    
    -- Create content based on complexity level
    local content = [[
    -- Benchmark test file with complexity level ]] .. complexity .. [[
    
    local M = {}
    
    -- Helper functions
    local function factorial(n)
        if n <= 1 then
            return 1
        else
            return n * factorial(n - 1)
        end
    end
    
    local function fibonacci(n)
        if n <= 1 then
            return n
        else
            return fibonacci(n - 1) + fibonacci(n - 2)
        end
    end
    
    -- Create functions based on complexity
    ]]
    
    -- Add varying number of functions based on complexity
    local function_count = complexity * 5
    for i = 1, function_count do
        content = content .. [[
    function M.test_function_]] .. i .. [[(x)
        local result = 0
        for j = 1, x do
            result = result + j
        end
        return result
    end
    
    ]]
    end
    
    -- Add complex function with many branches
    content = content .. [[
    function M.complex_decision(value)
        if type(value) ~= "number" then
            return "not_a_number"
        end
        
        if value < 0 then
            return "negative"
        elseif value == 0 then
            return "zero"
        end
        
        if value < 10 then
            if value % 2 == 0 then
                return "small_even"
            else
                return "small_odd"
            end
        elseif value < 100 then
            if value % 2 == 0 then
                return "medium_even"
            else
                return "medium_odd"
            end
        else
            if value % 2 == 0 then
                return "large_even"
            else
                return "large_odd"
            end
        end
    end
    ]]
    
    -- Add function with nested loops (complexity affects depth)
    local loop_depth = math.min(complexity, 3)
    content = content .. [[
    function M.nested_loops(size)
        local result = 0
    ]]
    
    -- Create nested loops
    local indent = "    "
    for i = 1, loop_depth do
        content = content .. indent .. "for i" .. i .. " = 1, size do\n"
        indent = indent .. "    "
    end
    
    -- Add loop body
    content = content .. indent .. "result = result + " 
    for i = 1, loop_depth do
        content = content .. "i" .. i .. (i < loop_depth and " * " or "")
    end
    content = content .. "\n"
    
    -- Close loops
    indent = string.rep("    ", loop_depth + 1)
    for i = 1, loop_depth do
        indent = indent:sub(1, -5)
        content = content .. indent .. "end\n"
    end
    
    content = content .. [[
        return result
    end
    ]]
    
    -- Add recursive function with complexity-based depth
    local max_depth = math.min(complexity * 2, 10)  -- Limit max depth to avoid stack overflows
    content = content .. [[
    function M.recursive_function(n, depth)
        depth = depth or 0
        if depth >= ]] .. max_depth .. [[ or n <= 0 then
            return 0
        end
        return n + M.recursive_function(n - 1, depth + 1)
    end
    ]]
    
    -- Add table operations
    local table_size = complexity * 10
    content = content .. [[
    function M.process_large_table(operation)
        local large_table = {}
        for i = 1, ]] .. table_size .. [[ do
            large_table[i] = i
        end
        
        if operation == "sum" then
            local sum = 0
            for i = 1, #large_table do
                sum = sum + large_table[i]
            end
            return sum
        elseif operation == "product" then
            local product = 1
            for i = 1, #large_table do
                product = product * large_table[i]
                if product > 1000000 then
                    product = product % 1000000
                end
            end
            return product
        elseif operation == "average" then
            local sum = 0
            for i = 1, #large_table do
                sum = sum + large_table[i]
            end
            return sum / #large_table
        else
            return #large_table
        end
    end
    ]]
    
    -- Add a runner function to execute various operations
    content = content .. [[
    function M.run_benchmark()
        local results = {}
        
        -- Call various functions to exercise code paths
        for i = 1, ]] .. complexity .. [[ do
            results["function_" .. i] = M["test_function_" .. i](i * 2)
        end
        
        -- Exercise complex decision function
        results.decisions = {
            M.complex_decision("string"),
            M.complex_decision(-5),
            M.complex_decision(0),
            M.complex_decision(5),
            M.complex_decision(8),
            M.complex_decision(50),
            M.complex_decision(75),
            M.complex_decision(500),
            M.complex_decision(999)
        }
        
        -- Exercise nested loops
        results.loops = M.nested_loops(3)
        
        -- Exercise recursive function
        results.recursive = M.recursive_function(]] .. math.min(complexity, 5) .. [[)
        
        -- Exercise large table operations
        results.table_ops = {
            M.process_large_table("sum"),
            M.process_large_table("product"),
            M.process_large_table("average"),
            M.process_large_table("count")
        }
        
        return results
    end
    
    return M
    ]]
    
    -- Write to file
    fs.write_file(file_path, content)
    return file_path
end

-- Function to run benchmark with specified approach
local function run_benchmark(approach, complexity, iterations)
    -- Initialize coverage with specified approach
    if approach == "debug_hook" then
        coverage.init({
            enabled = true,
            use_instrumentation = false,   -- Use debug hook approach
            use_static_analysis = true,
            track_blocks = true
        })
    elseif approach == "instrumentation" then
        coverage.init({
            enabled = true,
            use_instrumentation = true,    -- Use instrumentation approach
            instrument_on_load = true,
            use_static_analysis = true,
            track_blocks = true,
            cache_instrumented_files = true,
            sourcemap_enabled = true
        })
    else
        -- No coverage
        coverage.init({
            enabled = false
        })
    end
    
    -- Reset coverage data
    coverage.reset()
    
    -- Create test file
    local file_path = create_test_file(complexity)
    
    -- Benchmark function to measure performance
    local function test_function()
        -- Start coverage
        coverage.start()
        
        -- Load and execute the benchmark file
        local mod = loadfile(file_path)()
        local result = mod.run_benchmark()
        
        -- Stop coverage
        coverage.stop()
        
        -- Provide a simple result to ensure consistent execution
        return result.loops
    end
    
    -- Run the benchmark with custom implementation since we can't rely on the benchmark module
    local function run_benchmark_custom(func, opts)
        local iterations = opts.iterations or 10
        local warmup = opts.warmup_iterations or 2
        
        -- Perform warmup runs
        for i = 1, warmup do
            func()
        end
        
        -- Measure actual runs
        local times = {}
        local sum = 0
        
        for i = 1, iterations do
            local start_time = os.clock()
            local result = func()
            local end_time = os.clock()
            local elapsed = end_time - start_time
            
            times[i] = elapsed
            sum = sum + elapsed
        end
        
        -- Calculate statistics
        local avg = sum / iterations
        local min = math.huge
        local max = 0
        local sum_sq_diff = 0
        
        for _, time in ipairs(times) do
            min = math.min(min, time)
            max = math.max(max, time)
            sum_sq_diff = sum_sq_diff + (time - avg)^2
        end
        
        local stddev = math.sqrt(sum_sq_diff / iterations)
        
        return {
            average = avg,
            min = min,
            max = max,
            stddev = stddev,
            iterations = iterations,
            name = opts.name
        }
    end
    
    -- Run the benchmark
    local result = run_benchmark_custom(test_function, {
        iterations = iterations,
        warmup_iterations = 2,
        name = "Coverage Approach: " .. approach .. ", Complexity: " .. complexity
    })
    
    -- Clean up
    os.remove(file_path)
    
    return result
end

-- Function to format number with commas for thousands separator
local function format_number(num)
    local str = tostring(math.floor(num))
    local result = ""
    for i = 1, #str do
        if i > 1 and (i - 1) % 3 == 0 then
            result = "," .. result
        end
        result = str:sub(#str - i + 1, #str - i + 1) .. result
    end
    return result
end

-- Default settings
local DEFAULT_COMPLEXITY = 4
local DEFAULT_ITERATIONS = 5

-- Parse command line arguments
local args = {...}
local complexity = tonumber(args[1]) or DEFAULT_COMPLEXITY
local iterations = tonumber(args[2]) or DEFAULT_ITERATIONS

-- Print benchmark header
print("\n=== Lust-Next Coverage Benchmark ===")
print("Comparing different coverage approaches with varied code complexity")
print("Complexity level: " .. complexity .. " (higher = more code)")
print("Iterations: " .. iterations)
print("========================================\n")

-- Run benchmark with different approaches
print("Running benchmarks...\n")

-- First, get baseline performance (no coverage)
print("Baseline (No Coverage)")
local baseline_result = run_benchmark("none", complexity, iterations)
print(string.format("  Avg: %.4f ms", baseline_result.average * 1000))
print(string.format("  Min: %.4f ms", baseline_result.min * 1000))
print(string.format("  Max: %.4f ms", baseline_result.max * 1000))
print(string.format("  StdDev: %.4f ms", baseline_result.stddev * 1000))
print("")

-- Debug hook approach
print("Debug Hook Approach")
local debug_hook_result = run_benchmark("debug_hook", complexity, iterations)
print(string.format("  Avg: %.4f ms", debug_hook_result.average * 1000))
print(string.format("  Min: %.4f ms", debug_hook_result.min * 1000))
print(string.format("  Max: %.4f ms", debug_hook_result.max * 1000))
print(string.format("  StdDev: %.4f ms", debug_hook_result.stddev * 1000))
print(string.format("  Overhead: %.2f%%", 
    ((debug_hook_result.average / baseline_result.average) - 1) * 100))
print("")

-- Instrumentation approach
print("Instrumentation Approach")
local instr_result = run_benchmark("instrumentation", complexity, iterations)
print(string.format("  Avg: %.4f ms", instr_result.average * 1000))
print(string.format("  Min: %.4f ms", instr_result.min * 1000))
print(string.format("  Max: %.4f ms", instr_result.max * 1000))
print(string.format("  StdDev: %.4f ms", instr_result.stddev * 1000))
print(string.format("  Overhead: %.2f%%", 
    ((instr_result.average / baseline_result.average) - 1) * 100))
print("")

-- Summary and comparison
print("=== Performance Comparison ===")
print(string.format("Baseline execution: %.4f ms", baseline_result.average * 1000))
print(string.format("Debug Hook overhead: +%.2f%%", 
    ((debug_hook_result.average / baseline_result.average) - 1) * 100))
print(string.format("Instrumentation overhead: +%.2f%%", 
    ((instr_result.average / baseline_result.average) - 1) * 100))

print("\nDifference between approaches:")
local approach_diff = ((instr_result.average / debug_hook_result.average) - 1) * 100
if approach_diff > 0 then
    print(string.format("Instrumentation is %.2f%% slower than Debug Hook", approach_diff))
else
    print(string.format("Instrumentation is %.2f%% faster than Debug Hook", -approach_diff))
end

print("\n=== Recommendation ===")
if complexity <= 2 then
    print("For small codebases, the Debug Hook approach is recommended for simplicity and lower setup overhead.")
elseif approach_diff < -5 then
    print("For this complexity level, the Instrumentation approach is significantly faster. It's recommended for better performance.")
elseif approach_diff > 5 then
    print("For this complexity level, the Debug Hook approach is significantly faster. It's recommended for better performance.")
else
    print("Both approaches have similar performance at this complexity level. Choose based on other factors like branch coverage needs.")
end

print("\nNote: Run with different complexity levels (1-10) to see how performance scales:")
print("  lua examples/instrumentation_benchmark_example.lua [complexity] [iterations]")