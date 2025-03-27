--[[
  error_handling_example.lua
  
  Comprehensive example of standardized error handling in Firmo.
  This example demonstrates best practices for error creation,
  propagation, and handling throughout the framework.
]]

-- Import the required modules
local firmo = require("firmo")
local error_handler = require("lib.tools.error_handler")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem")
local logging = require("lib.tools.logging")

-- Set up logging
local logger = logging.get_logger("ErrorHandlingExample")

-- Testing functions
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

print("\n== ERROR HANDLING SYSTEM EXAMPLE ==\n")
print("PART 1: Error Categories and Creation\n")

-- Display available error categories
print("Standard Error Categories:")
for name, value in pairs(error_handler.CATEGORY) do
    print(string.format("- %-12s: %s", name, value))
end

-- Display available error severities
print("\nError Severities:")
for name, value in pairs(error_handler.SEVERITY) do
    print(string.format("- %-12s: %s", name, value))
end

-- Example 1: Creating basic errors
print("\nExample 1: Creating Basic Errors")

local function create_basic_error()
    -- Create a general error
    local err = error_handler.create(
        "Something went wrong",
        error_handler.CATEGORY.GENERAL,
        error_handler.SEVERITY.ERROR,
        { source = "create_basic_error" }
    )
    
    print("\nGeneral Error:")
    print("- Message:", err.message)
    print("- Category:", err.category)
    print("- Severity:", err.severity)
    print("- Context:", err.context and err.context.source or "None")
    
    return err
end

local basic_error = create_basic_error()

-- Example 2: Specialized error creation helpers
print("\nExample 2: Specialized Error Creation Helpers")

-- Validation error (for input validation failures)
local validation_error = error_handler.validation_error(
    "Invalid parameter: id must be a number",
    { parameter = "id", provided_type = "string", provided_value = "abc" }
)

-- I/O error (for file system operations)
local io_error = error_handler.io_error(
    "Failed to read file",
    { file_path = "/not/a/real/path.txt", operation = "read" }
)

-- Runtime error (for errors that occur during execution)
local runtime_error = error_handler.runtime_error(
    "Unexpected condition during execution",
    { function_name = "process_data", module = "data_processor" }
)

-- Format error (for invalid format or parsing issues)
local format_error = error_handler.format_error(
    "Invalid JSON format",
    { content_sample = "{invalid json", expected_format = "JSON" }
)

-- Display specialized errors
print("\nSpecialized Errors:")
print("\nValidation Error:")
print("- Message:", validation_error.message)
print("- Category:", validation_error.category)
print("- Parameter:", validation_error.context.parameter)
print("- Provided Type:", validation_error.context.provided_type)

print("\nI/O Error:")
print("- Message:", io_error.message)
print("- Category:", io_error.category)
print("- File Path:", io_error.context.file_path)
print("- Operation:", io_error.context.operation)

print("\nRuntime Error:")
print("- Message:", runtime_error.message)
print("- Category:", runtime_error.category)
print("- Function:", runtime_error.context.function_name)
print("- Module:", runtime_error.context.module)

print("\nFormat Error:")
print("- Message:", format_error.message)
print("- Category:", format_error.category)
print("- Expected Format:", format_error.context.expected_format)

-- PART 2: Error Propagation Patterns
print("\nPART 2: Error Propagation Patterns\n")

-- Example 3: Basic error return pattern (nil, error)
print("Example 3: Basic Error Return Pattern (nil, error)")

function read_config_file(path)
    -- Validation
    if type(path) ~= "string" then
        return nil, error_handler.validation_error(
            "Path must be a string",
            { parameter = "path", provided_type = type(path) }
        )
    end
    
    -- Check if file exists (using a fake check for the example)
    if not path:match("%.lua$") and not path:match("%.json$") then
        return nil, error_handler.validation_error(
            "Config file must be .lua or .json",
            { parameter = "path", provided_value = path }
        )
    end
    
    -- In a real implementation, we would read the file here
    -- Simulating success and error cases
    if path:match("missing") then
        return nil, error_handler.io_error(
            "File not found",
            { file_path = path, operation = "read" }
        )
    end
    
    -- Success case: return the result
    return { 
        config_type = path:match("%.(%w+)$"), 
        settings = { 
            debug = true, 
            log_level = "info" 
        } 
    }
