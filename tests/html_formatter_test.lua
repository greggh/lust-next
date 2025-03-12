-- Comprehensive tests for the HTML formatter

local lust = require('lust-next')
local describe, it, expect = lust.describe, lust.it, lust.expect
local before, after = lust.before, lust.after
local before_each, after_each = lust.before, lust.after

-- Try to load the logging module
local logging, logger
local function try_load_logger()
  if not logger then
    local ok, log_module = pcall(require, "lib.tools.logging")
    if ok and log_module then
      logging = log_module
      logger = logging.get_logger("test.html_formatter")
      
      if logger and logger.debug then
        logger.debug("HTML formatter test initialized", {
          module = "test.html_formatter",
          test_type = "unit",
          focus = "HTML formatter functionality"
        })
      end
    end
  end
  return logger
end

-- Initialize logger
try_load_logger()

-- Modules to test
local reporting
local html_formatter_module
local html_formatter_fn
local formatters = { coverage = {}, quality = {} }
local validation
local fs = require("lib.tools.filesystem")
local central_config

-- Helper to create a table representation of coverage data
local function create_mock_coverage_data(options)
    options = options or {}
    
    -- Default source code sample
    local source_code = [[
local function example(x, y)
    if x > 10 then
        return x + y
    else
        return x - y
    end
end

local result = example(20, 5)
print("Result:", result)]]

    -- Create mock coverage data with different states
    return {
        files = {
            ["/path/to/test.lua"] = {
                source = options.source or source_code,
                lines = {
                    [1] = true,           -- covered line
                    [2] = 5,              -- covered line with count
                    [3] = true,
                    [4] = options.include_not_covered ~= false and "executed" or true, -- executed but not covered
                    [5] = false,          -- uncovered line
                    [6] = options.include_blocks and {
                        type = "block_end",
                        count = 2,
                        block_type = "if"
                    } or true,
                    [7] = options.include_conditions and {
                        type = "condition",
                        count = 3,
                        true_count = 2,
                        false_count = 1
                    } or true,
                    [8] = true,
                    [9] = 10              -- covered line with count
                },
                functions = {
                    ["example"] = {
                        count = 2,
                        first_line = 1,
                        last_line = 6
                    }
                },
                executable_lines = 9,
                covered_lines = options.include_not_covered ~= false and 7 or 8,
                executed_lines = 8,
                not_covered_lines = options.include_not_covered ~= false and 1 or 0,
                coverage_percentage = options.include_not_covered ~= false and 77.8 or 88.9
            }
        },
        summary = {
            total_lines = 9,
            covered_lines = options.include_not_covered ~= false and 7 or 8,
            executed_lines = 8,
            not_covered_lines = options.include_not_covered ~= false and 1 or 0,
            coverage_percentage = options.include_not_covered ~= false and 77.8 or 88.9,
            total_files = 1,
            covered_files = 1,
            overall_percent = options.include_not_covered ~= false and 77.8 or 88.9,
            total_functions = 1,
            covered_functions = 1
        }
    }
end

