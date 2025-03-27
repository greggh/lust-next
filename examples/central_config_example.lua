--[[
  central_config_example.lua
  
  Comprehensive example of the central configuration system in Firmo.
  This example demonstrates best practices for using the centralized
  configuration system for all framework components.
]]

-- Import the required modules
local firmo = require("firmo")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")

-- PART 1: Core Configuration Concepts
print("\n== CENTRAL CONFIGURATION SYSTEM EXAMPLE ==\n")
print("PART 1: Core Configuration Concepts\n")

-- Access the current configuration
local config = central_config.get_config()
print("Current configuration loaded from:", config.__source or "default")

-- Display available configuration options
print("\nSample Configuration Options:")
print("- Coverage patterns:", type(config.coverage.include))
print("- Log level:", config.logging.level)
print("- Report format:", config.reporting.format)

-- PART 2: Configuration File Structure
print("\nPART 2: Configuration File Structure\n")

-- Create a temporary directory for the example
local temp_dir = test_helper.create_temp_test_directory()

-- Create a sample config file
local config_file_content = [[
-- .firmo-config.lua
-- Configuration file for the Firmo testing framework

local config = {
  -- Coverage configuration
  coverage = {
    -- Include pattern (function that returns true if file should be included)
    include = function(file_path)
      -- Include all Lua files in src/ and lib/
      return file_path:match("%.lua$") and (
        file_path:match("^src/") or
        file_path:match("^lib/")
      )
    end,
    
    -- Exclude pattern (function that returns true if file should be excluded)
    exclude = function(file_path)
      -- Exclude test files and vendored code
      return file_path:match("test") or 
             file_path:match("vendor") or
             file_path:match("%.test%.lua$")
    end,
    
    -- Track all executed lines (not just covered ones)
    track_all_executed = true,
    
    -- Report uncovered branches
    track_branches = true
  },
  
  -- Reporting configuration
  reporting = {
    -- Default report format
    format = "html",
    
    -- Output directory for reports
    output_dir = "reports",
    
    -- Report file name template
    file_template = "coverage-report-${timestamp}",
    
    -- Show coverage statistics in console output
    show_stats = true
  },
  
  -- Logging configuration
  logging = {
    -- Global log level (error, warn, info, debug, trace)
    level = "info",
    
    -- Enable output coloring
    colors = true,
    
    -- Module-specific log levels
    modules = {
      ["coverage"] = "warn",
      ["runner"] = "info"
    }
  },
  
  -- Test discovery configuration
  discovery = {
    -- Patterns to include in test discovery
    patterns = {"test_", "_test.lua$", "_spec.lua$"},
    
    -- Directories to search for tests
    directories = {"tests/"},
    
    -- Maximum recursion depth for directory traversal
    max_depth = 10
  },
  
  -- Async testing configuration
  async = {
    -- Default timeout for async tests (in milliseconds)
    default_timeout = 2000,
    
    -- Poll interval for async tests (in milliseconds)
    poll_interval = 10
  }
}

-- Return the configuration
return config
]]

-- Write the config file to the temporary directory
local config_path = temp_dir.path .. "/.firmo-config.lua"
temp_dir.create_file(".firmo-config.lua", config_file_content)

-- Display the configuration file
print("Sample .firmo-config.lua file:")
print(config_file_content:sub(1, 500) .. "...\n")

-- PART 3: Loading Custom Configuration
print("PART 3: Loading Custom Configuration\n")

-- Load configuration from a file
print("Loading configuration from:", config_path)
local custom_config, load_err = central_config.load_config_from_file(config_path)

if not custom_config then
    print("Error loading configuration:", load_err.message)
else
    print("Configuration loaded successfully!")
    
    -- Display some loaded configuration values
    print("\nLoaded configuration values:")
    print("- Reporting format:", custom_config.reporting.format)
    print("- Default async timeout:", custom_config.async.default_timeout, "ms")
    print("- Global log level:", custom_config.logging.level)
    
    -- Test the include/exclude patterns
    local test_paths = {
        "src/calculator.lua",
        "lib/utils/string.lua",
        "tests/calculator_test.lua",
        "lib/vendor/json.lua"
    }
    
    print("\nTesting include/exclude patterns:")
    for _, path in ipairs(test_paths) do
        local included = custom_config.coverage.include(path)
        local excluded = custom_config.coverage.exclude(path)
        local status = included and not excluded and "INCLUDED" or "EXCLUDED"
        print(string.format("- %-25s: %s", path, status))
    end
end

-- PART 4: Programmatic Configuration
print("\nPART 4: Programmatic Configuration\n")

-- Create a new configuration programmatically
local program_config = {
    coverage = {
        include = function(file_path)
            return file_path:match("%.lua$")
        end,
        exclude = function(file_path)
            return file_path:match("test") or file_path:match("examples")
        end,
        track_all_executed = true
    },
    reporting = {
        format = "json",
        output_dir = "coverage-reports"
    },
    logging = {
        level = "warn"
    }
}

-- Apply the configuration programmatically
print("Applying programmatic configuration...")
central_config.apply_config(program_config)

-- Verify the applied configuration
local new_config = central_config.get_config()
print("New configuration applied!")
print("- Reporting format:", new_config.reporting.format)
print("- Output directory:", new_config.reporting.output_dir)
print("- Log level:", new_config.logging.level)

-- PART 5: Environment-Specific Configuration
print("\nPART 5: Environment-Specific Configuration\n")

-- Define environment-specific configurations
local dev_config_content = [[
-- .firmo-config.dev.lua
-- Development environment configuration

local config = {
  logging = {
    level = "debug",
    colors = true
  },
  reporting = {
    format = "html",
    show_stats = true
  },
  discovery = {
    directories = {"tests/"}
  }
}
return config
]]

