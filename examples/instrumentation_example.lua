-- Instrumentation approach example for firmo coverage
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local firmo = require("firmo")
local logging = require("lib.tools.logging")
local logger = logging.get_logger("example.instrumentation")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Instrumentation approach for coverage", function()
    -- Create variables to hold test file paths and content
    local temp_dir, sample_file, sample_module

    -- Setup - runs before all tests in this block
    before(function()
        -- Create a sample file to test instrumentation
        temp_dir = os.tmpname():gsub("([^/]+)$", "")
        sample_file = temp_dir .. "/instrumentation_test.lua"

        -- Write sample code to test file
        local sample_code = [[
-- This is a sample file for testing instrumentation

-- Define a simple function that we'll test
local function add(a, b)
    -- Simple addition function
    return a + b
end

-- Define a function with conditional logic
local function calculate(a, b, operation)
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

-- This function will remain uncovered
local function uncovered_function()
    print("This function won't be called")
    return true
end

-- Return public interface
return {
    add = add,
    calculate = calculate,
    uncovered_function = uncovered_function
}
]]

        logger.info("Creating test file for instrumentation", {
            path = sample_file
        })
        fs.write_file(sample_file, sample_code)

        -- Initialize coverage with instrumentation mode
        coverage.init({
            enabled = true,
            use_instrumentation = true,     -- Use instrumentation approach
            instrument_on_load = true,      -- Instrument files when loaded
            use_static_analysis = true,     -- Use static analysis for better instrumentation
            track_blocks = true,            -- Track code blocks
            cache_instrumented_files = true, -- Cache instrumented files
            sourcemap_enabled = true,       -- Enable sourcemap for better error reporting
            use_static_imports = true       -- Use static imports for better module handling
        })

        -- Start coverage tracking
        coverage.start()
        
        -- Load the instrumented module once for all tests
        local loadFunc = loadfile(sample_file)
        if loadFunc then
            sample_module = loadFunc()
        else
            logger.error("Failed to load sample file", {
                path = sample_file
            })
        end
    end)

    it("should instrument and track coverage using the instrumentation approach", function()
        if not sample_module then
            logger.warn("Test skipped - sample module not loaded")
            return
        end
        
        -- Execute some code to generate coverage
        expect(sample_module.add(2, 3)).to.equal(5)
        expect(sample_module.calculate(10, 5, "add")).to.equal(15)
        expect(sample_module.calculate(10, 5, "subtract")).to.equal(5)
        expect(sample_module.calculate(10, 5, "multiply")).to.equal(50)
        expect(sample_module.calculate(10, 5, "divide")).to.equal(2)
        
        -- Note: uncovered_function is deliberately not called
    end)
    
    it("should compare debug hook and instrumentation approaches", function()
        -- This is just for demonstration in the example
        -- In a real test, we would run the same code with both approaches
        -- and compare the results
        
        logger.info("Instrumentation approach details:")
        -- Display coverage info - only call if available
        if coverage.debug_dump then
            coverage.debug_dump()
        else
            logger.info("Coverage debug_dump not available")
        end
    end)
    
    -- Cleanup after all tests in this block
    after(function()
        -- Stop coverage tracking
        coverage.stop()
        
        -- Generate coverage report
        local report = coverage.report("summary")
        logger.info("Coverage report (summary):", {
            report = report
        })
        
        -- Clean up test file
        logger.debug("Cleaning up test file", {
            path = sample_file
        })
        os.remove(sample_file)
    end)
end)

describe("Module lifecycle hooks", function()
    local test_module_path
    local old_package_path

    before(function()
        -- Save original package path
        old_package_path = package.path
        
        -- Create test directory if needed
        local test_dir = "./test_modules"
        if not fs.directory_exists(test_dir) then
            fs.create_directory(test_dir)
        end
        
        -- Create a test module
        test_module_path = "./test_modules/test_hooks_module.lua"
        local module_content = [[
-- Test module for instrumentation lifecycle hooks
local M = {}

function M.greet(name)
    return "Hello, " .. name .. "!"
end

function M.calculate_area(length, width)
    return length * width
end

return M
]]
        
        logger.info("Creating test module for lifecycle hooks", {
            path = test_module_path
        })
        fs.write_file(test_module_path, module_content)
        
        -- Add test directory to package path
        package.path = "./test_modules/?.lua;" .. package.path
        
        -- Configure coverage with lifecycle hooks
        coverage.init({
            enabled = true,
            use_instrumentation = true,
            use_static_imports = true,  -- Use static imports for better module handling
            on_module_load = function(module_name, module_path)
                logger.info("Module loaded through instrumentation", {
                    module = module_name,
                    path = module_path
                })
            end,
            on_file_instrumented = function(file_path, executable_lines)
                logger.info("File instrumented", {
                    path = file_path,
                    executable_lines = executable_lines
                })
            end
        })
        
        coverage.start()
    end)
    
    it("should trigger lifecycle hooks during module loading", function()
        -- Require the module (should trigger hooks)
        local module = require("test_hooks_module")
        
        -- Test module functionality
        expect(module.greet("World")).to.equal("Hello, World!")
        expect(module.calculate_area(5, 4)).to.equal(20)
    end)
    
    after(function()
        -- Stop coverage
        coverage.stop()
        
        -- Clean up
        if fs.file_exists(test_module_path) then
            fs.delete_file(test_module_path)
        end
        
        -- Remove test directory if empty
        if fs.directory_exists("./test_modules") and #fs.get_directory_contents("./test_modules") == 0 then
            fs.delete_directory("./test_modules")
        end
        
        -- Restore package path
        package.path = old_package_path
    end)
end)

-- Note: Run this example using the standard test runner:
-- lua test.lua examples/instrumentation_example.lua