end

-- Demo the function with success and error cases
local configs = {
    "config.lua",
    123,  -- Invalid type
    "config.txt",  -- Invalid extension
    "missing.lua"  -- Simulated missing file
}

print("\nTesting read_config_file function:")
for _, config_path in ipairs(configs) do
    local result, err = read_config_file(config_path)
    
    if result then
        print(string.format("SUCCESS: '%s' -> %s config with %d settings", 
            config_path, result.config_type, #next(result.settings) and 
            result.settings or 0))
    else
        print(string.format("ERROR: '%s' -> %s: %s", 
            tostring(config_path), err.category, err.message))
    end
end

-- Example 4: Error propagation chain
print("\nExample 4: Error Propagation Chain")

-- Low-level function that may fail
function parse_json(content)
    -- Simulating parsing failures for invalid JSON
    if not content or not content:match("{") then
        return nil, error_handler.format_error(
            "Invalid JSON format",
            { content_sample = content and content:sub(1, 20) or "nil" }
        )
    end
    
    -- Success case (simulated)
    return { parsed = true, content = content }
end

-- Mid-level function that calls parse_json
function load_json_config(path)
    -- Validation
    if type(path) ~= "string" then
        return nil, error_handler.validation_error(
            "Path must be a string",
            { parameter = "path", provided_type = type(path) }
        )
    end
    
    -- Simulate reading file content
    local content
    if path:match("empty") then
        content = ""
    elseif path:match("invalid") then
        content = "This is not JSON"
    else
        content = '{"setting":"value"}'
    end
    
    -- Parse the content
    local parsed_data, parse_err = parse_json(content)
    
    -- Propagate error if parsing failed
    if not parsed_data then
        -- Add context and propagate the error
        parse_err.context.file_path = path
        return nil, parse_err
    end
    
    -- Success case
    return parsed_data
end

-- High-level function that uses the config
function initialize_with_config(config_path)
    -- Load the configuration
    local config, load_err = load_json_config(config_path)
    
    -- Propagate error if loading failed
    if not config then
        -- Wrap the error with additional context
        return nil, error_handler.create(
            "Failed to initialize: " .. load_err.message,
            error_handler.CATEGORY.INITIALIZATION,
            error_handler.SEVERITY.ERROR,
            {
                original_error = load_err,
                config_path = config_path
            }
        )
    end
    
    -- Success case
    return { initialized = true, config = config }
end

-- Test the error propagation chain
local test_paths = {
    "config.json",       -- Valid
    "empty.json",        -- Empty
    "invalid.json",      -- Invalid JSON
    123                  -- Invalid type
}

print("\nTesting error propagation chain:")
for _, path in ipairs(test_paths) do
    local result, err = initialize_with_config(path)
    
    if result then
        print(string.format("SUCCESS: '%s' -> Initialized successfully", path))
    else
        -- Display the full error chain
        print(string.format("ERROR: '%s' -> %s: %s", 
            tostring(path), err.category, err.message))
        
        -- Display error context
        if err.context then
            print("  Context:")
            if err.context.original_error then
                print("    Original error:", err.context.original_error.message)
                print("    Original category:", err.context.original_error.category)
                if err.context.original_error.context then
                    for k, v in pairs(err.context.original_error.context) do
                        print(string.format("    %s: %s", k, tostring(v)))
                    end
                end
            else
                for k, v in pairs(err.context) do
                    print(string.format("    %s: %s", k, tostring(v)))
                end
            end
        end
    end
end

-- PART 3: Using try/catch Pattern
print("\nPART 3: Using try/catch Pattern\n")

-- Example 5: Try/catch pattern with error_handler.try
print("Example 5: Try/catch Pattern with error_handler.try")

