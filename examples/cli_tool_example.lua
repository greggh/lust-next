--[[
  cli_tool_example.lua
  
  Comprehensive example of building command-line tools with Firmo.
  This example demonstrates creating a rich CLI application with
  argument parsing, subcommands, and proper error handling.
]]

-- Import required modules
local firmo = require("firmo")
local cli = require("lib.tools.cli")
local error_handler = require("lib.tools.error_handler")
local central_config = require("lib.core.central_config")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Configure logging
local logger = logging.get_logger("CLI-Example")
logging.configure({level = "info"})

print("\n== CLI TOOL EXAMPLE ==\n")
print("PART 1: Basic CLI Structure\n")

-- Example 1: Creating a CLI Application
print("Example 1: Creating a CLI Application")

-- Create a SimpleTestRunner CLI tool
local TestRunnerCLI = {}

-- Initialize the CLI tool
function TestRunnerCLI.init()
    -- Define the main command
    TestRunnerCLI.command = cli.create_command({
        name = "test-runner",
        description = "Simple test runner CLI tool",
        version = "1.0.0",
        
        -- Define command-line arguments
        arguments = {
            {
                name = "path",
                description = "Path to test file or directory",
                type = "string",
                required = false
            }
        },
        
        -- Define command-line options
        options = {
            {
                name = "verbose",
                short = "v",
                description = "Enable verbose output",
                type = "boolean",
                default = false
            },
            {
                name = "pattern",
                short = "p",
                description = "Only run tests matching pattern",
                type = "string"
            },
            {
                name = "coverage",
                short = "c",
                description = "Enable code coverage",
                type = "boolean",
                default = false
            },
            {
                name = "format",
                short = "f",
                description = "Output format (text, json, html)",
                type = "string",
                default = "text",
                choices = {"text", "json", "html"}
            },
            {
                name = "output",
                short = "o",
                description = "Output file path",
                type = "string"
            }
        },
        
        -- Define the command handler
        handler = function(args, options)
            print("\nTest Runner CLI")
            print("Command: test-runner")
            
            -- Display parsed arguments
            print("\nArguments:")
            print("  path:", args.path or "(default: current directory)")
            
            -- Display parsed options
            print("\nOptions:")
            print("  verbose:", options.verbose)
            print("  pattern:", options.pattern or "(not specified)")
            print("  coverage:", options.coverage)
            print("  format:", options.format)
            print("  output:", options.output or "(console output)")
            
            -- In a real CLI tool, we would run the tests here
            print("\nRunning tests...")
            print("Test execution complete!")
            
            return 0 -- Exit code
        end
    })
    
    return TestRunnerCLI.command
end

-- Display the command structure
local test_runner = TestRunnerCLI.init()
print("Command Name:", test_runner.name)
print("Description:", test_runner.description)
print("Version:", test_runner.version)

print("\nArguments:")
for _, arg in ipairs(test_runner.arguments) do
    print(string.format("  %-10s %-20s %-10s %s", 
        arg.name, 
        "(" .. arg.type .. ")", 
        arg.required and "Required" or "Optional",
        arg.description))
end

print("\nOptions:")
for _, opt in ipairs(test_runner.options) do
    local default = ""
    if opt.default ~= nil then
        default = " (default: " .. tostring(opt.default) .. ")"
    end
    
    print(string.format("  --%s, -%s %-15s %s%s", 
        opt.name, 
        opt.short or " ", 
        "(" .. opt.type .. ")", 
        opt.description,
        default))
end

-- Example 2: Parsing Command-Line Arguments
print("\nExample 2: Parsing Command-Line Arguments")

---@param args string[] Command-line arguments to parse and execute
---@return number exit_code The exit code from the command execution
function TestRunnerCLI.parse_and_run(args)
    -- Parse the arguments
    local parsed_args, parsed_options, err = cli.parse_args(test_runner, args)
    
    if err then
        print("Error parsing arguments:", err.message)
        return 1 -- Error exit code
    end
    
    -- Call the command handler
    return test_runner.handler(parsed_args, parsed_options)
end

-- Test with different argument sets
local test_args = {
    { "tests/unit", "--verbose", "--coverage" },
    { "tests/integration", "-v", "-c", "-f", "json", "-o", "results.json" },
    { "--pattern", "user_*", "--format", "html" }
}

