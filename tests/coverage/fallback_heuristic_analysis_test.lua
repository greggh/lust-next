-- Tests for the fallback_heuristic_analysis function
local lust = require("lust-next")
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")

local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after

-- Test helper functions
local function create_test_file(content)
    local temp_dir = os.tmpname():gsub("([^/]+)$", "")
    local test_file = temp_dir .. "/fallback_test_" .. os.time() .. ".lua"
    fs.write_file(test_file, content)
    return test_file
end

local function cleanup_test_file(file_path)
    os.remove(file_path)
end

describe("fallback_heuristic_analysis", function()
    -- Test basic file analysis
    it("should analyze a file with basic heuristics when static analysis is disabled", function()
        -- Create a simple test file without actual requires
        local test_code = [[
            -- Import section (commented out to avoid errors)
            -- These are just for the heuristic analysis to detect
            local a = "module1" -- require("module1")
            local b = "module2" -- require("module2")
            
            -- Function definition
            local function test_function()
                return "test"
            end
            
            -- Return value
            return test_function()
        ]]
        
        local file_path = create_test_file(test_code)
        
        -- Initialize coverage with static analysis disabled to force fallback
        coverage.init({
            enabled = true,
            use_static_analysis = false  -- Force fallback heuristic analysis
        })
        
        -- Reset coverage data
        coverage.reset()
        
        -- Start coverage and load the module
        coverage.start()
        
        -- Explicitly track the test file
        coverage.track_file(file_path)
        
        local result = loadfile(file_path)()
        coverage.stop()
        
        -- Check the result from the code execution
        expect(result).to.equal("test")
        
        -- Get coverage report
        local report_data = coverage.get_report_data()
        
        -- Normalize the file path for comparison
        local normalized_path = fs.normalize_path(file_path)
        
        -- Verify that the file was tracked
        expect(report_data.files[normalized_path]).to.exist()
        
        -- Cleanup
        cleanup_test_file(file_path)
    end)
end)

-- Tests are run by run_all_tests.lua, no need to call lust() explicitly
-- The framework handles running these tests when loaded