local ci_config_content = [[
-- .firmo-config.ci.lua
-- CI environment configuration

local config = {
  logging = {
    level = "info",
    colors = false,
    file = "firmo-ci.log"
  },
  reporting = {
    format = "cobertura",
    output_dir = "coverage-reports"
  },
  discovery = {
    directories = {"tests/", "integration-tests/"},
    patterns = {"test_", "_test.lua$"}
  }
}
return config
]]

-- Write the environment-specific configs
temp_dir.create_file(".firmo-config.dev.lua", dev_config_content)
temp_dir.create_file(".firmo-config.ci.lua", ci_config_content)

-- Show the configuration files
print("Environment-specific configuration files:")
print("\n.firmo-config.dev.lua (Development):")
print(dev_config_content)
print("\n.firmo-config.ci.lua (CI):")
print(ci_config_content)

-- Load environment-specific configuration
print("\nLoading environment-specific configuration...")
local env_configs = {
    dev = central_config.load_config_from_file(temp_dir.path .. "/.firmo-config.dev.lua"),
    ci = central_config.load_config_from_file(temp_dir.path .. "/.firmo-config.ci.lua")
}

-- Compare the configurations
print("\nConfiguration comparison:")
print(string.format("%-25s %-15s %-15s", "Option", "Development", "CI"))
print(string.format("%-25s %-15s %-15s", "----------------------", "---------------", "---------------"))
print(string.format("%-25s %-15s %-15s", "Logging level", 
    env_configs.dev.logging.level, 
    env_configs.ci.logging.level))
print(string.format("%-25s %-15s %-15s", "Logging colors", 
    tostring(env_configs.dev.logging.colors), 
    tostring(env_configs.ci.logging.colors)))
print(string.format("%-25s %-15s %-15s", "Reporting format", 
    env_configs.dev.reporting.format, 
    env_configs.ci.reporting.format))

-- PART 6: Using Configuration in Modules
print("\nPART 6: Using Configuration in Modules\n")

-- Example of a module that properly uses central_config
local ExampleModule = {}

function ExampleModule.init()
    -- Always get fresh configuration from central_config
    local config = central_config.get_config()
    
    -- Use configuration values to set up the module
    local log_level = config.logging.level
    local report_format = config.reporting.format
    
    print("ExampleModule initialized with:")
    print("- Log level:", log_level)
    print("- Report format:", report_format)
    
    -- CORRECT: Proper filtering using config patterns
    function ExampleModule.should_process_file(file_path)
        local config = central_config.get_config()
        return config.coverage.include(file_path) and 
               not config.coverage.exclude(file_path)
    end
    
    -- Initialize with configuration
    return true
end

-- Example of proper configuration usage
print("Initializing example module...")
ExampleModule.init()

-- Test the file filtering
local test_files = {
    "src/main.lua",
    "lib/core/util.lua",
    "tests/unit/main_test.lua",
    "lib/vendor/third_party.lua"
}

print("\nFile filtering results:")
for _, file in ipairs(test_files) do
    local should_process = ExampleModule.should_process_file(file)
    print(string.format("- %-25s: %s", file, should_process and "PROCESS" or "SKIP"))
end

-- Part 7: Best Practices and Anti-patterns
print("\nPART 7: Best Practices and Anti-patterns\n")

print("BEST PRACTICES:")
print("✓ Always use central_config to access configuration")
print("✓ Retrieve fresh config in each function that needs it")
print("✓ Use sensible defaults for optional values")
print("✓ Allow configuration for all hard-coded values")
print("✓ Add new options to the central configuration")

print("\nANTI-PATTERNS (NEVER DO THESE):")
print("✗ Never hard-code paths or patterns")
print("  Bad:  if file_path:match('calculator.lua') then")
print("  Good: if config.coverage.include(file_path) then")
print("✗ Never create custom configuration systems")
print("  Bad:  local my_config = { ... }")
print("  Good: local config = central_config.get_config()")
print("✗ Never bypass existing central_config usage")
print("  Bad:  local debug_mode = true")
print("  Good: local debug_mode = config.logging.debug_mode")

-- PART 8: Testing with Firmo
print("\nPART 8: Testing with Firmo\n")

-- Create a simple test
describe("Central Config System", function()
    it("properly loads configuration", function()
        local config = central_config.get_config()
        expect(config).to.exist()
        expect(config.coverage).to.exist()
        expect(config.reporting).to.exist()
    end)
    
    it("provides pattern functions", function()
        local config = central_config.get_config()
        expect(config.coverage.include).to.be.a("function")
        expect(config.coverage.exclude).to.be.a("function")
    end)
    
    it("handles include/exclude patterns correctly", function()
        local config = central_config.get_config()
        
        -- Modify patterns temporarily for testing
        local original_include = config.coverage.include
        local original_exclude = config.coverage.exclude
        
        config.coverage.include = function(path)
            return path:match("%.lua$")
        end
        
        config.coverage.exclude = function(path)
            return path:match("test")
        end
        
        -- Test includes
        expect(config.coverage.include("file.lua")).to.be_truthy()
        expect(config.coverage.include("file.txt")).to_not.be_truthy()
        
        -- Test excludes
        expect(config.coverage.exclude("test_file.lua")).to.be_truthy()
        expect(config.coverage.exclude("main.lua")).to_not.be_truthy()
        
        -- Restore original functions
        config.coverage.include = original_include
        config.coverage.exclude = original_exclude
    end)
end)

print("Run the tests with: lua test.lua examples/central_config_example.lua\n")

-- Cleanup
print("Central configuration example completed successfully.")