print("\nTest Runs:")
for i, args in ipairs(test_args) do
    print("\nTest Run " .. i .. ":")
    print("Arguments:", table.concat(args, " "))
    
    local exit_code = TestRunnerCLI.parse_and_run(args)
    print("Exit code:", exit_code)
end

-- PART 2: Subcommands
print("\nPART 2: Subcommands\n")

-- Example 3: Creating CLI with Subcommands
print("Example 3: Creating CLI with Subcommands")

-- Create a more complex CLI with subcommands
local ComplexCLI = {}

-- Create the main command
function ComplexCLI.init()
    -- Define the root command
    ComplexCLI.command = cli.create_command({
        name = "firmo-cli",
        description = "Firmo Testing Framework CLI",
        version = "2.0.0",
        
        -- Global options (available to all subcommands)
        options = {
            {
                name = "verbose",
                short = "v",
                description = "Enable verbose output",
                type = "boolean",
                default = false
            },
            {
                name = "config",
                short = "c",
                description = "Path to configuration file",
                type = "string"
            }
        },
        
        -- Main command handler (default when no subcommand is specified)
        handler = function(args, options)
            print("Firmo CLI Tool")
            print("Use --help to see available commands")
            return 0
        end
    })
    
    -- Add subcommands
    cli.add_subcommand(ComplexCLI.command, {
        name = "run",
        description = "Run tests",
        arguments = {
            {
                name = "path",
                description = "Path to test file or directory",
                type = "string",
                required = false
            }
        },
        options = {
            {
                name = "pattern",
                short = "p",
                description = "Only run tests matching pattern",
                type = "string"
            },
            {
                name = "coverage",
                description = "Enable code coverage",
                type = "boolean",
                default = false
            }
        },
        handler = function(args, options, parent_options)
            print("\nRunning Tests")
            print("Command: firmo-cli run")
            
            -- Display arguments and options
            print("\nArguments:")
            print("  path:", args.path or "(default: current directory)")
            
            print("\nOptions:")
            print("  pattern:", options.pattern or "(not specified)")
            print("  coverage:", options.coverage)
            
            -- Display parent options
            print("\nGlobal Options:")
            print("  verbose:", parent_options.verbose)
            print("  config:", parent_options.config or "(default config)")
            
            return 0
        end
    })
    
    cli.add_subcommand(ComplexCLI.command, {
        name = "report",
        description = "Generate test reports",
        options = {
            {
                name = "format",
                short = "f",
                description = "Report format (html, json, xml, text)",
                type = "string",
                default = "html",
                choices = {"html", "json", "xml", "text"}
            },
            {
                name = "output",
                short = "o",
                description = "Output directory",
                type = "string",
                default = "reports"
            }
        },
        handler = function(args, options, parent_options)
            print("\nGenerating Reports")
            print("Command: firmo-cli report")
            
            print("\nOptions:")
            print("  format:", options.format)
            print("  output:", options.output)
            
            -- Display parent options
            print("\nGlobal Options:")
            print("  verbose:", parent_options.verbose)
            print("  config:", parent_options.config or "(default config)")
            
            return 0
        end
    })
    
    cli.add_subcommand(ComplexCLI.command, {
        name = "init",
        description = "Initialize a new test project",
        arguments = {
            {
                name = "directory",
                description = "Target directory",
                type = "string",
                required = true
            }
        },
        options = {
            {
                name = "template",
                short = "t",
                description = "Project template (basic, full)",
                type = "string",
                default = "basic",
                choices = {"basic", "full"}
            }
        },
        handler = function(args, options, parent_options)
            print("\nInitializing Project")
            print("Command: firmo-cli init")
            
            print("\nArguments:")
            print("  directory:", args.directory)
            
            print("\nOptions:")
            print("  template:", options.template)
            
            -- Display parent options
            print("\nGlobal Options:")
            print("  verbose:", parent_options.verbose)
            print("  config:", parent_options.config or "(default config)")
            
            return 0
        end
    })
    
    return ComplexCLI.command
end

-- Display the command hierarchy
local complex_cli = ComplexCLI.init()
print("Main Command:", complex_cli.name)
print("Description:", complex_cli.description)
print("Version:", complex_cli.version)