-- Helper to extract parts of HTML for easier testing
local function extract_html_part(html, marker_start, marker_end)
    local start_pos = html:find(marker_start, 1, true)
    if not start_pos then return nil end
    
    local end_pos = html:find(marker_end, start_pos, true)
    if not end_pos then return nil end
    
    return html:sub(start_pos, end_pos + #marker_end - 1)
end

describe("HTML Formatter", function()
    -- Setup: Load modules before running tests
    do
        -- Load modules
        reporting = require("lib.reporting")
        
        -- Attempt to load formatter module
        local success, formatter_result
        success, formatter_result = pcall(require, "lib.reporting.formatters.html")
        if success and formatter_result then
            html_formatter_fn = formatter_result
            
            -- Initialize formatters table and register the HTML formatter
            formatters = { coverage = {}, quality = {} }
            html_formatter_fn(formatters)
            
            -- Store reference to the HTML formatter function
            html_formatter_module = formatters.coverage.html
            
            if logger then
                logger.debug("HTML formatter loaded successfully", {
                    html_formatter_fn_type = type(html_formatter_fn),
                    html_formatter_module_type = type(html_formatter_module),
                    formatters_registered = formatters.coverage.html ~= nil
                })
            end
        else
            if logger then
                logger.error("Failed to load HTML formatter", {
                    error = formatter_result
                })
            end
            html_formatter_fn = nil
            html_formatter_module = nil
        end
        
        -- Attempt to load validation and central_config modules
        local success
        success, validation = pcall(require, "lib.reporting.validation")
        if not success then validation = nil end
        
        -- Load modern central_config module instead of deprecated config
        success, central_config = pcall(require, "lib.core.central_config")
        if not success then central_config = nil end
        
        -- Reset formatter configuration to defaults
        if reporting and reporting.configure_formatter then
            reporting.configure_formatter("html", {
                theme = "dark",
                show_line_numbers = true,
                collapsible_sections = true,
                highlight_syntax = true,
                asset_base_path = nil,
                include_legend = true
            })
        end
        
        if logger and logger.info then
            logger.info("HTML formatter test modules loaded", {
                reporting = reporting ~= nil,
                html_formatter = html_formatter ~= nil,
                validation = validation ~= nil,
                central_config = central_config ~= nil
            })
        end
    end
    
    -- Helper to reset configuration between tests
    local function reset_config()
        -- Reset formatter configuration to defaults
        if reporting and reporting.configure_formatter then
            reporting.configure_formatter("html", {
                theme = "dark",
                show_line_numbers = true,
                collapsible_sections = true,
                highlight_syntax = true,
                asset_base_path = nil,
                include_legend = true
            })
        end
        
        -- Reset any central config changes
        if central_config and central_config.set then
            central_config.set("reporting.formatters.html", {
                theme = "dark",
                show_line_numbers = true,
                collapsible_sections = true,
                highlight_syntax = true,
                asset_base_path = nil,
                include_legend = true
            })
        end
    end
    
    it("should exist as a function", function()
        expect(html_formatter_module).to.be.a("function")
    end)
    
    it("should generate basic HTML with correct structure", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Verify basic HTML structure
        expect(html).to.match("<!DOCTYPE html>")
        expect(html).to.match("<html")
        expect(html).to.match("</html>")
        expect(html).to.match("<head>")
        expect(html).to.match("<title>Coverage Report</title>")
        expect(html).to.match("<body")
        
        -- Verify it contains essential sections
        expect(html).to.match("<div class=\"summary\">")
        expect(html).to.match("<div class=\"file%-list\">")
        expect(html).to.match("<div class=\"files\">")
        expect(html).to.match("<div class=\"file\">")
    end)
    
    it("should include coverage summary data", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for summary data
        expect(html).to.match("77%.8%%")  -- Coverage percentage
        expect(html).to.match("7/9")      -- Covered/Total lines
    end)
    
    it("should render source code with line numbers", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for line numbers and source code
        expect(html).to.match("<td class=\"line%-number\">1</td>")
        expect(html).to.match("local function example")
        expect(html).to.match("if x > 10 then")
    end)
    
    it("should visualize different coverage states", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for covered line styling
        expect(html).to.match("<tr class=\"covered\">")
        
        -- Check for executed but not covered line styling
        expect(html).to.match("<tr class=\"executed%-not%-covered\">")
        
        -- Check for uncovered line styling
        expect(html).to.match("<tr class=\"uncovered\">")
    end)
    
    it("should include execution counts in tooltips", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for execution count tooltips
        expect(html).to.match("title=\"Executed 5 times\"")
        expect(html).to.match("title=\"Executed 10 times\"")
    end)
    
    it("should handle block visualization when enabled", function()
        local coverage_data = create_mock_coverage_data({include_blocks = true})
        local html = html_formatter_module(coverage_data)
        
        -- Check for block visualization
        expect(html).to.match("block_type=\"if\"")
        expect(html).to.match("block_count=\"2\"")
    end)
    
    it("should handle condition visualization when enabled", function()
        local coverage_data = create_mock_coverage_data({include_conditions = true})
        local html = html_formatter_module(coverage_data)
        
        -- Check for condition visualization
        expect(html).to.match("condition_true_count=\"2\"")
        expect(html).to.match("condition_false_count=\"1\"")
    end)
    
    it("should include a comprehensive legend", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for legend
        local legend = extract_html_part(html, "<div class=\"legend\">", "</div>")
        expect(legend).not_to.be(nil)
        
        -- Verify legend contains explanations for all states
        expect(legend).to.match("covered")
        expect(legend).to.match("uncovered")
        expect(legend).to.match("executed%-not%-covered")
    end)
    
    it("should include theme toggle functionality", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for theme toggle
        expect(html).to.match("theme%-toggle")
        expect(html).to.match("toggleTheme")
    end)
    
    it("should apply syntax highlighting to source code", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data)
        
        -- Check for syntax highlighting classes
        expect(html).to.match("<span class=\"keyword\">local</span>")
        expect(html).to.match("<span class=\"keyword\">function</span>")
        expect(html).to.match("<span class=\"keyword\">if</span>")
        expect(html).to.match("<span class=\"keyword\">then</span>")
        expect(html).to.match("<span class=\"keyword\">else</span>")
        expect(html).to.match("<span class=\"keyword\">end</span>")
        expect(html).to.match("<span class=\"keyword\">return</span>")
    end)
    
    it("should accept custom title configuration", function()
        local coverage_data = create_mock_coverage_data()
        local html = html_formatter_module(coverage_data, {title = "Custom Report Title"})
        
        -- Check for custom title
        expect(html).to.match("<title>Custom Report Title</title>")
    end)
    
    it("should accept theme configuration", function()
        local coverage_data = create_mock_coverage_data()
        
        -- Test dark theme
        local html_dark = html_formatter_module(coverage_data, {theme = "dark"})
        -- Look for specific substring instead of whole HTML
        local dark_html_part = extract_html_part(html_dark, "<html", ">")
        expect(dark_html_part).to.match("data%-theme=\"dark\"")
        
        -- Test light theme
        local html_light = html_formatter_module(coverage_data, {theme = "light"})
        -- Look for specific substring instead of whole HTML
        local light_html_part = extract_html_part(html_light, "<html", ">")
        expect(light_html_part).to.match("data%-theme=\"light\"")
    end)
    
    it("should format coverage data with minimal required fields", function()
        -- Create minimal coverage data
        local minimal_coverage_data = {
            files = {
                ["/path/to/minimal.lua"] = {
                    source = "print('hello')",
                    lines = {[1] = true},
                    executable_lines = 1,
                    covered_lines = 1,
                    coverage_percentage = 100
                }
            },
            summary = {
                total_lines = 1,
                covered_lines = 1,
                coverage_percentage = 100
            }
        }
        
        local html = html_formatter_module(minimal_coverage_data)
        
        -- Verify it generated valid HTML
        expect(html).to.match("<!DOCTYPE html>")
        expect(html).to.match("<html")
        expect(html).to.match("print%('hello'%)")
        expect(html).to.match("100%%")  -- Coverage percentage
    end)
    
    it("should handle empty coverage data gracefully", function()
        local empty_coverage_data = {
            files = {},
            summary = {
                total_lines = 0,
                covered_lines = 0,
                coverage_percentage = 0
            }
        }
        
        local html = html_formatter_module(empty_coverage_data)
        
        -- Verify it generated valid HTML with appropriate message
        expect(html).to.match("<!DOCTYPE html>")
        expect(html).to.match("<html")
        expect(html).to.match("0%%")  -- Coverage percentage
        expect(html).to.match("No files covered")
    end)
    
    -- Only run validation tests if validation module exists
    if validation then
        it("should integrate with validation results when available", function()
            local coverage_data = create_mock_coverage_data()
            
            -- Add validation issues
            coverage_data.validation_issues = {
                {file = "/path/to/test.lua", line = 4, message = "Line execution count mismatch", severity = "warning"},
                {file = "/path/to/test.lua", line = 7, message = "Condition coverage incomplete", severity = "error"}
            }
            
            local html = html_formatter_module(coverage_data)
            
            -- Check for validation issues display
            expect(html).to.match("validation%-issues")
            expect(html).to.match("Line execution count mismatch")
            expect(html).to.match("Condition coverage incomplete")
            expect(html).to.match("warning")
            expect(html).to.match("error")
        end)
    end
    
    -- Test file saving functionality
    it("should save HTML report to file when specified", function()
        local coverage_data = create_mock_coverage_data()
        
        -- Create a temporary directory for testing
        local temp_dir = os.tmpname()
        os.remove(temp_dir)  -- tmpname creates a file, we need just the name
        
        -- Use the correct filesystem module methods
        if fs.exists and not fs.exists(temp_dir) then
            fs.mkdir(temp_dir)
        end
        
        local file_path = temp_dir .. "/coverage.html"
        
        -- Use formatter to save to file
        html_formatter_module(coverage_data, {output_file = file_path})
        
        -- Verify file exists and contains HTML
        expect(fs.exists(file_path)).to.be(true)
        local content = fs.read_file(file_path)
        expect(content).to.match("<!DOCTYPE html>")
        expect(content).to.match("77%.8%%")  -- Coverage percentage
        
        -- Clean up
        if fs.remove_file then
            fs.remove_file(file_path)
        else
            os.remove(file_path)
        end
        
        if fs.remove_directory then
            fs.remove_directory(temp_dir)
        elseif fs.rmdir then
            fs.rmdir(temp_dir)
        else
            os.remove(temp_dir)
        end
    end)
    
    -- Configuration Tests
    describe("Configuration Options", function()
        it("should respect show_line_numbers configuration", function()
            local coverage_data = create_mock_coverage_data()
            
            -- Test with line numbers
            local html_with_line_numbers = html_formatter_module(coverage_data, {show_line_numbers = true})
            expect(html_with_line_numbers).to.match("<td class=\"line%-number\">")
            
            -- Test without line numbers
            local html_without_line_numbers = html_formatter_module(coverage_data, {show_line_numbers = false})
            expect(html_without_line_numbers).not_to.match("<td class=\"line%-number\">")
        end)
        
        it("should respect highlight_syntax configuration", function()
            local coverage_data = create_mock_coverage_data()
            
            -- Test with syntax highlighting
            local html_with_highlighting = html_formatter_module(coverage_data, {highlight_syntax = true})
            expect(html_with_highlighting).to.match("<span class=\"keyword\">")
            
            -- Test without syntax highlighting
            local html_without_highlighting = html_formatter_module(coverage_data, {highlight_syntax = false})
            expect(html_without_highlighting).not_to.match("<span class=\"keyword\">")
        end)
        
        it("should respect include_legend configuration", function()
            local coverage_data = create_mock_coverage_data()
            
            -- Test with legend
            local html_with_legend = html_formatter_module(coverage_data, {include_legend = true})
            expect(html_with_legend).to.match("<div class=\"legend\">")
            
            -- Test without legend
            local html_without_legend = html_formatter_module(coverage_data, {include_legend = false})
            expect(html_without_legend).not_to.match("<div class=\"legend\">")
        end)
        
        it("should respect collapsible_sections configuration", function()
            local coverage_data = create_mock_coverage_data()
            
            -- Test with collapsible sections
            local html_with_collapsible = html_formatter_module(coverage_data, {collapsible_sections = true})
            expect(html_with_collapsible).to.match("collapsible")
            
            -- Test without collapsible sections
            local html_without_collapsible = html_formatter_module(coverage_data, {collapsible_sections = false})
            expect(html_without_collapsible).not_to.match("collapsible")
        end)
        
        -- Test configuration via reporting module
        if reporting and reporting.configure_formatter then
            it("should respect reporting.configure_formatter settings", function()
                local coverage_data = create_mock_coverage_data()
                
                -- Configure formatter via reporting module
                reporting.configure_formatter("html", {theme = "light", highlight_syntax = false})
                
                -- Generate HTML and verify configuration was applied
                local html = html_formatter_module(coverage_data)
                expect(html).to.match("data%-theme=\"light\"")
                expect(html).not_to.match("<span class=\"keyword\">")
                
                -- Reset configuration
                reporting.configure_formatter("html", {theme = "dark", highlight_syntax = true})
            end)
        end
        
        -- Test configuration via central_config
        if central_config and central_config.set then
            it("should respect central_config settings", function()
                local coverage_data = create_mock_coverage_data()
                
                -- Configure via central_config
                central_config.set("reporting.formatters.html.theme", "light")
                central_config.set("reporting.formatters.html.include_legend", false)
                
                -- Generate HTML and verify configuration was applied
                local html = html_formatter_module(coverage_data)
                expect(html).to.match("data%-theme=\"light\"")
                expect(html).not_to.match("<div class=\"legend\">")
                
                -- Reset configuration
                central_config.set("reporting.formatters.html.theme", "dark")
                central_config.set("reporting.formatters.html.include_legend", true)
            end)
            
            it("should prioritize direct options over central_config", function()
                local coverage_data = create_mock_coverage_data()
                
                -- Set config in central_config
                central_config.set("reporting.formatters.html.theme", "light")
                
                -- Generate HTML with direct options that override central_config
                local html = html_formatter_module(coverage_data, {theme = "dark"})
                
                -- Verify direct options took precedence
                expect(html).to.match("data%-theme=\"dark\"")
                
                -- Reset configuration
                central_config.set("reporting.formatters.html.theme", "dark")
            end)
        end
    end)
    
    if logger then
        logger.info("HTML formatter tests completed", {
            status = "success",
            test_group = "html_formatter"
        })
    end
end)

-- Tests are run by run_all_tests.lua or scripts/runner.lua
-- No need to call lust() explicitly here