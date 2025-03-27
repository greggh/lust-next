# Test Helper Examples

This document provides practical examples of using the Test Helper module to make tests more reliable and easier to write. The examples show how to handle error conditions, manage temporary files, and create robust test environments.

## Table of Contents

- [Error Testing Examples](#error-testing-examples)
- [Temporary File Examples](#temporary-file-examples)
- [Test Directory Examples](#test-directory-examples)
- [Environment Modification Examples](#environment-modification-examples)
- [Mocking Examples](#mocking-examples)
- [Integration Examples](#integration-examples)

## Error Testing Examples

### Example 1: Basic Error Capture

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Error testing examples", function()
  it("should capture errors with details", function()
    -- Function that will throw an error
    local function divide(a, b)
      if b == 0 then
        error("Division by zero")
      end
      return a / b
    end
    
    -- Capture error safely
    local result, err = test_helper.with_error_capture(function()
      return divide(10, 0)
    end)()
    
    -- Error should have been caught
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("Division by zero")
  end)
  
  it("should handle successful execution", function()
    -- Capture result from successful execution
    local result, err = test_helper.with_error_capture(function()
      return 10 + 5
    end)()
    
    -- Should have result, not error
    expect(result).to.equal(15)
    expect(err).to_not.exist()
  end)
end)
```

### Example 2: Expecting Errors

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Expect error examples", function()
  -- Simple validator function
  local function validate_email(email)
    if type(email) ~= "string" then
      error({message = "Email must be a string", category = "VALIDATION"})
    end
    
    if not email:match("^[%w.-]+@[%w.-]+%.%w+$") then
      error({message = "Invalid email format", category = "VALIDATION"})
    end
    
    return true
  end
  
  it("should fail for non-string emails", { expect_error = true }, function()
    local err = test_helper.expect_error(function()
      validate_email(123)
    end, "Email must be a string")
    
    expect(err.category).to.equal("VALIDATION")
  end)
  
  it("should fail for invalid email format", { expect_error = true }, function()
    local err = test_helper.expect_error(function()
      validate_email("not-an-email")
    end, "Invalid email format")
    
    expect(err.category).to.equal("VALIDATION")
  end)
  
  it("should pass for valid emails", function()
    local result = validate_email("user@example.com")
    expect(result).to.equal(true)
  end)
end)
```

### Example 3: Suppressing Output

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Output suppression examples", function()
  -- Function that prints output
  local function verbose_function(message, level)
    print("INFO: " .. message)
    if level == "error" then
      io.stderr:write("ERROR: " .. message .. "\n")
    end
    return #message
  end
  
  it("should capture stdout and stderr", function()
    local result, stdout, stderr = test_helper.with_suppressed_output(function()
      return verbose_function("Test message", "info")
    end)
    
    expect(result).to.equal(12)
    expect(stdout).to.match("INFO: Test message")
    expect(stderr).to.equal("")
  end)
  
  it("should capture stderr separately", function()
    local result, stdout, stderr = test_helper.with_suppressed_output(function()
      return verbose_function("Error occurred", "error")
    end)
    
    expect(result).to.equal(14)
    expect(stdout).to.match("INFO: Error occurred")
    expect(stderr).to.match("ERROR: Error occurred")
  end)
end)
```

## Temporary File Examples

### Example 4: Creating and Using Temporary Files

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Temporary file examples", function()
  local fs = require("lib.tools.filesystem")

  it("should create empty temporary file", function()
    local temp_file, err = test_helper.create_temp_file("lua")
    
    -- Check the file was created
    expect(err).to_not.exist()
    expect(temp_file).to.match("%.lua$")
    expect(fs.file_exists(temp_file)).to.equal(true)
    
    -- Check the file is empty
    local content = fs.read_file(temp_file)
    expect(content).to.equal("")
    
    -- No need to clean up - happens automatically
  end)
  
  it("should create file with content", function()
    local content = [[
      function test()
        return "Hello, world!"
      end
    ]]
    
    local temp_file, err = test_helper.create_temp_file_with_content(content, "lua")
    
    -- Check the file was created with content
    expect(err).to_not.exist()
    expect(fs.file_exists(temp_file)).to.equal(true)
    
    -- Check the content was written
    local read_content = fs.read_file(temp_file)
    expect(read_content).to.equal(content)
    
    -- Load and execute the file
    local chunk, load_err = loadfile(temp_file)
    expect(load_err).to_not.exist()
    
    local module = chunk()
    expect(module()).to.equal("Hello, world!")
    
    -- No need to clean up - happens automatically
  end)
end)
```

### Example 5: Registering External Files

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("External file registration examples", function()
  local fs = require("lib.tools.filesystem")

  it("should register and clean up external files", function()
    -- Create file using os.tmpname
    local file_path = os.tmpname()
    local f = io.open(file_path, "w")
    f:write("This is a test file")
    f:close()
    
    -- Register for cleanup
    test_helper.register_temp_file(file_path)
    
    -- Use the file in tests
    local content = fs.read_file(file_path)
    expect(content).to.equal("This is a test file")
    
    -- No need to manually delete - happens automatically
  end)
  
  it("should register and clean up external directories", function()
    -- Create temporary directory
    local dir_path = os.tmpname()
    os.remove(dir_path) -- Remove the file created by tmpname
    fs.create_directory(dir_path)
    
    -- Create files in the directory
    local file1 = dir_path .. "/file1.txt"
    local file2 = dir_path .. "/file2.txt"
    
    fs.write_file(file1, "File 1")
    fs.write_file(file2, "File 2")
    
    -- Register for cleanup
    test_helper.register_temp_directory(dir_path)
    
    -- Use the directory in tests
    local files = fs.list_directory(dir_path)
    expect(#files).to.equal(2)
    
    -- No need to manually delete - happens automatically
  end)
end)
```

## Test Directory Examples

### Example 6: Creating and Using Test Directories

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Test directory examples", function()
  local fs = require("lib.tools.filesystem")

  it("should create test directory with files", function()
    local test_dir = test_helper.create_temp_test_directory()
    
    -- Create some files
    test_dir.create_file("config.json", '{"test": true}')
    test_dir.create_file("src/main.lua", "return 'Hello, world!'")
    test_dir.create_file("README.md", "# Test Project")
    
    -- Verify files were created
    expect(fs.file_exists(test_dir.path .. "/config.json")).to.equal(true)
    expect(fs.file_exists(test_dir.path .. "/src/main.lua")).to.equal(true)
    expect(fs.file_exists(test_dir.path .. "/README.md")).to.equal(true)
    
    -- Read file content
    local config = test_dir.read_file("config.json")
    expect(config).to.equal('{"test": true}')
    
    -- Get absolute path to a file
    local main_path = test_dir.file_path("src/main.lua")
    expect(main_path).to.equal(test_dir.path .. "/src/main.lua")
    
    -- Directory is cleaned up automatically
  end)
  
  it("should use the with_temp_test_directory helper", function()
    test_helper.with_temp_test_directory({
      ["config.json"] = '{"test": true}',
      ["src/main.lua"] = "return 'Hello, world!'",
      ["README.md"] = "# Test Project"
    }, function(dir_path, files, test_dir)
      -- Verify files were created
      expect(fs.file_exists(dir_path .. "/config.json")).to.equal(true)
      expect(fs.file_exists(dir_path .. "/src/main.lua")).to.equal(true)
      expect(fs.file_exists(dir_path .. "/README.md")).to.equal(true)
      
      -- Access files by relative path
      expect(files["config.json"]).to.equal(dir_path .. "/config.json")
      expect(files["src/main.lua"]).to.equal(dir_path .. "/src/main.lua")
      
      -- Use the test_dir object
      local config = test_dir.read_file("config.json")
      expect(config).to.equal('{"test": true}')
      
      -- Files will be cleaned up when function returns
    end)
  end)
end)
```

### Example 7: Project Structure Testing

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Project structure examples", function()
  -- Mock project utilities
  local function find_modules(dir)
    local fs = require("lib.tools.filesystem")
    local modules = {}
    
    local lua_files = fs.list_files(dir, "%.lua$")
    for _, file in ipairs(lua_files) do
      if not file:match("_test%.lua$") then
        table.insert(modules, file)
      end
    end
    
    return modules
  end
  
  local function count_tests(dir)
    local fs = require("lib.tools.filesystem")
    local test_files = fs.list_files(dir, "_test%.lua$")
    return #test_files
  end
  
  it("should verify module-test correspondence", function()
    test_helper.with_temp_test_directory({
      ["src/module1.lua"] = "return { func = function() return true end }",
      ["src/module2.lua"] = "return { func = function() return false end }",
      ["src/utils/helper.lua"] = "return { trim = function(s) return s:match('^%s*(.-)%s*$') end }",
      ["tests/module1_test.lua"] = "-- Test for module1",
      ["tests/module2_test.lua"] = "-- Test for module2",
      ["tests/utils/helper_test.lua"] = "-- Test for helper"
    }, function(dir_path, files, test_dir)
      -- Find all modules
      local modules = find_modules(dir_path .. "/src")
      local test_count = count_tests(dir_path .. "/tests")
      
      -- Verify every module has a corresponding test
      expect(#modules).to.equal(test_count)
      
      -- Check specific modules
      local module_names = {}
      for _, path in ipairs(modules) do
        local name = path:match("([^/]+)%.lua$")
        module_names[name] = true
      end
      
      expect(module_names["module1"]).to.equal(true)
      expect(module_names["module2"]).to.equal(true)
      expect(module_names["helper"]).to.equal(true)
    end)
  end)
end)
```

## Environment Modification Examples

### Example 8: Environment Variables

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Environment variable examples", function()
  -- Mock logger configuration
  local function init_logger()
    local logger = {
      level = os.getenv("LOG_LEVEL") or "info",
      debug = os.getenv("DEBUG") == "1",
      output = os.getenv("LOG_OUTPUT") or "console"
    }
    return logger
  end
  
  it("should configure using environment variables", function()
    test_helper.with_environment({
      LOG_LEVEL = "debug",
      DEBUG = "1",
      LOG_OUTPUT = "file"
    }, function()
      local logger = init_logger()
      
      expect(logger.level).to.equal("debug")
      expect(logger.debug).to.equal(true)
      expect(logger.output).to.equal("file")
    end)
    
    -- Environment is restored after function completes
    local logger = init_logger()
    expect(logger.level).to_not.equal("debug")
    expect(logger.debug).to.equal(false)
  end)
  
  it("should work with empty environment", function()
    test_helper.with_environment({
      LOG_LEVEL = nil,
      DEBUG = nil,
      LOG_OUTPUT = nil
    }, function()
      local logger = init_logger()
      
      expect(logger.level).to.equal("info")  -- default
      expect(logger.debug).to.equal(false)   -- default
      expect(logger.output).to.equal("console") -- default
    end)
  end)
end)
```

### Example 9: Working Directory

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Working directory examples", function()
  local fs = require("lib.tools.filesystem")
  
  -- Mock function that depends on current working directory
  local function find_config_file()
    local paths_to_check = {
      ".firmo-config.lua",
      ".firmo-config.json",
      "firmo-config.lua"
    }
    
    for _, path in ipairs(paths_to_check) do
      if fs.file_exists(path) then
        return path
      end
    end
    
    return nil
  end
  
  it("should find config file in current directory", function()
    test_helper.with_temp_test_directory({
      [".firmo-config.lua"] = "return { test = true }"
    }, function(dir_path)
      -- Save original directory
      local original_dir = fs.get_current_directory()
      
      -- Test with modified working directory
      test_helper.with_working_directory(dir_path, function()
        local config_path = find_config_file()
        expect(config_path).to.equal(".firmo-config.lua")
        
        -- Verify we can read the file
        local f = io.open(config_path, "r")
        local content = f:read("*a")
        f:close()
        
        expect(content).to.equal("return { test = true }")
      end)
      
      -- Verify working directory was restored
      expect(fs.get_current_directory()).to.equal(original_dir)
    end)
  end)
  
  it("should find config file in subdirectory", function()
    test_helper.with_temp_test_directory({
      ["project/.firmo-config.json"] = '{"test": true}'
    }, function(dir_path)
      test_helper.with_working_directory(dir_path .. "/project", function()
        local config_path = find_config_file()
        expect(config_path).to.equal(".firmo-config.json")
      end)
    end)
  end)
end)
```

### Example 10: Path Separator Testing

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Path separator examples", function()
  -- Mock path normalization function
  local function normalize_path(path)
    local separator = package.config:sub(1, 1)
    
    if separator == "/" then
      return path:gsub("\\", "/")
    else
      return path:gsub("/", "\\")
    end
  end
  
  -- Mock path joining function
  local function join_paths(...)
    local separator = package.config:sub(1, 1)
    local paths = {...}
    return table.concat(paths, separator)
  end
  
  it("should normalize paths on Unix systems", function()
    test_helper.with_path_separator("/", function()
      -- Test Unix-style normalization
      expect(normalize_path("dir1/dir2/file.txt")).to.equal("dir1/dir2/file.txt")
      expect(normalize_path("dir1\\dir2\\file.txt")).to.equal("dir1/dir2/file.txt")
      
      -- Test path joining
      expect(join_paths("dir1", "dir2", "file.txt")).to.equal("dir1/dir2/file.txt")
    end)
  end)
  
  it("should normalize paths on Windows systems", function()
    test_helper.with_path_separator("\\", function()
      -- Test Windows-style normalization
      expect(normalize_path("dir1\\dir2\\file.txt")).to.equal("dir1\\dir2\\file.txt")
      expect(normalize_path("dir1/dir2/file.txt")).to.equal("dir1\\dir2\\file.txt")
      
      -- Test path joining
      expect(join_paths("dir1", "dir2", "file.txt")).to.equal("dir1\\dir2\\file.txt")
    end)
  end)
end)
```

## Mocking Examples

### Example 11: Mocking I/O Operations

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("I/O mocking examples", function()
  -- Mock config loader
  local function load_config(path)
    local f = io.open(path, "r")
    if not f then
      error("Failed to open config file: " .. path)
    end
    
    local content = f:read("*a")
    f:close()
    
    -- Simple JSON parsing
    if path:match("%.json$") then
      -- Very basic JSON parsing for example purposes
      local parsed = {}
      for key, value in content:gmatch('"([^"]+)":%s*"([^"]+)"') do
        parsed[key] = value
      end
      return parsed
    else
      -- Assume Lua config
      local chunk, err = load("return " .. content)
      if not chunk then
        error("Failed to parse config: " .. err)
      end
      return chunk()
    end
  end
  
  it("should handle JSON config files", function()
    -- Set up I/O mocking
    local restore = test_helper.mock_io({
      ["config%.json"] = {
        read = '{"username": "test", "api_key": "abc123"}',
        error = nil
      }
    })
    
    -- Test with mocked I/O
    local config = load_config("config.json")
    expect(config.username).to.equal("test")
    expect(config.api_key).to.equal("abc123")
    
    -- Restore original I/O functions
    restore()
  end)
  
  it("should handle Lua config files", function()
    -- Set up I/O mocking
    local restore = test_helper.mock_io({
      ["config%.lua"] = {
        read = '{ username = "test", api_key = "abc123" }',
        error = nil
      }
    })
    
    -- Test with mocked I/O
    local config = load_config("config.lua")
    expect(config.username).to.equal("test")
    expect(config.api_key).to.equal("abc123")
    
    -- Restore original I/O functions
    restore()
  end)
  
  it("should handle missing config files", function()
    -- Set up I/O mocking
    local restore = test_helper.mock_io({
      ["missing%.json"] = {
        read = nil,
        error = "No such file or directory"
      }
    })
    
    -- Test with mocked I/O
    local success, err = pcall(function()
      load_config("missing.json")
    end)
    
    expect(success).to.equal(false)
    expect(err).to.match("Failed to open config file")
    
    -- Restore original I/O functions
    restore()
  end)
end)
```

### Example 12: Time Mocking

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Time mocking examples", function()
  -- Mock timestamp formatter
  local function format_timestamp(format)
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format, os.time())
  end
  
  -- Mock age calculator
  local function calculate_age(birth_date)
    local year, month, day = birth_date:match("(%d+)-(%d+)-(%d+)")
    
    local birth_timestamp = os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day)
    })
    
    local age_seconds = os.difftime(os.time(), birth_timestamp)
    local age_years = math.floor(age_seconds / (365.25 * 24 * 60 * 60))
    
    return age_years
  end
  
  it("should format timestamps correctly", function()
    -- Mock current time to a specific date
    local restore = test_helper.mock_time("2025-03-15 14:30:00")
    
    -- Test timestamp formatting
    expect(format_timestamp()).to.equal("2025-03-15 14:30:00")
    expect(format_timestamp("%Y-%m-%d")).to.equal("2025-03-15")
    expect(format_timestamp("%H:%M")).to.equal("14:30")
    
    -- Restore original time functions
    restore()
  end)
  
  it("should calculate age correctly", function()
    -- Mock current time to a specific date
    local restore = test_helper.mock_time("2025-03-15")
    
    -- Test age calculation from various dates
    expect(calculate_age("2000-01-01")).to.equal(25)
    expect(calculate_age("2000-06-01")).to.equal(24)
    expect(calculate_age("1990-03-15")).to.equal(35)
    expect(calculate_age("1990-03-16")).to.equal(34)
    
    -- Restore original time functions
    restore()
  end)
end)
```

### Example 13: Creating Spy Functions

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Spy function examples", function()
  -- Mock calculator module
  local calculator = {
    add = function(a, b) return a + b end,
    subtract = function(a, b) return a - b end,
    multiply = function(a, b) return a * b end,
    divide = function(a, b)
      if b == 0 then error("Division by zero") end
      return a / b
    end
  }
  
  -- Mock function that uses calculator
  local function perform_calculations(values)
    local results = {}
    
    -- Sum all values
    local sum = 0
    for _, v in ipairs(values) do
      sum = calculator.add(sum, v)
    end
    results.sum = sum
    
    -- Calculate average
    results.average = calculator.divide(sum, #values)
    
    -- Calculate product
    local product = 1
    for _, v in ipairs(values) do
      product = calculator.multiply(product, v)
    end
    results.product = product
    
    return results
  end
  
  it("should track function calls", function()
    -- Create spies for calculator functions
    local add_spy = test_helper.create_spy(calculator.add)
    local divide_spy = test_helper.create_spy(calculator.divide)
    local multiply_spy = test_helper.create_spy(calculator.multiply)
    
    -- Replace original functions with spies
    local original_add = calculator.add
    local original_divide = calculator.divide
    local original_multiply = calculator.multiply
    
    calculator.add = add_spy.func
    calculator.divide = divide_spy.func
    calculator.multiply = multiply_spy.func
    
    -- Call the function that uses calculator
    local results = perform_calculations({2, 4, 6})
    
    -- Verify results
    expect(results.sum).to.equal(12)
    expect(results.average).to.equal(4)
    expect(results.product).to.equal(48)
    
    -- Verify add spy
    expect(add_spy.called).to.equal(true)
    expect(add_spy.call_count).to.equal(3)
    expect(add_spy.calls[1].args[1]).to.equal(0)
    expect(add_spy.calls[1].args[2]).to.equal(2)
    expect(add_spy.calls[2].args[1]).to.equal(2)
    expect(add_spy.calls[2].args[2]).to.equal(4)
    expect(add_spy.calls[3].args[1]).to.equal(6)
    expect(add_spy.calls[3].args[2]).to.equal(6)
    
    -- Verify divide spy
    expect(divide_spy.called).to.equal(true)
    expect(divide_spy.call_count).to.equal(1)
    expect(divide_spy.calls[1].args[1]).to.equal(12)
    expect(divide_spy.calls[1].args[2]).to.equal(3)
    
    -- Verify multiply spy
    expect(multiply_spy.called).to.equal(true)
    expect(multiply_spy.call_count).to.equal(3)
    expect(multiply_spy.calls[1].args[1]).to.equal(1)
    expect(multiply_spy.calls[1].args[2]).to.equal(2)
    expect(multiply_spy.calls[2].args[1]).to.equal(2)
    expect(multiply_spy.calls[2].args[2]).to.equal(4)
    expect(multiply_spy.calls[3].args[1]).to.equal(8)
    expect(multiply_spy.calls[3].args[2]).to.equal(6)
    
    -- Restore original functions
    calculator.add = original_add
    calculator.divide = original_divide
    calculator.multiply = original_multiply
  end)
  
  it("should track errors correctly", function()
    -- Create spy for divide function
    local divide_spy = test_helper.create_spy(calculator.divide)
    
    -- Replace original function with spy
    local original_divide = calculator.divide
    calculator.divide = divide_spy.func
    
    -- Call with invalid arguments (division by zero)
    local success, err = pcall(function()
      calculator.divide(10, 0)
    end)
    
    -- Verify the function was called
    expect(divide_spy.called).to.equal(true)
    expect(divide_spy.call_count).to.equal(1)
    expect(divide_spy.calls[1].args[1]).to.equal(10)
    expect(divide_spy.calls[1].args[2]).to.equal(0)
    
    -- Verify error was properly recorded
    expect(divide_spy.calls[1].error).to.exist()
    expect(divide_spy.calls[1].error).to.match("Division by zero")
    
    -- Restore original function
    calculator.divide = original_divide
  end)
end)
```

## Integration Examples

### Example 14: Integration with Error Handler

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Error handler integration examples", function()
  local error_handler = require("lib.tools.error_handler")
  
  -- Mock validation function
  local function validate_user(user)
    if type(user) ~= "table" then
      return nil, error_handler.validation_error(
        "User must be a table",
        {
          input_type = type(user),
          function = "validate_user"
        }
      )
    end
    
    if not user.username then
      return nil, error_handler.validation_error(
        "Username is required",
        {
          function = "validate_user",
          provided_fields = table.concat(table_keys(user), ", ")
        }
      )
    end
    
    if type(user.username) ~= "string" or user.username == "" then
      return nil, error_handler.validation_error(
        "Username must be a non-empty string",
        {
          function = "validate_user",
          username_type = type(user.username),
          username_value = user.username
        }
      )
    end
    
    if user.age and type(user.age) ~= "number" then
      return nil, error_handler.validation_error(
        "Age must be a number if provided",
        {
          function = "validate_user",
          age_type = type(user.age),
          age_value = user.age
        }
      )
    end
    
    return user
  end
  
  -- Helper function to get table keys
  function table_keys(t)
    local keys = {}
    for k, _ in pairs(t) do
      table.insert(keys, k)
    end
    return keys
  end
  
  it("should validate correct user data", function()
    local user = {
      username = "test_user",
      age = 30
    }
    
    local result, err = validate_user(user)
    expect(err).to_not.exist()
    expect(result).to.equal(user)
  end)
  
  it("should validate user with minimal data", function()
    local user = {
      username = "test_user"
    }
    
    local result, err = validate_user(user)
    expect(err).to_not.exist()
    expect(result).to.equal(user)
  end)
  
  it("should fail for non-table input", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return validate_user("not_a_table")
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.equal("User must be a table")
    expect(err.category).to.equal("VALIDATION")
    expect(err.context.input_type).to.equal("string")
  end)
  
  it("should fail for missing username", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return validate_user({age = 30})
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.equal("Username is required")
    expect(err.category).to.equal("VALIDATION")
    expect(err.context.provided_fields).to.equal("age")
  end)
  
  it("should fail for invalid username type", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return validate_user({username = 123})
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.equal("Username must be a non-empty string")
    expect(err.category).to.equal("VALIDATION")
    expect(err.context.username_type).to.equal("number")
  end)
  
  it("should fail for empty username", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return validate_user({username = ""})
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.equal("Username must be a non-empty string")
    expect(err.category).to.equal("VALIDATION")
    expect(err.context.username_value).to.equal("")
  end)
  
  it("should fail for invalid age type", { expect_error = true }, function()
    local result, err = test_helper.with_error_capture(function()
      return validate_user({username = "test_user", age = "thirty"})
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.equal("Age must be a number if provided")
    expect(err.category).to.equal("VALIDATION")
    expect(err.context.age_type).to.equal("string")
  end)
end)
```

### Example 15: Integration with Filesystem Module

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Filesystem integration examples", function()
  local fs = require("lib.tools.filesystem")
  
  -- Mock project module functions
  local function create_project(name, options)
    options = options or {}
    
    -- Create project directory
    local project_dir = options.path or "."
    project_dir = fs.join_paths(project_dir, name)
    
    -- Create directories
    local dirs = {
      project_dir,
      fs.join_paths(project_dir, "src"),
      fs.join_paths(project_dir, "tests"),
      fs.join_paths(project_dir, "docs")
    }
    
    for _, dir in ipairs(dirs) do
      local success, err = fs.create_directory(dir)
      if not success then
        return nil, "Failed to create directory " .. dir .. ": " .. err
      end
    end
    
    -- Create initial files
    local files = {
      [fs.join_paths(project_dir, "README.md")] = "# " .. name .. "\n\nA new project created with Firmo.",
      [fs.join_paths(project_dir, ".firmo-config.lua")] = "return {\n  name = \"" .. name .. "\",\n  created_at = \"" .. os.date("%Y-%m-%d") .. "\"\n}",
      [fs.join_paths(project_dir, "src", "init.lua")] = "local M = {}\nM._VERSION = \"0.1.0\"\nreturn M"
    }
    
    for path, content in pairs(files) do
      local success, err = fs.write_file(path, content)
      if not success then
        return nil, "Failed to create file " .. path .. ": " .. err
      end
    end
    
    return {
      name = name,
      path = project_dir
    }
  end
  
  local function list_project_files(project_dir)
    local files = {}
    
    local function scan_dir(dir, relative_path)
      relative_path = relative_path or ""
      
      local entries = fs.list_directory(dir)
      for _, entry in ipairs(entries) do
        local path = fs.join_paths(dir, entry)
        local rel_path = relative_path ~= "" and fs.join_paths(relative_path, entry) or entry
        
        if fs.is_directory(path) then
          scan_dir(path, rel_path)
        else
          table.insert(files, rel_path)
        end
      end
    end
    
    scan_dir(project_dir)
    return files
  end
  
  it("should create project structure", function()
    -- Create temp directory for test
    test_helper.with_temp_test_directory({}, function(dir_path, _, test_dir)
      -- Create a project in the temp directory
      local project, err = create_project("test-project", {path = dir_path})
      
      -- Verify project was created
      expect(err).to_not.exist()
      expect(project).to.exist()
      expect(project.name).to.equal("test-project")
      expect(project.path).to.equal(fs.join_paths(dir_path, "test-project"))
      
      -- Verify project directory structure
      local project_dir = project.path
      
      -- Check directories
      expect(fs.directory_exists(project_dir)).to.equal(true)
      expect(fs.directory_exists(fs.join_paths(project_dir, "src"))).to.equal(true)
      expect(fs.directory_exists(fs.join_paths(project_dir, "tests"))).to.equal(true)
      expect(fs.directory_exists(fs.join_paths(project_dir, "docs"))).to.equal(true)
      
      -- Check files
      expect(fs.file_exists(fs.join_paths(project_dir, "README.md"))).to.equal(true)
      expect(fs.file_exists(fs.join_paths(project_dir, ".firmo-config.lua"))).to.equal(true)
      expect(fs.file_exists(fs.join_paths(project_dir, "src", "init.lua"))).to.equal(true)
      
      -- Check file contents
      local readme = fs.read_file(fs.join_paths(project_dir, "README.md"))
      expect(readme).to.match("# test%-project")
      
      local config = fs.read_file(fs.join_paths(project_dir, ".firmo-config.lua"))
      expect(config).to.match('name = "test%-project"')
      
      local init = fs.read_file(fs.join_paths(project_dir, "src", "init.lua"))
      expect(init).to.match('M%._VERSION = "0%.1%.0"')
      
      -- List all project files
      local files = list_project_files(project_dir)
      expect(#files).to.equal(3)
    end)
  end)
end)
```

### Example 16: Complete Test Suite

```lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("JSON Parser", function()
  local fs = require("lib.tools.filesystem")
  local error_handler = require("lib.tools.error_handler")
  
  -- Mock JSON parser module
  local json_parser = {
    parse = function(input)
      if type(input) ~= "string" then
        return nil, error_handler.validation_error(
          "Input must be a string",
          {
            input_type = type(input),
            function = "json_parser.parse"
          }
        )
      end
      
      -- Try to parse JSON
      local success, result = error_handler.try(function()
        -- Very simplified JSON parser for example purposes
        if input == "" then
          return nil, error_handler.parse_error(
            "Empty JSON string",
            {
              input = input,
              function = "json_parser.parse"
            }
          )
        end
        
        -- Check for basic JSON object
        if input:match("^%s*{") and input:match("}%s*$") then
          local parsed = {}
          for key, value in input:gmatch('"([^"]+)":%s*"([^"]+)"') do
            parsed[key] = value
          end
          for key, value in input:gmatch('"([^"]+)":%s*(%d+)') do
            parsed[key] = tonumber(value)
          end
          for key, value in input:gmatch('"([^"]+)":%s*(%b{})') do
            -- Recursive parsing for nested objects (simplified)
            parsed[key] = json_parser.parse(value)
          end
          return parsed
        end
        
        -- Check for basic JSON array
        if input:match("^%s*%[") and input:match("%]%s*$") then
          local parsed = {}
          for value in input:gmatch('"([^"]+)"') do
            table.insert(parsed, value)
          end
          for value in input:gmatch("(%d+)") do
            table.insert(parsed, tonumber(value))
          end
          return parsed
        end
        
        return nil, error_handler.parse_error(
          "Unsupported JSON format",
          {
            input = input,
            function = "json_parser.parse"
          }
        )
      end)
      
      if success then
        return result
      else
        return nil, result  -- Return the error object
      end
    end,
    
    stringify = function(obj)
      if type(obj) ~= "table" then
        return nil, error_handler.validation_error(
          "Object must be a table",
          {
            object_type = type(obj),
            function = "json_parser.stringify"
          }
        )
      end
      
      -- Try to stringify object
      local success, result = error_handler.try(function()
        -- Very simplified JSON stringifier for example purposes
        
        -- Check if it's an array
        local is_array = true
        local max_index = 0
        
        for k, _ in pairs(obj) do
          if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
            is_array = false
            break
          end
          max_index = math.max(max_index, k)
        end
        
        if is_array and max_index > 0 and max_index == #obj then
          -- It's an array
          local items = {}
          for i, v in ipairs(obj) do
            if type(v) == "string" then
              table.insert(items, '"' .. v .. '"')
            elseif type(v) == "number" then
              table.insert(items, tostring(v))
            elseif type(v) == "table" then
              local nested, err = json_parser.stringify(v)
              if not nested then
                return nil, err
              end
              table.insert(items, nested)
            else
              return nil, error_handler.validation_error(
                "Unsupported array value type",
                {
                  value_type = type(v),
                  function = "json_parser.stringify"
                }
              )
            end
          end
          return "[" .. table.concat(items, ", ") .. "]"
        else
          -- It's an object
          local items = {}
          for k, v in pairs(obj) do
            if type(k) ~= "string" then
              return nil, error_handler.validation_error(
                "Object keys must be strings",
                {
                  key_type = type(k),
                  function = "json_parser.stringify"
                }
              )
            end
            
            local value_str
            if type(v) == "string" then
              value_str = '"' .. v .. '"'
            elseif type(v) == "number" then
              value_str = tostring(v)
            elseif type(v) == "table" then
              local nested, err = json_parser.stringify(v)
              if not nested then
                return nil, err
              end
              value_str = nested
            else
              return nil, error_handler.validation_error(
                "Unsupported object value type",
                {
                  value_type = type(v),
                  function = "json_parser.stringify"
                }
              )
            end
            
            table.insert(items, '"' .. k .. '": ' .. value_str)
          end
          return "{" .. table.concat(items, ", ") .. "}"
        end
      end)
      
      if success then
        return result
      else
        return nil, result  -- Return the error object
      end
    end,
    
    parse_file = function(file_path)
      if type(file_path) ~= "string" then
        return nil, error_handler.validation_error(
          "File path must be a string",
          {
            path_type = type(file_path),
            function = "json_parser.parse_file"
          }
        )
      end
      
      -- Read file
      local content, read_err = fs.read_file(file_path)
      if not content then
        return nil, error_handler.io_error(
          "Failed to read JSON file",
          {
            file_path = file_path,
            function = "json_parser.parse_file"
          },
          read_err
        )
      end
      
      -- Parse content
      return json_parser.parse(content)
    end,
    
    write_file = function(file_path, obj)
      if type(file_path) ~= "string" then
        return nil, error_handler.validation_error(
          "File path must be a string",
          {
            path_type = type(file_path),
            function = "json_parser.write_file"
          }
        )
      end
      
      -- Stringify object
      local json_str, stringify_err = json_parser.stringify(obj)
      if not json_str then
        return nil, stringify_err
      end
      
      -- Write to file
      local success, write_err = fs.write_file(file_path, json_str)
      if not success then
        return nil, error_handler.io_error(
          "Failed to write JSON file",
          {
            file_path = file_path,
            function = "json_parser.write_file"
          },
          write_err
        )
      end
      
      return true
    end
  }
  
  -- Basic parsing tests
  describe("parse function", function()
    it("should parse simple object", function()
      local json = '{"name": "test", "value": 42}'
      local obj = json_parser.parse(json)
      
      expect(obj).to.exist()
      expect(obj.name).to.equal("test")
      expect(obj.value).to.equal(42)
    end)
    
    it("should parse simple array", function()
      local json = '["test", 42, "another"]'
      local arr = json_parser.parse(json)
      
      expect(arr).to.exist()
      expect(#arr).to.equal(3)
      expect(arr[1]).to.equal("test")
      expect(arr[2]).to.equal(42)
      expect(arr[3]).to.equal("another")
    end)
    
    it("should fail for non-string input", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return json_parser.parse(123)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.equal("Input must be a string")
      expect(err.category).to.equal("VALIDATION")
    end)
    
    it("should fail for empty JSON", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return json_parser.parse("")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.equal("Empty JSON string")
      expect(err.category).to.equal("PARSE")
    end)
  end)
  
  -- Stringification tests
  describe("stringify function", function()
    it("should stringify simple object", function()
      local obj = {name = "test", value = 42}
      local json = json_parser.stringify(obj)
      
      expect(json).to.exist()
      expect(json).to.match('{')
      expect(json).to.match('}')
      expect(json).to.match('"name": "test"')
      expect(json).to.match('"value": 42')
    end)
    
    it("should stringify simple array", function()
      local arr = {"test", 42, "another"}
      local json = json_parser.stringify(arr)
      
      expect(json).to.exist()
      expect(json).to.match('%[')
      expect(json).to.match('%]')
      expect(json).to.match('"test"')
      expect(json).to.match('42')
      expect(json).to.match('"another"')
    end)
    
    it("should fail for non-table input", { expect_error = true }, function()
      local result, err = test_helper.with_error_capture(function()
        return json_parser.stringify("not a table")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.equal("Object must be a table")
      expect(err.category).to.equal("VALIDATION")
    end)
  end)
  
  -- File I/O tests
  describe("file operations", function()
    -- Use test_helper for temp files
    it("should read and parse JSON file", function()
      -- Create test file
      local json_content = '{"name": "test", "value": 42}'
      local temp_file, err = test_helper.create_temp_file_with_content(json_content, "json")
      expect(err).to_not.exist("Failed to create temp file")
      
      -- Parse file
      local obj = json_parser.parse_file(temp_file)
      
      expect(obj).to.exist()
      expect(obj.name).to.equal("test")
      expect(obj.value).to.equal(42)
    end)
    
    it("should stringify and write JSON file", function()
      -- Create temp file path
      local temp_file, err = test_helper.create_temp_file("json")
      expect(err).to_not.exist("Failed to create temp file")
      
      -- Object to write
      local obj = {name = "test", value = 42}
      
      -- Write to file
      local success = json_parser.write_file(temp_file, obj)
      expect(success).to.equal(true)
      
      -- Read and verify content
      local content = fs.read_file(temp_file)
      expect(content).to.exist()
      
      -- Should be able to parse it back
      local parsed = json_parser.parse(content)
      expect(parsed.name).to.equal("test")
      expect(parsed.value).to.equal(42)
    end)
    
    it("should handle missing files", { expect_error = true }, function()
      -- Try to parse non-existent file
      local result, err = test_helper.with_error_capture(function()
        return json_parser.parse_file("nonexistent.json")
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.equal("Failed to read JSON file")
      expect(err.category).to.equal("IO")
    end)
    
    it("should handle IO errors with mocking", { expect_error = true }, function()
      -- Set up I/O mocking
      local restore = test_helper.mock_io({
        ["error%.json"] = {
          read = nil,
          error = "Permission denied"
        }
      })
      
      -- Try to parse file with simulated permission error
      local result, err = test_helper.with_error_capture(function()
        return json_parser.parse_file("error.json")
      end)()
      
      -- Verify error
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err.message).to.equal("Failed to read JSON file")
      expect(err.category).to.equal("IO")
      expect(err.context.file_path).to.equal("error.json")
      
      -- Restore original I/O functions
      restore()
    end)
  end)
  
  -- Integration tests with temp directory
  describe("integration tests", function()
    it("should handle complex JSON operations", function()
      test_helper.with_temp_test_directory({}, function(dir_path, _, test_dir)
        -- Create a complex object
        local config = {
          name = "test-project",
          version = "1.0.0",
          dependencies = {
            "module1",
            "module2"
          },
          settings = {
            debug = true,
            timeout = 30,
            paths = {
              "src",
              "tests"
            }
          }
        }
        
        -- Write to file
        local config_path = fs.join_paths(dir_path, "config.json")
        local write_success = json_parser.write_file(config_path, config)
        expect(write_success).to.equal(true)
        
        -- Read from file
        local read_config = json_parser.parse_file(config_path)
        expect(read_config).to.exist()
        
        -- Verify complex object structure
        expect(read_config.name).to.equal("test-project")
        expect(read_config.version).to.equal("1.0.0")
        expect(#read_config.dependencies).to.equal(2)
        expect(read_config.settings.debug).to.equal(true)
        expect(read_config.settings.timeout).to.equal(30)
        expect(#read_config.settings.paths).to.equal(2)
      end)
    end)
  end)
end)
```

These examples demonstrate the various features of the Test Helper module and how to use them effectively in different testing scenarios. By leveraging these capabilities, you can write more comprehensive, reliable, and maintainable tests.