print("\nGlobal Options:")
for _, opt in ipairs(complex_cli.options) do
    print(string.format("  --%s, -%s  %s", 
        opt.name, opt.short or " ", opt.description))
end

print("\nSubcommands:")
for _, subcmd in ipairs(complex_cli.subcommands) do
    print(string.format("  %-10s  %s", subcmd.name, subcmd.description))
end

-- Example 4: Running Subcommands
print("\nExample 4: Running Subcommands")

---@param args string[] Command-line arguments to parse and execute
---@return number exit_code The exit code from the command execution
function ComplexCLI.parse_and_run(args)
    -- Parse the arguments
    local result = cli.execute_command(complex_cli, args)
    return result.exit_code or 0
end

-- Test with different subcommands
local subcommand_tests = {
    { "run", "tests/unit", "--pattern", "user_*", "--verbose" },
    { "report", "--format", "json", "--output", "custom-reports" },
    { "init", "new-project", "--template", "full", "--config", "custom-config.lua" }
}

print("\nSubcommand Tests:")
for i, args in ipairs(subcommand_tests) do
    print("\nTest " .. i .. ":")
    print("Command:", "firmo-cli", table.concat(args, " "))
    
    local exit_code = ComplexCLI.parse_and_run(args)
    print("Exit code:", exit_code)
end

-- PART 3: Help Text and Documentation
print("\nPART 3: Help Text and Documentation\n")

-- Example 5: Generating Help Text
print("Example 5: Generating Help Text")

---@param command table The CLI command object to generate help text for
---@param subcommand_name? string Optional name of a subcommand to generate help for
---@return string The formatted help text
function ComplexCLI.generate_help(command, subcommand_name)
    local cmd = command
    
    -- If subcommand is specified, find it
    if subcommand_name then
        for _, subcmd in ipairs(command.subcommands or {}) do
            if subcmd.name == subcommand_name then
                cmd = subcmd
                break
            end
        end
    end
    
    -- Generate help header
    local help = "\nUsage: " .. (cmd.parent and (cmd.parent.name .. " ") or "") .. cmd.name
    
    -- Add arguments to usage
    if cmd.arguments and #cmd.arguments > 0 then
        for _, arg in ipairs(cmd.arguments) do
            local arg_str = " <" .. arg.name .. ">"
            if not arg.required then
                arg_str = " [" .. arg.name .. "]"
            end
            help = help .. arg_str
        end
    end
    
    -- Add options to usage
    if cmd.options and #cmd.options > 0 then
        help = help .. " [options]"
    end
    
    -- Add subcommands to usage
    if cmd.subcommands and #cmd.subcommands > 0 then
        help = help .. " [command]"
    end
    
    -- Add description
    help = help .. "\n\n" .. (cmd.description or "")
    
    -- Add version if available
    if cmd.version then
        help = help .. "\nVersion: " .. cmd.version
    end
    
    -- Add arguments section
    if cmd.arguments and #cmd.arguments > 0 then
        help = help .. "\n\nArguments:"
        for _, arg in ipairs(cmd.arguments) do
            local required = arg.required and " (Required)" or ""
            help = help .. string.format("\n  %-15s %s%s", 
                arg.name, arg.description or "", required)
        end
    end
    
    -- Add options section
    if cmd.options and #cmd.options > 0 then
        help = help .. "\n\nOptions:"
        for _, opt in ipairs(cmd.options) do
            local option_name = "--" .. opt.name
            if opt.short then
                option_name = "-" .. opt.short .. ", " .. option_name
            end
            
            local default = ""
            if opt.default ~= nil then
                default = " (default: " .. tostring(opt.default) .. ")"
            end
            
            help = help .. string.format("\n  %-20s %s%s", 
                option_name, opt.description or "", default)
        end
    end
    
    -- Add subcommands section
    if cmd.subcommands and #cmd.subcommands > 0 then
        help = help .. "\n\nCommands:"
        for _, subcmd in ipairs(cmd.subcommands) do
            help = help .. string.format("\n  %-15s %s", 
                subcmd.name, subcmd.description or "")
        end
        
        help = help .. "\n\nRun '" .. command.name .. " [command] --help' for more information on a command."
    end
    
    return help
end

