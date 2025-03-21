-- Coverage approach comparison example for firmo
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")

-- Extract test functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Create a sample file to test coverage approaches
local temp_dir = os.tmpname():gsub("([^/]+)$", "")
local sample_file = temp_dir .. "/coverage_test.lua"

-- Function to create test results table
local function create_results_table()
    return {
        files = 0,
        covered_files = 0,
        lines = 0,
        covered_lines = 0,
        functions = 0,
        covered_functions = 0,
        blocks = 0,
        covered_blocks = 0,
        line_coverage_percent = 0,
        function_coverage_percent = 0,
        block_coverage_percent = 0,
        execution_time = 0
    }
end

-- Write sample code to test file with various code patterns
local sample_code = [[
-- This is a sample file for testing coverage approaches
local M = {}

-- Simple function
function M.add(a, b)
    -- Simple addition function
    return a + b
end

-- Function with conditional branches
function M.calculate(a, b, operation)
    if operation == "add" then
        return a + b
    elseif operation == "subtract" then
        return a - b
    elseif operation == "multiply" then
        return a * b
    else
        -- Default to division
        return a / b
    end
end

-- Function with a loop
function M.sum_array(array)
    local result = 0
    for i = 1, #array do
        result = result + array[i]
    end
    return result
end

-- Nested function
function M.process_data(data, processor)
    -- Define a local helper function
    local function apply_processor(item)
        return processor(item)
    end
    
    local results = {}
    for i = 1, #data do
        results[i] = apply_processor(data[i])
    end
    
    return results
end

-- Function that won't be called (uncovered)
function M.uncovered_function()
    print("This function won't be called")
    return true
end

-- More complex function with multiple branches and early returns
function M.analyze_value(value)
    if type(value) ~= "number" then
        return "not_a_number"
    end
    
    if value < 0 then
        return "negative"
    elseif value == 0 then
        return "zero"
    elseif value < 10 then
        return "small"
    elseif value < 100 then
        return "medium"
    else
        return "large"
    end
end

-- Return the module
return M
]]

-- Write the sample file with error handling
local write_success, write_err = error_handler.safe_io_operation(
    function() return fs.write_file(sample_file, sample_code) end,
    sample_file,
    {operation = "write_sample_file"}
)

if not write_success then
    print("Error writing sample file: " .. tostring(write_err.message))
    os.exit(1)
end

-- Run the tests with debug hook approach
local function run_with_debug_hook()
    local results = create_results_table()
    
    -- Configure coverage with debug hook approach
    coverage.init({
        enabled = true,
        use_instrumentation = false,  -- Use debug hook approach
        use_static_analysis = true,
        track_blocks = true
    })
    
    -- Reset coverage data
    coverage.reset()
    
    -- Start coverage tracking
    local start_time = os.clock()
    coverage.start()
    
    -- Load the module and execute code to generate coverage
    package.loaded[sample_file:gsub("%.lua$", "")] = nil  -- Clear from cache if previously loaded
    local module = require(sample_file:gsub("%.lua$", ""))
    
    -- Execute functions to generate coverage
    expect(module.add(2, 3)).to.equal(5)
    expect(module.calculate(10, 5, "add")).to.equal(15)
    expect(module.calculate(10, 5, "subtract")).to.equal(5)
    expect(module.calculate(10, 5, "multiply")).to.equal(50)
    expect(module.calculate(10, 5, "divide")).to.equal(2)
    expect(module.sum_array({1, 2, 3, 4, 5})).to.equal(15)
    expect(module.process_data({1, 2, 3}, function(x) return x * 2 end)[2]).to.equal(4)
    expect(module.analyze_value("not a number")).to.equal("not_a_number")
    expect(module.analyze_value(-5)).to.equal("negative")
    expect(module.analyze_value(0)).to.equal("zero")
    expect(module.analyze_value(5)).to.equal("small")
    expect(module.analyze_value(50)).to.equal("medium")
    expect(module.analyze_value(500)).to.equal("large")
    
    -- Stop coverage tracking
    coverage.stop()
    local end_time = os.clock()
    
    -- Get coverage report
    local report_data = coverage.get_report_data()
    if not report_data or not report_data.summary then
        print("Error: Failed to get coverage report data")
        return results
    end
    
    local summary = report_data.summary
    
    -- Copy results
    results.files = summary.total_files
    results.covered_files = summary.covered_files
    results.lines = summary.total_lines
    results.covered_lines = summary.covered_lines
    results.functions = summary.total_functions
    results.covered_functions = summary.covered_functions
    results.blocks = summary.total_blocks
    results.covered_blocks = summary.covered_blocks
    results.line_coverage_percent = summary.line_coverage_percent
    results.function_coverage_percent = summary.function_coverage_percent
    results.block_coverage_percent = summary.block_coverage_percent
    results.execution_time = end_time - start_time
    
    return results
end