-- Function that may throw an error
function divide(a, b)
    if b == 0 then
        error(error_handler.validation_error(
            "Division by zero",
            { numerator = a, denominator = b }
        ))
    end
    return a / b
end

-- Using try to handle potential errors
function safe_divide(a, b)
    local success, result, err = error_handler.try(function()
        return divide(a, b)
    end)
    
    if not success then
        -- Handle the error safely
        logger.error("Division failed", {
            error = error_handler.format_error(result),
            numerator = a,
            denominator = b
        })
        return nil, result
    end
    
    return result
end

-- Test the try/catch pattern
local test_divisions = {
    { 10, 2 },   -- Valid
    { 10, 0 },   -- Division by zero
    { "10", 2 }, -- Type error
}

print("\nTesting try/catch pattern:")
for _, pair in ipairs(test_divisions) do
    local result, err = safe_divide(pair[1], pair[2])
    
    if result then
        print(string.format("SUCCESS: %s / %s = %s", 
            tostring(pair[1]), tostring(pair[2]), tostring(result)))
    else
        print(string.format("ERROR: %s / %s -> %s", 
            tostring(pair[1]), tostring(pair[2]), 
            err and (err.category .. ": " .. err.message) or "Unknown error"))
    end
end

-- PART 4: Safe I/O Operations
print("\nPART 4: Safe I/O Operations\n")

-- Example 6: Safe file operations with error handling
print("Example 6: Safe File Operations")

-- Create a temporary file for testing
local temp_dir = os.tmpname()
os.remove(temp_dir) -- Remove the file so we can create a directory
os.execute("mkdir -p " .. temp_dir)
local test_file = temp_dir .. "/test_file.txt"
local missing_file = temp_dir .. "/missing_file.txt"
local invalid_path = temp_dir .. "/invalid/path/file.txt"

-- Write to the test file
local write_result, write_err = error_handler.safe_io_operation(function()
    local file = io.open(test_file, "w")
    if not file then error("Failed to open file for writing") end
    file:write("Test content")
    file:close()
    return true
end, test_file, { operation = "write" })

-- Read from existing file
local read_result, read_err = error_handler.safe_io_operation(function()
    local file = io.open(test_file, "r")
    if not file then error("Failed to open file for reading") end
    local content = file:read("*a")
    file:close()
    return content
end, test_file, { operation = "read" })

-- Try to read from missing file
local missing_result, missing_err = error_handler.safe_io_operation(function()
    local file = io.open(missing_file, "r")
    if not file then error("Failed to open file for reading") end
    local content = file:read("*a")
    file:close()
    return content
end, missing_file, { operation = "read" })

-- Try to write to invalid path
local invalid_result, invalid_err = error_handler.safe_io_operation(function()
    local file = io.open(invalid_path, "w")
    if not file then error("Failed to open file for writing") end
    file:write("Test content")
    file:close()
    return true
end, invalid_path, { operation = "write" })

-- Display results
print("\nSafe I/O operation results:")
print("Write to test file:", write_result and "Success" or "Error: " .. write_err.message)
print("Read from test file:", read_result and ("Success: \"" .. read_result .. "\"") or "Error: " .. read_err.message)
print("Read from missing file:", missing_result and "Success (unexpected)" or "Error: " .. missing_err.message)
print("Write to invalid path:", invalid_result and "Success (unexpected)" or "Error: " .. invalid_err.message)

-- Clean up
os.execute("rm -rf " .. temp_dir)

-- PART 5: Testing Error Handling
print("\nPART 5: Testing Error Handling\n")

-- Example 7: Testing error conditions with expect_error
print("Example 7: Testing Error Conditions")