-- Display help for main command and subcommands
print("\nMain Command Help:")
print(ComplexCLI.generate_help(complex_cli))

print("\nRun Subcommand Help:")
print(ComplexCLI.generate_help(complex_cli, "run"))

-- Example 6: Handling Help and Version Flags
print("\nExample 6: Handling Help and Version Flags")

---@param command table The CLI command object
---@param args string[] Command-line arguments to check for help or version flags
---@return boolean handled True if help or version flag was detected and handled
function ComplexCLI.handle_help_version(command, args)
    -- Check for --help flag
    if table.concat(args, " "):match("%-%-help") or table.concat(args, " "):match("%-h%s") then
        -- Find the correct command to show help for
        local cmd = command
        local subcommand_name
        
        for i, arg in ipairs(args) do
            if not arg:match("^%-") and i == 1 then
                subcommand_name = arg
                break
            end
        end
        
        print(ComplexCLI.generate_help(cmd, subcommand_name))
        return true
    end
    
    -- Check for --version flag
    if table.concat(args, " "):match("%-%-version") or table.concat(args, " "):match("%-V%s") then
        print(command.name .. " version " .. (command.version or "unknown"))
        return true
    end
    
    return false
end

-- Test help and version handling
local help_version_tests = {
    { "--help" },
    { "run", "--help" },
    { "--version" }
}

print("\nHelp and Version Tests:")
for i, args in ipairs(help_version_tests) do
    print("\nTest " .. i .. ":")
    print("Command:", "firmo-cli", table.concat(args, " "))
    
    local handled = ComplexCLI.handle_help_version(complex_cli, args)
    print("Handled by help/version:", handled)
end

-- PART 4: Error Handling
print("\nPART 4: Error Handling\n")

-- Example 7: Validation and Error Handling
print("Example 7: Validation and Error Handling")

---@param command table The CLI command object
---@param args table Parsed command arguments
---@param options table Parsed command options
---@return boolean valid True if all arguments are valid
---@return table|nil validation_errors Table of validation errors if not valid
function ComplexCLI.validate_args(command, args, options)
    -- Create the error handler for validation errors
    local validation_errors = {}
    
    -- Validate required arguments
    if command.arguments then
        for _, arg_def in ipairs(command.arguments) do
            if arg_def.required and (not args[arg_def.name] or args[arg_def.name] == "") then
                table.insert(validation_errors, {
                    parameter = arg_def.name,
                    message = "Required argument '" .. arg_def.name .. "' is missing"
                })
            end
        end
    end
    
    -- Validate option choices
    if command.options then
        for _, opt_def in ipairs(command.options) do
            if opt_def.choices and options[opt_def.name] then
                local value = options[opt_def.name]
                local valid_choice = false
                
                for _, choice in ipairs(opt_def.choices) do
                    if value == choice then
                        valid_choice = true
                        break
                    end
                end
                
                if not valid_choice then
                    table.insert(validation_errors, {
                        parameter = opt_def.name,
                        message = "Invalid value for '" .. opt_def.name .. "': " .. 
                                  tostring(value) .. ". Must be one of: " .. 
                                  table.concat(opt_def.choices, ", ")
                    })
                end
            end
        end
    end
    
    -- Return validation results
    if #validation_errors > 0 then
        return false, validation_errors
    end
    
    return true
end

---@param command table The CLI command object
---@param args string[] Command-line arguments to parse and execute
---@return {exit_code: number, error?: table, errors?: table[]} Result of the command execution
function ComplexCLI.execute_with_validation(command, args)
    -- Parse the arguments first
    local parsed_args, parsed_options, parse_err = cli.parse_args(command, args)
    
    if parse_err then
        print("Error parsing arguments:", parse_err.message)
        return { exit_code = 1, error = parse_err }
    end
    
    -- Validate the arguments
    local valid, validation_errors = ComplexCLI.validate_args(command, parsed_args, parsed_options)
    
    if not valid then
        print("Validation errors:")
        for _, err in ipairs(validation_errors) do
            print("  - " .. err.message)
        end
        
        return { exit_code = 1, errors = validation_errors }
    end
    
    -- If everything is valid, execute the command
    local exit_code = command.handler(parsed_args, parsed_options)
    return { exit_code = exit_code }
end