-- Run the tests with instrumentation approach
local function run_with_instrumentation()
    local results = create_results_table()
    
    -- Configure coverage with instrumentation approach
    coverage.init({
        enabled = true,
        use_instrumentation = true,      -- Use instrumentation approach
        instrument_on_load = true,       -- Instrument files when loaded
        use_static_analysis = true,
        track_blocks = true,
        cache_instrumented_files = true,
        sourcemap_enabled = true
    })
    
    -- Reset coverage data
    coverage.reset()
    
    -- Start coverage tracking
    local start_time = os.clock()
    coverage.start()
    
    -- Load the module and execute code to generate coverage
    package.loaded[sample_file:gsub("%.lua$", "")] = nil  -- Clear from cache if previously loaded
    local module = require(sample_file:gsub("%.lua$", ""))
    
    -- Execute functions to generate coverage (same as debug hook approach)
    expect(module.add(2, 3)).to.equal(5)
    expect(module.calculate(10, 5, "add")).to.equal(15)
    expect(module.calculate(10, 5, "subtract")).to.equal(5)
    expect(module.calculate(10, 5, "multiply")).to.equal(50)
    expect(module.calculate(10, 5, "divide")).to.equal(2)
    expect(module.sum_array({1, 2, 3, 4, 5})).to.equal(15)
    expect(module.process_data({1, 2, 3}, function(x) return x * 2 end)[2]).to.equal(4)
    expect(module.analyze_value("not a number")).to.equal("not_a_number")
    expect(module.analyze_value(-5)).to.equal("negative")
    expect(module.analyze_value(0)).to.equal("zero")
    expect(module.analyze_value(5)).to.equal("small")
    expect(module.analyze_value(50)).to.equal("medium")
    expect(module.analyze_value(500)).to.equal("large")
    
    -- Stop coverage tracking
    coverage.stop()
    local end_time = os.clock()
    
    -- Get coverage report
    local report_data = coverage.get_report_data()
    if not report_data or not report_data.summary then
        print("Error: Failed to get coverage report data")
        return results
    end
    
    local summary = report_data.summary
    
    -- Copy results
    results.files = summary.total_files
    results.covered_files = summary.covered_files
    results.lines = summary.total_lines
    results.covered_lines = summary.covered_lines
    results.functions = summary.total_functions
    results.covered_functions = summary.covered_functions
    results.blocks = summary.total_blocks
    results.covered_blocks = summary.covered_blocks
    results.line_coverage_percent = summary.line_coverage_percent
    results.function_coverage_percent = summary.function_coverage_percent
    results.block_coverage_percent = summary.block_coverage_percent
    results.execution_time = end_time - start_time
    
    return results
end

-- Format a number to a fixed number of decimal places
local function format_number(num, decimal_places)
    local factor = 10 ^ (decimal_places or 2)
    return math.floor(num * factor + 0.5) / factor
end

-- Print results table in a formatted way
local function print_results(title, results)
    print("\n" .. title .. ":")
    print(string.format("  Files: %d/%d (%.1f%%)", 
        results.covered_files, results.files, 
        results.files > 0 and (results.covered_files / results.files * 100) or 0))
    
    print(string.format("  Lines: %d/%d (%.1f%%)", 
        results.covered_lines, results.lines, results.line_coverage_percent))
    
    print(string.format("  Functions: %d/%d (%.1f%%)", 
        results.covered_functions, results.functions, results.function_coverage_percent))
    
    print(string.format("  Blocks: %d/%d (%.1f%%)", 
        results.covered_blocks, results.blocks, results.block_coverage_percent))
    
    print(string.format("  Execution time: %.4f seconds", results.execution_time))
end

-- Comparison test
describe("Coverage approach comparison", function()
    it("should compare debug hook and instrumentation approaches", function()
        print("\nRunning coverage approach comparison...")
        
        -- Run with debug hook approach
        local debug_hook_results = run_with_debug_hook()
        print_results("Debug Hook Approach Results", debug_hook_results)
        
        -- Run with instrumentation approach
        local instrumentation_results = run_with_instrumentation()
        print_results("Instrumentation Approach Results", instrumentation_results)
        
        -- Compare results
        print("\nComparison:")
        
        -- Compare coverage percentages
        local line_diff = format_number(instrumentation_results.line_coverage_percent - debug_hook_results.line_coverage_percent)
        local function_diff = format_number(instrumentation_results.function_coverage_percent - debug_hook_results.function_coverage_percent)
        local block_diff = format_number(instrumentation_results.block_coverage_percent - debug_hook_results.block_coverage_percent)
        
        print(string.format("  Line coverage difference: %+.1f%%", line_diff))
        print(string.format("  Function coverage difference: %+.1f%%", function_diff))
        print(string.format("  Block coverage difference: %+.1f%%", block_diff))
        
        -- Compare execution time
        local time_diff = instrumentation_results.execution_time - debug_hook_results.execution_time
        local time_percent = debug_hook_results.execution_time > 0 
                          and ((instrumentation_results.execution_time / debug_hook_results.execution_time) - 1) * 100
                          or 0
        
        print(string.format("  Execution time difference: %+.4f seconds (%+.1f%%)", 
            time_diff, time_percent))
        
        -- Conclusion
        print("\nConclusion:")
        if math.abs(line_diff) < 1 and math.abs(function_diff) < 1 and math.abs(block_diff) < 1 then
            print("  Both approaches provide similar coverage results.")
        else
            if line_diff > 0 or function_diff > 0 or block_diff > 0 then
                print("  The instrumentation approach provides better coverage in some areas.")
            else
                print("  The debug hook approach provides better coverage in some areas.")
            end
        end
        
        if time_percent > 10 then
            print("  The instrumentation approach is notably slower than the debug hook approach.")
        elseif time_percent < -10 then
            print("  The instrumentation approach is notably faster than the debug hook approach.")
        else
            print("  Both approaches have similar performance characteristics.")
        end
    end)
    
    -- Cleanup after tests
    after(function()
        -- Make sure coverage is stopped
        coverage.stop()
        
        -- Clean up test file
        os.remove(sample_file)
    end)
end)

print("\nRun this example with:")
print("lua test.lua examples/coverage_comparison_example.lua")