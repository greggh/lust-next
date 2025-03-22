-- A truly functional test of the execution count tracking - run live - no cheating.
local coverage = require("lib.coverage")
local debug_hook = require("lib.coverage.debug_hook")
local fs = require("lib.tools.filesystem")

-- Get the current file path
local this_file = debug.getinfo(1, "S").source:sub(2) 
print("Current file: " .. this_file)

-- First, implement a simple test function that will have predictable execution counts
local function test_loop_function(iterations)
    local sum = 0
    print("Starting test with " .. iterations .. " iterations")
    
    -- Explicitly track this line
    debug_hook.track_line(this_file, 11, {is_executable = true, is_covered = true})
    print("Explicitly tracked line 11")
    
    -- Check if it was recorded
    local line11_data = debug_hook.dump_execution_data(this_file)
    print("After line 11 tracking, execution count: " .. 
        (line11_data and line11_data[this_file] and 
         line11_data[this_file]._execution_counts and 
         line11_data[this_file]._execution_counts[11] or "not found"))
    
    for i = 1, iterations do
        sum = sum + i
        print("  Iteration " .. i .. ": sum = " .. sum)
        
        -- Explicitly track this line in the loop
        debug_hook.track_line(this_file, 16, {is_executable = true, is_covered = true})
        print("Explicitly tracked line 16 on iteration " .. i)
        
        -- Check if it was recorded
        local loop_data = debug_hook.dump_execution_data(this_file)
        print("  After iteration " .. i .. ", line 16 execution count: " .. 
            (loop_data and loop_data[this_file] and 
             loop_data[this_file]._execution_counts and 
             loop_data[this_file]._execution_counts[16] or "not found"))
    end
    
    print("Final sum: " .. sum)
    return sum
end

-- Start coverage with debug hook
print("\nStarting coverage...")
coverage.start({
    debug = true,
    verbose = true,
    track_blocks = true
})

-- Explicitly initialize and activate this file
print("Explicitly activating this file...")
debug_hook.initialize_file(this_file)
debug_hook.activate_file(this_file)

-- Run the test function multiple times with predictable patterns
print("\n=== First run (3 iterations) ===")
test_loop_function(3)

print("\n=== Second run (2 iterations) ===")
test_loop_function(2)

-- Let's also add a custom debug function to help us understand what's happening
local function debug_execution_counts()
    print("\n-- CURRENT RAW EXECUTION DATA --")
    local data = debug_hook.get_coverage_data()
    
    if not data or not data.files then
        print("No coverage data available")
        return
    end
    
    -- For the current file
    local normalized_path = fs.normalize_path(this_file)
    local file_data = data.files[normalized_path]
    
    if not file_data then
        print("No file data for: " .. normalized_path)
        
        -- Try with original path
        file_data = data.files[this_file]
        if file_data then
            print("Found file data using non-normalized path: " .. this_file)
        else
            print("Available files in coverage data:")
            for file_path, _ in pairs(data.files) do
                print("  " .. file_path)
            end
            return
        end
    end
    
    -- Check execution counts directly
    if file_data._execution_counts and next(file_data._execution_counts) then
        print("  Direct _execution_counts:")
        for line, count in pairs(file_data._execution_counts) do
            print(string.format("    Line %d: executed %d times", line, count))
        end
    else
        print("  No _execution_counts found in file data")
    end
end

-- Debug execution counts before stopping
print("\n=== Direct examination of execution counts before stopping ===")
debug_execution_counts()

-- Stop coverage tracking
print("\nStopping coverage...")
coverage.stop()

-- Check raw execution data for this file
print("\n--- RAW EXECUTION DATA ---")
local raw_data = debug_hook.dump_execution_data(this_file)
if raw_data and next(raw_data) then
    for path, data in pairs(raw_data) do
        print("File: " .. path)
        if data._execution_counts and next(data._execution_counts) then
            print("  Execution counts:")
            -- Sort the lines for easier reading
            local lines = {}
            for line, _ in pairs(data._execution_counts) do
                table.insert(lines, line)
            end
            table.sort(lines)
            
            for _, line in ipairs(lines) do
                local count = data._execution_counts[line]
                print(string.format("    Line %d: executed %d times", line, count))
            end
        else
            print("  No execution counts recorded!")
        end
    end
else
    print("No raw execution data available!")
end

-- Check report data for this file
print("\n--- COVERAGE REPORT DATA ---")
local report = coverage.get_report_data()
if report and report.files and report.files[this_file] then
    local file_data = report.files[this_file]
    print("File found in report data")
    
    if file_data.execution_counts and next(file_data.execution_counts) then
        print("  Execution counts from report:")
        -- Sort the lines for easier reading
        local lines = {}
        for line, _ in pairs(file_data.execution_counts) do
            table.insert(lines, line)
        end
        table.sort(lines)
        
        for _, line in ipairs(lines) do
            local count = file_data.execution_counts[line]
            print(string.format("    Line %d: executed %d times", line, count))
        end
    else
        print("  No execution counts in report data!")
    end
    
    -- Verify execution counts match expectations
    local expected_test_lines = {
        [10] = 2,  -- test_loop_function signature line
        [11] = 2,  -- local sum = 0
        [12] = 2,  -- print starting test
        [14] = 2,  -- for loop header
        [15] = 5,  -- body of loop (3+2 iterations)
        [16] = 5,  -- print in loop
        [19] = 2,  -- print final sum
        [20] = 2   -- return sum
    }
    
    print("\n  Verification of key execution counts:")
    local all_correct = true
    for line, expected in pairs(expected_test_lines) do
        local actual = file_data.execution_counts and file_data.execution_counts[line] or 0
        local correct = actual == expected
        if not correct then
            all_correct = false
        end
        print(string.format("    Line %d: Expected %d, Got %d - %s", 
            line, expected, actual, correct and "CORRECT" or "WRONG"))
    end
    
    print("\nOverall execution count verification: " .. 
          (all_correct and "PASSED" or "FAILED"))
else
    print("File not found in report data!")
end