-- Test validation with invalid inputs
local validation_tests = {
    { "init" },  -- Missing required 'directory' argument
    { "report", "--format", "invalid" } -- Invalid choice for 'format'
}

print("\nValidation Tests:")
for i, args in ipairs(validation_tests) do
    print("\nTest " .. i .. ":")
    print("Command:", "firmo-cli", table.concat(args, " "))
    
    local result = ComplexCLI.execute_with_validation(complex_cli, args)
    print("Exit code:", result.exit_code)
end

-- Example 8: Exception Handling
print("\nExample 8: Exception Handling")

---@param command table The CLI command object
---@param args string[] Command-line arguments to parse and execute
---@return {exit_code: number, error?: string, error_type?: string, error_details?: table} Result of the command execution
function ComplexCLI.safe_execute(command, args)
    -- Use error_handler.try to catch any errors
    local success, result, err = error_handler.try(function()
        -- Parse and validate arguments
        local parsed_args, parsed_options, parse_err = cli.parse_args(command, args)
        
        if parse_err then
            return {
                exit_code = 1,
                error = parse_err.message,
                error_type = "parse_error"
            }
        end
        
        -- Execute the command handler
        local exit_code = command.handler(parsed_args, parsed_options)
        return { exit_code = exit_code }
    end)
    
    if not success then
        -- Format the error for display
        local error_message = "An error occurred: " .. tostring(result)
        
        -- Log the error
        logger.error(error_message, {
            command = command.name,
            arguments = table.concat(args, " "),
            error = result
        })
        
        -- Return error information
        return {
            exit_code = 1,
            error = error_message,
            error_type = "runtime_error",
            error_details = result
        }
    end
    
    return result
end

-- Create a command that throws an error
local error_command = cli.create_command({
    name = "error-test",
    description = "Command that generates errors",
    arguments = {
        {
            name = "error_type",
            description = "Type of error to generate",
            type = "string",
            required = true
        }
    },
    handler = function(args, options)
        if args.error_type == "runtime" then
            error("Simulated runtime error")
        elseif args.error_type == "validation" then
            return nil, error_handler.validation_error(
                "Simulated validation error",
                { parameter = "error_type", value = args.error_type }
            )
        elseif args.error_type == "none" then
            return 0 -- No error
        else
            error("Unknown error type: " .. args.error_type)
        end
    end
})

-- Test exception handling
local exception_tests = {
    { "runtime" },
    { "validation" },
    { "none" },
    { "unknown" }
}

print("\nException Handling Tests:")
for i, args in ipairs(exception_tests) do
    print("\nTest " .. i .. ":")
    print("Command:", "error-test", table.concat(args, " "))
    
    local result = ComplexCLI.safe_execute(error_command, args)
    print("Exit code:", result.exit_code)
    if result.error then
        print("Error:", result.error)
    end
end

-- PART 5: Real-World Examples
print("\nPART 5: Real-World Examples\n")

-- Example 9: Test Runner CLI
print("Example 9: Test Runner CLI")

-- Create a full-featured test runner CLI
local RunnerCLI = {}

