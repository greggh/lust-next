-- Tests for the fallback_heuristic_analysis function
local firmo = require("firmo")
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")
local logging = require("lib.tools.logging")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Initialize logger with error handling
local logger
local logger_init_success, logger_init_error = pcall(function()
    logger = logging.get_logger("fallback_heuristic_analysis_test")
    return true
end)

if not logger_init_success then
    print("Warning: Failed to initialize logger: " .. tostring(logger_init_error))
    -- Create a minimal logger as fallback
    logger = {
        debug = function() end,
        info = function() end,
        warn = function(msg) print("WARN: " .. msg) end,
        error = function(msg) print("ERROR: " .. msg) end
    }
end

describe("fallback_heuristic_analysis", function()
    -- No need to track or clean up files manually with the new temp_file system
    
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
        
        -- Create a temporary file with error handling
        local file_path, create_error = temp_file.create_with_content(test_code, "lua")
        expect(create_error).to_not.exist("Failed to create test file: " .. tostring(create_error))
        expect(file_path).to.exist()
        
        -- Initialize coverage with static analysis disabled to force fallback
        local init_success, init_error = test_helper.with_error_capture(function()
            return coverage.init({
                enabled = true,
                use_static_analysis = false  -- Force fallback heuristic analysis
            })
        end)()
        
        expect(init_error).to_not.exist("Failed to initialize coverage: " .. tostring(init_error))
        
        -- Reset coverage data with error handling
        local reset_success, reset_error = test_helper.with_error_capture(function()
            return coverage.reset()
        end)()
        
        expect(reset_error).to_not.exist("Failed to reset coverage: " .. tostring(reset_error))
        
        -- Start coverage with error handling
        local start_success, start_error = test_helper.with_error_capture(function()
            return coverage.start()
        end)()
        
        expect(start_error).to_not.exist("Failed to start coverage: " .. tostring(start_error))
        
        -- Explicitly track the test file with error handling
        local track_success, track_error = test_helper.with_error_capture(function()
            return coverage.track_file(file_path)
        end)()
        
        expect(track_error).to_not.exist("Failed to track file: " .. tostring(track_error))
        
        -- Load and execute the file with error handling
        local load_success, load_result, load_error = pcall(function()
            return loadfile(file_path)
        end)
        
        expect(load_success).to.be_truthy("Failed to load file: " .. tostring(load_result))
        expect(load_result).to.exist()
        
        -- Execute the loaded file with error handling
        local exec_success, exec_result = pcall(load_result)
        expect(exec_success).to.be_truthy("Failed to execute file: " .. tostring(exec_result))
        
        -- Stop coverage with error handling
        local stop_success, stop_error = test_helper.with_error_capture(function()
            return coverage.stop()
        end)()
        
        expect(stop_error).to_not.exist("Failed to stop coverage: " .. tostring(stop_error))
        
        -- Check the result from the code execution
        expect(exec_result).to.equal("test")
        
        -- Get coverage report with error handling
        local report_data, report_error = test_helper.with_error_capture(function()
            return coverage.get_report_data()
        end)()
        
        expect(report_error).to_not.exist("Failed to get coverage report: " .. tostring(report_error))
        expect(report_data).to.exist()
        
        -- Normalize the file path for comparison
        local normalized_path = fs.normalize_path(file_path)
        
        -- Verify that the file was tracked
        expect(report_data.files[normalized_path]).to.exist()
    end)
    
    -- Test error handling for invalid files
    it("should handle errors when given an invalid file path", { expect_error = true }, function()
        -- Initialize coverage with error handling
        local init_success, init_error = test_helper.with_error_capture(function()
            return coverage.init({
                enabled = true,
                use_static_analysis = false
            })
        end)()
        
        expect(init_error).to_not.exist("Failed to initialize coverage")
        
        -- Reset and start coverage with error handling
        local reset_success, reset_error = test_helper.with_error_capture(function()
            return coverage.reset()
        end)()
        
        expect(reset_error).to_not.exist("Failed to reset coverage")
        
        local start_success, start_error = test_helper.with_error_capture(function()
            return coverage.start()
        end)()
        
        expect(start_error).to_not.exist("Failed to start coverage")
        
        -- Try to track a non-existent file
        local non_existent_file = "/non/existent/file/path.lua"
        local result, err = test_helper.with_error_capture(function()
            return coverage.track_file(non_existent_file)
        end)()
        
        -- The API might return false or nil+error, handle both cases
        if result == nil then
            -- Nil+error pattern
            expect(err).to.exist()
            expect(err.message).to.match("file")  -- Should mention file in error
        else
            -- False return pattern
            expect(result).to.equal(false)
        end
        
        -- Stop coverage with error handling
        local stop_success, stop_error = test_helper.with_error_capture(function()
            return coverage.stop()
        end)()
        
        expect(stop_error).to_not.exist("Failed to stop coverage")
    end)
end)

-- Tests are run by run_all_tests.lua, no need to call firmo() explicitly
-- The framework handles running these tests when loaded