-- Function to test
function validate_user(user)
    if type(user) ~= "table" then
        return nil, error_handler.validation_error(
            "User must be a table",
            { parameter = "user", provided_type = type(user) }
        )
    end
    
    if not user.name or type(user.name) ~= "string" then
        return nil, error_handler.validation_error(
            "User must have a name property of type string",
            { parameter = "user.name", provided_value = user.name }
        )
    end
    
    if not user.age or type(user.age) ~= "number" or user.age < 0 then
        return nil, error_handler.validation_error(
            "User must have a valid age (non-negative number)",
            { parameter = "user.age", provided_value = user.age }
        )
    end
    
    return user
end

-- Unit tests for the validate_user function
describe("User Validation", function()
    it("accepts valid users", function()
        local user = { name = "John", age = 30 }
        local result, err = validate_user(user)
        
        expect(result).to.exist()
        expect(err).to.equal(nil)
        expect(result.name).to.equal("John")
        expect(result.age).to.equal(30)
    end)
    
    it("rejects non-table input", { expect_error = true }, function()
        local result, err = test_helper.with_error_capture(function()
            return validate_user("not a table")
        end)()
        
        expect(result).to.equal(nil)
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("must be a table")
    end)
    
    it("requires a name property", { expect_error = true }, function()
        local result, err = test_helper.with_error_capture(function()
            return validate_user({ age = 30 })
        end)()
        
        expect(result).to.equal(nil)
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("name property")
    end)
    
    it("requires a valid age", { expect_error = true }, function()
        local result, err = test_helper.with_error_capture(function()
            return validate_user({ name = "John", age = -10 })
        end)()
        
        expect(result).to.equal(nil)
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("valid age")
    end)
    
    it("handles nil age", { expect_error = true }, function()
        local result, err = test_helper.with_error_capture(function()
            return validate_user({ name = "John" })
        end)()
        
        expect(result).to.equal(nil)
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
        expect(err.message).to.match("valid age")
        expect(err.context.provided_value).to.equal(nil)
    end)
    
    -- Using expect_error helper for more concise test
    it("rejects invalid age type with expect_error", { expect_error = true }, function()
        local err = test_helper.expect_error(function()
            validate_user({ name = "John", age = "thirty" })
        end, "valid age")
        
        expect(err).to.exist()
        expect(err.category).to.equal(error_handler.CATEGORY.VALIDATION)
    end)
end)

print("Run the tests with: lua test.lua examples/error_handling_example.lua\n")

-- PART 6: Best Practices
print("\nPART 6: Error Handling Best Practices\n")

print("1. ALWAYS provide detailed error messages")
print("   Bad: 'An error occurred'")
print("   Good: 'Failed to read config file: file not found'")

print("\n2. ALWAYS use appropriate error categories")
print("   Bad: Using general errors for everything")
print("   Good: Using specific categories: VALIDATION, IO, RUNTIME, etc.")

print("\n3. ALWAYS include contextual information in errors")
print("   Bad: Error without context")
print("   Good: Error with file path, parameter name, expected type, etc.")

print("\n4. ALWAYS propagate errors with added context")
print("   Bad: Swallowing errors or losing context")
print("   Good: Wrapping errors with additional context")

print("\n5. ALWAYS validate function inputs")
print("   Bad: Assuming inputs are valid and correct types")
print("   Good: Validating all inputs and returning appropriate errors")

print("\n6. ALWAYS use the nil, error pattern for error returns")
print("   Bad: Returning 'false' or other values to indicate errors")
print("   Good: Returning 'nil, error_object' for errors")

print("\n7. ALWAYS use error_handler.try for code that might throw")
print("   Bad: Using pcall directly without standardized error handling")
print("   Good: Using error_handler.try with proper error conversion")

print("\n8. ALWAYS handle errors properly in tests")
print("   Bad: Letting errors crash tests or missing error cases")
print("   Good: Using expect_error and test_helper.with_error_capture")

print("\n9. ALWAYS include debugging information in errors")
print("   Bad: Generic errors without details")
print("   Good: Errors with stack traces, inputs, and state information")

print("\n10. ALWAYS log errors appropriately")
print("    Bad: Not logging errors or logging incorrectly")
print("    Good: Logging with proper level and structured data")

-- Cleanup 
print("\nError handling example completed successfully.")