function RunnerCLI.init()
    -- Create the root command
    local command = cli.create_command({
        name = "run-tests",
        description = "Firmo Test Runner",
        version = "1.0.0",
        options = {
            {
                name = "verbose",
                short = "v",
                description = "Enable verbose output",
                type = "boolean",
                default = false
            },
            {
                name = "config",
                short = "c",
                description = "Path to configuration file",
                type = "string"
            }
        },
        handler = function(args, options)
            print("Firmo Test Runner")
            print("Use 'run-tests [command] --help' for usage")
            return 0
        end
    })
    
    -- Add run subcommand
    cli.add_subcommand(command, {
        name = "unit",
        description = "Run unit tests",
        arguments = {
            {
                name = "path",
                description = "Path to test file or directory",
                type = "string",
                required = false
            }
        },
        options = {
            {
                name = "pattern",
                short = "p",
                description = "Test pattern to match",
                type = "string"
            },
            {
                name = "tags",
                short = "t",
                description = "Tags to include",
                type = "string"
            },
            {
                name = "exclude-tags",
                short = "T",
                description = "Tags to exclude",
                type = "string"
            },
            {
                name = "coverage",
                short = "c",
                description = "Enable code coverage",
                type = "boolean",
                default = false
            },
            {
                name = "coverage-format",
                description = "Coverage report format",
                type = "string",
                default = "html",
                choices = {"html", "json", "lcov", "cobertura"}
            },
            {
                name = "parallel",
                short = "P",
                description = "Run tests in parallel",
                type = "boolean",
                default = false
            },
            {
                name = "workers",
                short = "w",
                description = "Number of parallel workers",
                type = "number",
                default = 4
            }
        },
        handler = function(args, options, parent_options)
            -- Display test execution information
            print("\nRunning Unit Tests")
            print("=================")
            
            -- Calculate test path
            local test_path = args.path or "tests/unit"
            print("Test path:", test_path)
            
            -- Display test filtering
            local filter_info = {}
            if options.pattern then
                table.insert(filter_info, "pattern=" .. options.pattern)
            end
            if options.tags then
                table.insert(filter_info, "tags=" .. options.tags)
            end
            if options.exclude_tags then
                table.insert(filter_info, "exclude-tags=" .. options.exclude_tags)
            end
            
            if #filter_info > 0 then
                print("Filters:", table.concat(filter_info, ", "))
            else
                print("Filters: none")
            end
            
            -- Display execution settings
            local settings = {}
            table.insert(settings, "verbose=" .. tostring(parent_options.verbose))
            table.insert(settings, "coverage=" .. tostring(options.coverage))
            if options.coverage then
                table.insert(settings, "coverage-format=" .. options.coverage_format)
            end
            table.insert(settings, "parallel=" .. tostring(options.parallel))
            if options.parallel then
                table.insert(settings, "workers=" .. options.workers)
            end
            
            print("Settings:", table.concat(settings, ", "))
            
            -- Display configuration
            print("Config:", parent_options.config or "(default)")
            
            -- Simulate test execution
            print("\nExecuting tests...")
            print("Found 42 tests in 12 files")
            print("All tests passed!")
            
            return 0
        end
    })
    
    -- Add integration subcommand
    cli.add_subcommand(command, {
        name = "integration",
        description = "Run integration tests",
        arguments = {
            {
                name = "path",
                description = "Path to test file or directory",
                type = "string",
                required = false
            }
        },
        options = {
            {
                name = "pattern",
                short = "p",
                description = "Test pattern to match",
                type = "string"
            },
            {
                name = "timeout",
                short = "t",
                description = "Test timeout in seconds",
                type = "number",
                default = 60
            },
            {
                name = "retry",
                short = "r",
                description = "Number of retries for failing tests",
                type = "number",
                default = 0
            }
        },
        handler = function(args, options, parent_options)
            -- Display integration test execution
            print("\nRunning Integration Tests")
            print("=======================")
            
            -- Calculate test path
            local test_path = args.path or "tests/integration"
            print("Test path:", test_path)
            
            -- Display test filtering
            if options.pattern then
                print("Pattern:", options.pattern)
            else
                print("Pattern: none")
            end
            
            -- Display execution settings
            print("Timeout:", options.timeout, "seconds")
            print("Retries:", options.retry)
            print("Verbose:", parent_options.verbose)
            
            -- Display configuration
            print("Config:", parent_options.config or "(default)")
            
            -- Simulate test execution
            print("\nExecuting integration tests...")
            print("Found 15 tests in 5 files")
            print("All tests passed!")
            
            return 0
        end
    })
    
    -- Add report subcommand
    cli.add_subcommand(command, {
        name = "report",
        description = "Generate test reports",
        options = {
            {
                name = "format",
                short = "f",
                description = "Report format",
                type = "string",
                default = "html",
                choices = {"html", "json", "xml", "text"}
            },
            {
                name = "output",
                short = "o",
                description = "Output directory",
                type = "string",
                default = "reports"
            },
            {
                name = "coverage",
                short = "c",
                description = "Include coverage data",
                type = "boolean",
                default = true
            }
        },
        handler = function(args, options, parent_options)
            -- Display report generation information
            print("\nGenerating Test Reports")
            print("=====================")
            
            -- Display report settings
            print("Format:", options.format)
            print("Output:", options.output)
            print("Coverage:", options.coverage)
            print("Verbose:", parent_options.verbose)
            
            -- Display configuration
            print("Config:", parent_options.config or "(default)")
            
            -- Simulate report generation
            print("\nGenerating reports...")
            print("Created report in", options.output .. "/test-report." .. options.format)
            if options.coverage then
                print("Created coverage report in", options.output .. "/coverage-report." .. options.format)
            end
            
            return 0
        end
    })
    
    return command
end

-- Display the test runner CLI
local runner_cli = RunnerCLI.init()

-- Display brief summary of the CLI structure
print("Test Runner CLI Structure:")
print("Main command:", runner_cli.name)
print("Subcommands:", #runner_cli.subcommands)
for _, subcmd in ipairs(runner_cli.subcommands) do
    print("  -", subcmd.name, ":", subcmd.description)
end

-- Example 10: Exit Code Handling
print("\nExample 10: Exit Code Handling")

---@param command table The CLI command object
---@param args string[] Command-line arguments to parse and execute
---@return number exit_code The final exit code of the command execution
function RunnerCLI.execute_with_exit_code(command, args)
    -- In a real CLI tool, we would map exit codes to process.exit() values
    -- For this example, we'll just print them
    
    -- Parse and execute the command
    local result
    
    -- Use error handling to catch any exceptions
    local success, cmd_result, err = error_handler.try(function()
        return cli.execute_command(command, args)
    end)
    
    if not success then
        print("Error executing command:", cmd_result)
        return 1
    end
    
    result = cmd_result
    
    -- Define exit code meanings
    local exit_codes = {
        [0] = "Success - All tests passed",
        [1] = "Error - Command line parsing or validation error",
        [2] = "Failure - Tests failed",
        [3] = "Skip - No tests were executed",
        [4] = "Timeout - Tests timed out",
        [5] = "Coverage - Coverage threshold not met"
    }
    
    -- Display exit code information
    local exit_code = result.exit_code or 0
    print("\nExit Code:", exit_code)
    print("Meaning:", exit_codes[exit_code] or "Unknown exit code")
    
    return exit_code
end

-- Test exit code handling with various scenarios
local exit_code_tests = {
    { "unit", "tests/unit", "--verbose" },  -- Success
    { "unit", "--invalid-option" },         -- Command line error
    { "invalid-command" }                  -- Invalid command
}

print("\nExit Code Handling Tests:")
for i, args in ipairs(exit_code_tests) do
    print("\nTest " .. i .. ":")
    print("Command:", "run-tests", table.concat(args, " "))
    
    local exit_code = RunnerCLI.execute_with_exit_code(runner_cli, args)
end

-- PART 6: Best Practices
print("\nPART 6: CLI Tool Best Practices\n")

print("1. ALWAYS provide clear help text")
print("   Bad: Missing or unclear help")
print("   Good: Comprehensive help with examples")

print("\n2. ALWAYS validate input early")
print("   Bad: Letting errors occur deep in the code")
print("   Good: Validating all arguments and options up front")

print("\n3. ALWAYS use consistent option naming")
print("   Bad: Mixing styles like --verbose and --output-file")
print("   Good: Consistent style like --verbose and --output-dir")

print("\n4. ALWAYS handle errors gracefully")
print("   Bad: Crashing on invalid input")
print("   Good: Providing helpful error messages")

print("\n5. ALWAYS provide meaningful exit codes")
print("   Bad: Using only 0 and 1")
print("   Good: Using well-defined exit codes for different conditions")

print("\n6. ALWAYS support common flags like --help and --version")
print("   Bad: Missing standard flags")
print("   Good: Supporting -h, --help, -V, --version")

print("\n7. ALWAYS use subcommands for complex tools")
print("   Bad: Overloading the main command with too many options")
print("   Good: Organizing functionality with logical subcommands")

print("\n8. ALWAYS log operations at appropriate levels")
print("   Bad: Mixing log messages with command output")
print("   Good: Using structured logging with proper levels")

print("\n9. ALWAYS support configuration files")
print("   Bad: Requiring all options to be specified on command line")
print("   Good: Supporting configuration files with command line overrides")

print("\n10. ALWAYS follow platform conventions")
print("    Bad: Ignoring how other tools work on the platform")
print("    Good: Adhering to platform CLI conventions")

-- Cleanup
print("\nCLI tool example completed successfully.")