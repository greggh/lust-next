# Quality Validation Examples

This document provides example patterns for using Firmo's quality validation system.

## Basic Usage Examples

### Basic Quality Configuration

```lua
-- Example: basic_quality_configuration.lua
local firmo = require("firmo")

-- Enable quality validation
firmo.quality_options = {
  enabled = true,        -- Enable quality validation
  level = 2,             -- Require level 2 quality
  format = "html",       -- Generate HTML reports
  output = "./reports",  -- Output location
  strict = false         -- Don't fail on first issue
}

-- Run tests with quality validation enabled
firmo.run_discovered("./tests")

-- Generate a quality report
firmo.generate_quality_report("html", "./reports/quality.html")
```

### Command Line Usage

```bash
# Run with basic quality validation (level 1)
lua test.lua --quality tests/

# Specify quality level
lua test.lua --quality --quality-level=3 tests/

# Run with quality validation and generate HTML report
lua test.lua --quality --quality-level=2 --quality-format=html --quality-output=./reports/quality.html tests/

# Run with strict mode (fail on first quality issue)
lua test.lua --quality --quality-level=2 --quality-strict tests/
```

## Test Examples by Quality Level

### Level 1: Basic Quality

```lua
-- Example: level_1_quality.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Calculator implementation for testing
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end
}

-- Level 1 tests have a proper structure and at least one assertion per test
describe("Calculator - Level 1", function()
  it("adds two numbers", function()
    -- One simple assertion per test
    expect(calculator.add(2, 3)).to.equal(5)
  end)
  
  it("subtracts numbers", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
  end)
end)
```

### Level 2: Standard Quality

```lua
-- Example: level_2_quality.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Calculator implementation for testing
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then
      return nil, "Division by zero"
    end
    return a / b
  end
}

-- Level 2 tests have multiple assertions and different assertion types
describe("Calculator - Level 2", function()
  it("should add two numbers correctly", function()
    -- Multiple assertions
    expect(calculator.add(2, 3)).to.equal(5)
    expect(calculator.add(0, 5)).to.equal(5)
    
    -- Type checking assertion
    expect(calculator.add(10, 20)).to.be.a("number")
  end)
  
  it("should subtract properly", function()
    expect(calculator.subtract(5, 3)).to.equal(2)
    expect(calculator.subtract(10, 5)).to.equal(5)
    
    -- Test with negative numbers
    expect(calculator.subtract(5, 10)).to.equal(-5)
  end)
  
  -- Setup and teardown
  local test_values
  
  before(function()
    test_values = {a = 10, b = 2}
  end)
  
  after(function()
    test_values = nil
  end)
  
  it("should use setup values", function()
    expect(calculator.multiply(test_values.a, test_values.b)).to.equal(20)
  end)
end)
```

### Level 3: Comprehensive Quality

```lua
-- Example: level_3_quality.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper")

-- Calculator implementation for testing
local calculator = {
  add = function(a, b) return a + b end,
  subtract = function(a, b) return a - b end,
  multiply = function(a, b) return a * b end,
  divide = function(a, b)
    if b == 0 then
      return nil, "Division by zero"
    end
    return a / b
  end
}

-- Level 3 tests have nested contexts, error testing, and edge cases
describe("Calculator - Level 3", function()
  local calc
  
  -- Proper setup/teardown
  before(function()
    calc = calculator
  end)
  
  after(function()
    calc = nil
  end)
  
  -- Nested context for addition
  describe("when performing addition", function()
    it("should add two numbers", function()
      expect(calc.add(2, 3)).to.equal(5)
      expect(calc.add(0, 5)).to.equal(5)
      
      -- Test with type assertions
      expect(calc.add(2, 3)).to.be.a("number")
    end)
    
    it("should handle edge cases", function()
      -- Edge case testing
      expect(calc.add(0, 0)).to.equal(0)
      expect(calc.add(-5, 5)).to.equal(0)
      expect(calc.add(-5, -5)).to.equal(-10)
    end)
  end)
  
  -- Nested context for division
  describe("when performing division", function()
    it("should divide two numbers", function()
      expect(calc.divide(10, 2)).to.equal(5)
      expect(calc.divide(7, 2)).to.equal(3.5)
      
      -- Type assertion
      expect(calc.divide(10, 2)).to.be.a("number")
    end)
    
    it("should handle division with edge cases", function()
      expect(calc.divide(0, 5)).to.equal(0)
      expect(calc.divide(-10, 2)).to.equal(-5)
    end)
    
    it("should return error for division by zero", { expect_error = true }, function()
      -- Error handling test
      local result, err = test_helper.with_error_capture(function()
        return calc.divide(10, 0)
      end)()
      
      expect(result).to_not.exist()
      expect(err).to.exist()
      expect(err).to.match("Division by zero")
    end)
  end)
end)
```

### Level 4: Advanced Quality

```lua
-- Example: level_4_quality.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper")

-- UserService implementation for testing
local UserService = {}

-- Create the UserService constructor
function UserService.new(db_client)
  local service = {
    db = db_client,
    validate_id = function(id)
      if type(id) ~= "string" then return false end
      if #id < 3 or #id > 20 then return false end
      return id:match("^[a-zA-Z0-9_]+$") ~= nil
    end,
    get_user = function(self, id)
      if not self.validate_id(id) then
        return nil, "Invalid user ID format"
      end
      return self.db.get_user(id)
    end,
    create_user = function(self, user_data)
      if not user_data.username or #user_data.username < 3 then
        return nil, "Invalid username"
      end
      return self.db.create_user(user_data)
    end
  }
  return service
end

-- Level 4 tests have mocks, boundary tests, and performance testing
describe("UserService - Level 4", function()
  local user_service, db_mock
  
  before(function()
    -- Create a mock database client
    db_mock = firmo.mock("DatabaseClient")
    
    -- Configure mock behavior
    db_mock:when("get_user", "123").returns({
      id = "123",
      username = "test_user",
      email = "test@example.com"
    })
    
    db_mock:when("get_user", "999").returns(nil)
    
    db_mock:when("create_user", {
      username = "new_user",
      email = "new@example.com"
    }).returns({
      id = "456",
      username = "new_user",
      email = "new@example.com"
    })
    
    -- Create service with mock database
    user_service = UserService.new(db_mock)
  end)
  
  after(function()
    -- Reset the mock
    db_mock:reset()
    user_service = nil
  end)
  
  describe("when validating user IDs", function()
    it("should validate user ID format", function()
      -- Boundary testing for ID length
      expect(user_service.validate_id("12")).to.equal(false)
      expect(user_service.validate_id("123")).to.equal(true)
      expect(user_service.validate_id("12345678901234567890")).to.equal(true)
      expect(user_service.validate_id("123456789012345678901")).to.equal(false)
      
      -- Character validation
      expect(user_service.validate_id("abc_123")).to.equal(true)
      expect(user_service.validate_id("abc-123")).to.equal(false)
      expect(user_service.validate_id("abc@123")).to.equal(false)
    end)
  end)
  
  describe("when retrieving users", function()
    it("should retrieve an existing user", function()
      local user = user_service:get_user("123")
      
      expect(user).to.exist()
      expect(user.id).to.equal("123")
      expect(user.username).to.equal("test_user")
      
      -- Mock verification
      expect(db_mock:called_once()).to.be_truthy()
      expect(db_mock:called_with("get_user", "123")).to.be_truthy()
    end)
    
    it("should handle non-existent users", function()
      local user = user_service:get_user("999")
      
      expect(user).to_not.exist()
      
      -- Mock verification
      expect(db_mock:called_once()).to.be_truthy()
      expect(db_mock:called_with("get_user", "999")).to.be_truthy()
    end)
    
    it("should return error for invalid user ID", { expect_error = true }, function()
      local user, err = test_helper.with_error_capture(function()
        return user_service:get_user("a")
      end)()
      
      expect(user).to_not.exist()
      expect(err).to.match("Invalid user ID format")
      
      -- Verify the mock was NOT called (validation failed first)
      expect(db_mock:called()).to.equal(false)
    end)
    
    -- Performance test
    it("should retrieve users efficiently", function()
      -- Measure performance
      local start_time = os.clock()
      user_service:get_user("123")
      local end_time = os.clock()
      local duration = end_time - start_time
      
      -- Verify performance is acceptable
      expect(duration).to.be_less_than(0.01)
    end)
  end)
end)
```

### Level 5: Complete Quality

```lua
-- Example: level_5_quality.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper")

-- Authentication service implementation
local AuthService = {}

function AuthService.new(user_db, logger, options)
  local service = {
    db = user_db,
    logger = logger,
    options = options or {},
    login_attempts = {},
    
    validate_input = function(self, username, password)
      if type(username) ~= "string" or #username < 3 then
        return false, "Invalid username format"
      end
      
      if type(password) ~= "string" or #password < 8 then
        return false, "Password must be at least 8 characters"
      end
      
      -- Check for SQL injection
      if username:match("[;'\"=]") then
        self.logger.warn("Potential SQL injection attempt", { username = username })
        return false, "Invalid input characters"
      end
      
      return true
    end,
    
    check_rate_limit = function(self, username)
      local attempts = self.login_attempts[username] or 0
      local max_attempts = self.options.max_attempts or 5
      
      if attempts >= max_attempts then
        self.logger.warn("Rate limit applied", { username = username, attempts = attempts })
        return false, "Too many login attempts, please try again later"
      end
      
      return true
    end,
    
    authenticate = function(self, username, password)
      -- Validate input format
      local valid, err = self:validate_input(username, password)
      if not valid then
        return { success = false, error = err }
      end
      
      -- Check rate limiting
      local allowed, limit_err = self:check_rate_limit(username)
      if not allowed then
        return { success = false, error = limit_err }
      end
      
      -- Fixed-time user lookup to prevent timing attacks
      local user = self.db.find_by_username(username)
      
      -- Record attempt
      self.login_attempts[username] = (self.login_attempts[username] or 0) + 1
      
      -- Check credentials
      if user and self:verify_password(password, user.password_hash) then
        -- Success - reset attempts counter
        self.login_attempts[username] = 0
        self.logger.info("Successful login", { username = username })
        
        return {
          success = true,
          user = {
            id = user.id,
            username = user.username,
            roles = user.roles
          },
          token = self:generate_token(user)
        }
      else
        -- Failed login
        self.logger.warn("Failed login attempt", { username = username })
        
        -- Use consistent error message to prevent user enumeration
        return {
          success = false,
          error = "Invalid credentials"
        }
      end
    end,
    
    verify_password = function(self, password, hash)
      -- Simulate password verification with delay to prevent timing attacks
      -- In a real implementation, this would use bcrypt or similar
      os.execute("sleep 0.1")
      
      -- For this example, assume a simple comparison
      return hash == "hash_of_" .. password
    end,
    
    generate_token = function(self, user)
      -- Generate a JWT-like token (simplified for example)
      return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9." .. 
             "eyJpZCI6IjEyMyIsInVzZXJuYW1lIjoidGVzdF91c2VyIn0." ..
             "SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    end
  }
  
  return service
end

-- Level 5 tests include security, extensive mocking, and comprehensive API contract testing
describe("AuthService - Level 5", function()
  local auth_service, user_db, logger
  
  before(function()
    -- Create mocks
    user_db = firmo.mock("UserDatabase")
    logger = firmo.mock("Logger")
    
    -- Configure user_db mock
    user_db:when("find_by_username", "test_user").returns({
      id = "123",
      username = "test_user",
      password_hash = "hash_of_password123",
      roles = {"user"}
    })
    
    user_db:when("find_by_username", "admin_user").returns({
      id = "456",
      username = "admin_user",
      password_hash = "hash_of_admin_pass",
      roles = {"user", "admin"}
    })
    
    -- Non-existent user returns nil
    user_db:when("find_by_username", "unknown").returns(nil)
    
    -- Create service with mocks
    auth_service = AuthService.new(user_db, logger, {
      max_attempts = 3
    })
  end)
  
  after(function()
    -- Reset mocks
    user_db:reset()
    logger:reset()
    auth_service = nil
  end)
  
  describe("when validating input", function()
    it("should reject too short usernames", function()
      local result = auth_service:authenticate("ab", "password123")
      
      expect(result.success).to.equal(false)
      expect(result.error).to.match("Invalid username format")
      
      -- Verify logger was called
      expect(logger:called()).to.equal(false)
      
      -- Verify database was not accessed
      expect(user_db:called()).to.equal(false)
    end)
    
    it("should reject too short passwords", function()
      local result = auth_service:authenticate("test_user", "short")
      
      expect(result.success).to.equal(false)
      expect(result.error).to.match("Password must be at least 8 characters")
      
      -- Verify database was not accessed
      expect(user_db:called()).to.equal(false)
    end)
    
    it("should detect SQL injection attempts", function()
      local result = auth_service:authenticate("user' OR 1=1 --", "password123")
      
      expect(result.success).to.equal(false)
      expect(result.error).to.match("Invalid input characters")
      
      -- Verify logger was called with warning
      expect(logger:called_with("warn", "Potential SQL injection attempt")).to.be_truthy()
      
      -- Verify database was not accessed
      expect(user_db:called()).to.equal(false)
    end)
  end)
  
  describe("when authenticating users", function()
    it("should successfully authenticate valid users", function()
      local result = auth_service:authenticate("test_user", "password123")
      
      expect(result.success).to.be_truthy()
      expect(result.user).to.exist()
      expect(result.user.id).to.equal("123")
      expect(result.user.username).to.equal("test_user")
      expect(result.user.roles[1]).to.equal("user")
      expect(result.token).to.be.a("string")
      expect(#result.token).to.be_greater_than(20)
      
      -- Verify logger was called
      expect(logger:called_with("info", "Successful login")).to.be_truthy()
      
      -- Verify database was queried
      expect(user_db:called_with("find_by_username", "test_user")).to.be_truthy()
    end)
    
    it("should reject invalid passwords", function()
      local result = auth_service:authenticate("test_user", "wrong_password")
      
      expect(result.success).to.equal(false)
      expect(result.error).to.match("Invalid credentials")
      expect(result.user).to_not.exist()
      expect(result.token).to_not.exist()
      
      -- Verify logger was called with warning
      expect(logger:called_with("warn", "Failed login attempt")).to.be_truthy()
    end)
    
    it("should handle non-existent users", function()
      local result = auth_service:authenticate("unknown", "password123")
      
      expect(result.success).to.equal(false)
      expect(result.error).to.match("Invalid credentials")
      
      -- Check that database was called
      expect(user_db:called_with("find_by_username", "unknown")).to.be_truthy()
    end)
  end)
  
  describe("security requirements", function()
    it("should enforce rate limiting", function()
      -- Make multiple failed login attempts
      for i = 1, 3 do
        auth_service:authenticate("test_user", "wrong_password" .. i)
      end
      
      -- Next attempt should be rate limited
      local result = auth_service:authenticate("test_user", "password123")
      
      expect(result.success).to.equal(false)
      expect(result.error).to.match("Too many login attempts")
      
      -- Verify logger was called
      expect(logger:called_with("warn", "Rate limit applied")).to.be_truthy()
    end)
    
    it("should differentiate between roles", function()
      local result = auth_service:authenticate("admin_user", "admin_pass")
      
      expect(result.success).to.be_truthy()
      expect(result.user.roles).to.include("admin")
      
      -- Verify exact roles
      expect(#result.user.roles).to.equal(2)
      expect(result.user.roles[1]).to.equal("user")
      expect(result.user.roles[2]).to.equal("admin")
    end)
    
    it("should provide identical timing regardless of user existence", { skip = true }, function()
      -- Note: This test has been marked as "skip" since it involves timing measurement
      -- that might be unreliable in certain environments
      
      -- Measure timing for existing user with wrong password
      local start1 = os.clock()
      auth_service:authenticate("test_user", "wrong_password")
      local duration1 = os.clock() - start1
      
      -- Measure timing for non-existent user
      local start2 = os.clock()
      auth_service:authenticate("nonexistent", "password123")
      local duration2 = os.clock() - start2
      
      -- Timing should be similar to prevent user enumeration attacks
      -- In real tests, we'd use a more sophisticated timing comparison
      expect(math.abs(duration1 - duration2)).to.be_less_than(0.05)
    end)
  end)
end)
```

## Error Handling Examples

The Quality module requires robust error handling patterns in your tests. Here are examples of how to properly implement error handling:

### Error Handling in Test Setup

```lua
-- Example: error_handling_in_setup.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper")
local temp_file = require("lib.tools.temp_file")

describe("Quality module error handling", function()
  -- Track created resources for cleanup
  local test_files = {}
  local logger
  
  -- Set up logger with error handling
  before(function()
    -- Initialize logger with error handling
    local logger_init_success, result = pcall(function()
      local logging = require("lib.tools.logging")
      logger = logging.get_logger("test.quality")
      return true
    end)
    
    if not logger_init_success then
      print("Warning: Failed to initialize logger: " .. tostring(result))
      -- Create a minimal logger as fallback
      logger = {
        debug = function() end,
        info = function() end,
        warn = function(msg) print("WARN: " .. msg) end,
        error = function(msg) print("ERROR: " .. msg) end
      }
    end
    
    -- Load the quality module with error handling
    local quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module: " .. tostring(load_error))
    expect(quality).to.exist()
    
    -- Create test files with proper error handling
    for level = 1, 3 do
      local content = [[
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Test with quality level ]] .. level .. [[", function()
  it("should pass a simple test", function()
    expect(1 + 1).to.equal(2)
    expect("test").to.be.a("string")
  end)
end)
]]
      
      local file_path, create_err = temp_file.create_with_content(content, "lua")
      expect(create_err).to_not.exist("Failed to create test file: " .. tostring(create_err))
      table.insert(test_files, file_path)
    end
  end)
  
  -- Clean up with error handling
  after(function()
    for _, file_path in ipairs(test_files) do
      -- Remove file with error handling
      local success, err = pcall(function()
        temp_file.remove(file_path)
      end)
      
      if not success and logger then
        logger.warn("Failed to remove test file: " .. tostring(err))
      end
    end
    
    -- Always clear the list
    test_files = {}
  end)
  
  -- The rest of the test cases...
end)
```

### Testing Error Conditions

```lua
-- Example: testing_error_conditions.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local test_helper = require("lib.tools.test_helper")

describe("Quality module error cases", function()
  -- Load quality module with error handling
  local quality
  
  before(function()
    local load_error
    quality, load_error = test_helper.with_error_capture(function()
      return require("lib.quality")
    end)()
    
    expect(load_error).to_not.exist("Failed to load quality module")
    expect(quality).to.exist()
  end)
  
  -- Test handling of non-existent files
  it("should handle missing files gracefully", { expect_error = true }, function()
    -- Try to check a non-existent file
    local result, err = test_helper.with_error_capture(function()
      return quality.check_file("non_existent_file.lua", 1)
    end)()
    
    -- The check should either return false or an error
    if result ~= nil then
      expect(result).to.equal(false, "check_file should return false for non-existent files")
    else
      expect(err).to.exist("check_file should return an error for non-existent files")
    end
  end)
  
  -- Test handling of invalid quality levels
  it("should handle invalid quality levels", { expect_error = true }, function()
    -- Try a negative quality level
    local result1, err1 = test_helper.with_error_capture(function()
      return quality.set_level(-1)
    end)()
    
    expect(result1).to_not.exist("set_level should not accept negative values")
    expect(err1).to.exist("set_level should error on negative values")
    
    -- Try a quality level that's too high
    local result2, err2 = test_helper.with_error_capture(function()
      return quality.set_level(10)
    end)()
    
    expect(result2).to_not.exist("set_level should not accept values > 5")
    expect(err2).to.exist("set_level should error on values > 5")
  end)
  
  -- Test input validation in helper functions
  it("should validate input parameters", { expect_error = true }, function()
    local helper_function = function(file_path, quality_level)
      -- Validate parameters
      if not file_path or file_path == "" then
        return nil, "Invalid file path"
      end
      
      if not quality_level or type(quality_level) ~= "number" or 
         quality_level < 1 or quality_level > 5 then
        return nil, "Invalid quality level: must be between 1 and 5"
      end
      
      return true
    end
    
    -- Test with invalid file path
    local result1, err1 = test_helper.with_error_capture(function()
      return helper_function("", 3)
    end)()
    
    expect(result1).to_not.exist("Function should reject empty file path")
    expect(err1).to.match("Invalid file path")
    
    -- Test with invalid quality level
    local result2, err2 = test_helper.with_error_capture(function()
      return helper_function("test.lua", 0)
    end)()
    
    expect(result2).to_not.exist("Function should reject invalid quality level")
    expect(err2).to.match("Invalid quality level")
  end)
end)
```

## Quality Reporting Examples

### Creating Quality Reports with Error Handling

```lua
-- Example: generate_quality_reports.lua
local firmo = require("firmo")
local test_helper = require("lib.tools.test_helper")
local fs = require("lib.tools.filesystem") 

-- Load modules with error handling
local quality, quality_err = test_helper.with_error_capture(function()
  return require("lib.quality")
end)()

if quality_err then
  print("Error loading quality module: " .. tostring(quality_err))
  os.exit(1)
end

-- Configure quality
firmo.quality_options = {
  enabled = true,
  level = 3,
  format = "html"
}

-- Run tests with quality validation and error handling
local success, run_err = pcall(function()
  return firmo.run_discovered("./tests")
end)

if not success then
  print("Error running tests: " .. tostring(run_err))
  os.exit(1)
end

-- Create reports directory with error handling
local report_dir = "./reports"
local dir_exists = fs.directory_exists(report_dir)
if not dir_exists then
  local create_success, create_err = fs.create_directory(report_dir)
  if not create_success then
    print("Error creating reports directory: " .. tostring(create_err))
    report_dir = "." -- Fallback to current directory
  end
end

-- Generate various report formats with error handling
local function generate_report(format, path)
  local report_success, report_err = pcall(function()
    return firmo.generate_quality_report(format, path)
  end)
  
  if not report_success then
    print("Error generating " .. format .. " report: " .. tostring(report_err))
    return false
  end
  
  print("Successfully generated " .. format .. " report at " .. path)
  return true
end

generate_report("html", report_dir .. "/quality.html")
generate_report("json", report_dir .. "/quality.json")

-- Get a summary as a string with error handling
local summary_success, summary = pcall(function()
  return firmo.generate_quality_report("summary")
end)

if summary_success then
  print("\nQuality Summary:")
  print(summary)
else
  print("Error generating summary: " .. tostring(summary))
end
```

### Programmatic Quality Checking

```lua
-- Example: programmatic_quality_checking.lua
local firmo = require("firmo")

-- Start quality validation with custom configuration
firmo.start_quality({
  level = 4,
  strict = true,
  custom_rules = {
    min_assertions_per_test = 3,
    require_mock_verification = true,
    require_error_assertions = true
  }
})

-- Run specific test file
firmo.run_file("tests/api_tests.lua")

-- Stop quality validation
firmo.stop_quality()

-- Check if quality meets level
if firmo.quality_meets_level(4) then
  print("Tests meet quality level 4!")
else
  print("Tests do not meet quality level 4")
  
  -- Get quality data to analyze issues
  local quality_data = firmo.get_quality_data()
  
  -- Print problem areas
  print("\nQuality Issues:")
  for _, issue in ipairs(quality_data.issues) do
    print("  - " .. issue.test .. ": " .. issue.message)
  end
  
  -- Print statistics
  print("\nQuality Statistics:")
  print("  Tests analyzed: " .. quality_data.summary.tests_analyzed)
  print("  Assertions total: " .. quality_data.summary.assertions_total)
  print("  Assertions per test: " .. string.format("%.2f", quality_data.summary.assertions_per_test_avg))
  print("  Quality score: " .. string.format("%.2f%%", quality_data.summary.quality_percent))
end
```

### Custom Quality Rules

```lua
-- Example: custom_quality_rules.lua
local firmo = require("firmo")

-- Define custom quality rules
firmo.quality_options.custom_rules = {
  -- Test structure requirements
  require_describe_block = true,
  require_it_block = true,
  max_nesting_level = 3,
  
  -- Assertion requirements
  min_assertions_per_test = 2,
  max_assertions_per_test = 8,
  required_assertion_types = {"equality", "type", "error"},
  
  -- Naming requirements
  test_name_pattern = "^should_",
  test_name_max_length = 60,
  
  -- Organization requirements
  require_before_after = true,
  require_context_blocks = true,
  
  -- Coverage requirements
  min_line_coverage = 85,
  min_branch_coverage = 75,
  
  -- Advanced requirements
  require_mock_verification = true,
  require_error_assertions = true,
  require_performance_assertions = true,
  require_security_tests = true,
  
  -- Documentation requirements
  require_test_description_comments = true,
  require_covers_annotations = true
}

-- Run tests with custom quality rules
firmo.run_discovered("./tests")

-- Generate quality report
firmo.generate_quality_report("html", "./reports/custom_quality.html")
```

### Integrating with CI/CD

```lua
-- Example: ci_integration.lua
local firmo = require("firmo")
local fs = require("lib.tools.filesystem")

-- Configure quality validation for CI environment
firmo.quality_options = {
  enabled = true,
  level = 3,
  format = "json",
  output = "./ci-reports",
  strict = true
}

print("Running tests with quality validation...")

-- Run all tests
local success = firmo.run_discovered("./tests")

-- Generate a comprehensive quality report
local report_path = "./ci-reports/quality-report.json"
firmo.generate_quality_report("json", report_path)

-- Check if quality meets required level
if not firmo.quality_meets_level(3) then
  print("FAILURE: Tests do not meet quality level 3")
  
  -- Read the report to get detailed information
  local report_content = fs.read_file(report_path)
  local quality_data = JSON.decode(report_content) -- Assume JSON library
  
  -- Output key statistics for CI log
  print("Quality score: " .. quality_data.score .. "%")
  print("Tests passing quality: " .. quality_data.tests_passing_quality .. " / " .. quality_data.tests_analyzed)
  
  -- Output top issues
  print("\nTop quality issues:")
  for i = 1, math.min(5, #quality_data.issues) do
    print("  " .. i .. ". " .. quality_data.issues[i].test .. ": " .. quality_data.issues[i].issue)
  end
  
  os.exit(1) -- Fail the CI build
else
  print("SUCCESS: Tests meet quality level 3")
  
  -- Generate HTML report for human review
  firmo.generate_quality_report("html", "./ci-reports/quality-report.html")
  
  print("Quality report generated at ./ci-reports/quality-report.html")
end
```

## Complete End-to-End Example

```lua
-- Example: complete_quality_usage.lua
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after
local test_helper = require("lib.tools.test_helper")

-- Enable quality validation with level 4 requirements
firmo.quality_options = {
  enabled = true,
  level = 4,
  format = "html",
  output = "./reports",
  strict = false
}

-- Define a UserRepository for testing
local UserRepository = {}

function UserRepository.new(db_connection)
  local repo = {
    db = db_connection,
    
    get_user = function(self, id)
      return self.db.query("SELECT * FROM users WHERE id = ?", id)[1]
    end,
    
    find_by_username = function(self, username)
      return self.db.query("SELECT * FROM users WHERE username = ?", username)[1]
    end,
    
    create_user = function(self, user_data)
      if not user_data.username or #user_data.username < 3 then
        return nil, "Username must be at least 3 characters"
      end
      
      if not user_data.email or not user_data.email:match(".+@.+%.%w+") then
        return nil, "Invalid email format"
      end
      
      -- Check if username exists
      local existing = self:find_by_username(user_data.username)
      if existing then
        return nil, "Username already exists"
      end
      
      -- Insert user
      local id = self.db.insert("users", user_data)
      user_data.id = id
      
      return user_data
    end,
    
    update_user = function(self, id, user_data)
      local user = self:get_user(id)
      if not user then
        return nil, "User not found"
      end
      
      -- Update user
      self.db.update("users", user_data, "id = ?", id)
      
      -- Return updated user
      return self:get_user(id)
    end,
    
    delete_user = function(self, id)
      local user = self:get_user(id)
      if not user then
        return false, "User not found"
      end
      
      -- Delete user
      self.db.delete("users", "id = ?", id)
      
      return true
    end
  }
  
  return repo
end

-- Comprehensive test suite with level 4 quality 
describe("UserRepository", function()
  local user_repo, db_mock, logger_mock
  
  -- Setup/teardown with database mock
  before(function()
    -- Create mock database
    db_mock = firmo.mock("Database")
    logger_mock = firmo.mock("Logger")
    
    -- Configure mock responses
    db_mock:when("query", "SELECT * FROM users WHERE id = ?", "123").returns({
      {id = "123", username = "test_user", email = "test@example.com", role = "user"}
    })
    
    db_mock:when("query", "SELECT * FROM users WHERE id = ?", "999").returns({})
    
    db_mock:when("query", "SELECT * FROM users WHERE username = ?", "test_user").returns({
      {id = "123", username = "test_user", email = "test@example.com", role = "user"}
    })
    
    db_mock:when("query", "SELECT * FROM users WHERE username = ?", "new_user").returns({})
    
    db_mock:when("insert", "users", {
      username = "new_user",
      email = "new@example.com",
      role = "user"
    }).returns("456")
    
    db_mock:when("update", "users", {email = "updated@example.com"}, "id = ?", "123").returns(1)
    
    db_mock:when("delete", "users", "id = ?", "123").returns(1)
    db_mock:when("delete", "users", "id = ?", "999").returns(0)
    
    -- Create repository with mock
    user_repo = UserRepository.new(db_mock)
  end)
  
  after(function()
    -- Reset mocks
    db_mock:reset()
    logger_mock:reset()
    user_repo = nil
  end)
  
  -- Group tests by context
  describe("when retrieving users", function()
    it("should get user by ID", function()
      local user = user_repo:get_user("123")
      
      -- Type assertion
      expect(user).to.be.a("table")
      
      -- Property assertions
      expect(user.id).to.equal("123")
      expect(user.username).to.equal("test_user")
      expect(user.email).to.equal("test@example.com")
      
      -- Mock verification
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE id = ?", "123")).to.be_truthy()
    end)
    
    it("should return nil for non-existent user", function()
      local user = user_repo:get_user("999")
      
      -- Existence assertion
      expect(user).to_not.exist()
      
      -- Mock verification
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE id = ?", "999")).to.be_truthy()
    end)
    
    it("should find user by username", function()
      local user = user_repo:find_by_username("test_user")
      
      -- Type assertion
      expect(user).to.be.a("table")
      
      -- Property assertions
      expect(user.id).to.equal("123")
      expect(user.username).to.equal("test_user")
      
      -- Mock verification
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE username = ?", "test_user")).to.be_truthy()
    end)
    
    -- Boundary test
    it("should handle edge cases in user retrieval", function()
      -- Empty string ID
      local user1 = user_repo:get_user("")
      expect(user1).to_not.exist()
      
      -- Nil ID
      local user2 = user_repo:get_user(nil)
      expect(user2).to_not.exist()
    end)
    
    -- Performance test
    it("should retrieve users efficiently", function()
      local start_time = os.clock()
      user_repo:get_user("123")
      local end_time = os.clock()
      local duration = end_time - start_time
      
      -- Performance assertion
      expect(duration).to.be_less_than(0.01)
    end)
  end)
  
  describe("when creating users", function()
    it("should create a valid user", function()
      local user, err = user_repo:create_user({
        username = "new_user",
        email = "new@example.com",
        role = "user"
      })
      
      -- Error assertion
      expect(err).to_not.exist()
      
      -- Result assertions
      expect(user).to.exist()
      expect(user.id).to.equal("456")
      expect(user.username).to.equal("new_user")
      
      -- Mock verification
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE username = ?", "new_user")).to.be_truthy()
      expect(db_mock:called_with("insert", "users", {
        username = "new_user",
        email = "new@example.com",
        role = "user"
      })).to.be_truthy()
    end)
    
    it("should validate username length", { expect_error = true }, function()
      local user, err = test_helper.with_error_capture(function()
        return user_repo:create_user({
          username = "ab",  -- Too short
          email = "short@example.com",
          role = "user"
        })
      end)()
      
      -- Error assertions
      expect(user).to_not.exist()
      expect(err).to.match("Username must be at least 3 characters")
      
      -- Mock verification - database should NOT be called for invalid data
      expect(db_mock:called_with("insert")).to.equal(false)
    end)
    
    it("should validate email format", { expect_error = true }, function()
      local user, err = test_helper.with_error_capture(function()
        return user_repo:create_user({
          username = "invalid_email",
          email = "not-an-email",  -- Invalid format
          role = "user"
        })
      end)()
      
      -- Error assertions
      expect(user).to_not.exist()
      expect(err).to.match("Invalid email format")
      
      -- Mock verification - database should NOT be called for invalid data
      expect(db_mock:called_with("insert")).to.equal(false)
    end)
    
    it("should prevent duplicate usernames", { expect_error = true }, function()
      local user, err = test_helper.with_error_capture(function()
        return user_repo:create_user({
          username = "test_user",  -- Already exists
          email = "another@example.com",
          role = "user"
        })
      end)()
      
      -- Error assertions
      expect(user).to_not.exist()
      expect(err).to.match("Username already exists")
      
      -- Mock verification - should check for existing user but not insert
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE username = ?", "test_user")).to.be_truthy()
      expect(db_mock:called_with("insert")).to.equal(false)
    end)
  end)
  
  describe("when updating users", function()
    it("should update an existing user", function()
      local updated_user = user_repo:update_user("123", {email = "updated@example.com"})
      
      -- Result assertions
      expect(updated_user).to.exist()
      expect(updated_user.email).to.equal("test@example.com")  -- Mock doesn't actually update the data
      
      -- Mock verification
      expect(db_mock:called_with("update", "users", {email = "updated@example.com"}, "id = ?", "123")).to.be_truthy()
    end)
    
    it("should handle non-existent user for update", { expect_error = true }, function()
      local user, err = test_helper.with_error_capture(function()
        return user_repo:update_user("999", {email = "none@example.com"})
      end)()
      
      -- Error assertions
      expect(user).to_not.exist()
      expect(err).to.match("User not found")
      
      -- Mock verification - should check for user but not update
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE id = ?", "999")).to.be_truthy()
      expect(db_mock:called_with("update")).to.equal(false)
    end)
  end)
  
  describe("when deleting users", function()
    it("should delete an existing user", function()
      local success, err = user_repo:delete_user("123")
      
      -- Result assertions
      expect(success).to.be_truthy()
      expect(err).to_not.exist()
      
      -- Mock verification
      expect(db_mock:called_with("delete", "users", "id = ?", "123")).to.be_truthy()
    end)
    
    it("should handle non-existent user for deletion", { expect_error = true }, function()
      local success, err = test_helper.with_error_capture(function()
        return user_repo:delete_user("999")
      end)()
      
      -- Error assertions
      expect(success).to.equal(false)
      expect(err).to.match("User not found")
      
      -- Mock verification - should check for user but not actually delete
      expect(db_mock:called_with("query", "SELECT * FROM users WHERE id = ?", "999")).to.be_truthy()
    end)
  end)
end)

-- Run tests and generate quality report
firmo.generate_quality_report("html", "./reports/user_repository_quality.html")

print("Quality validation complete. Report generated at ./reports/user_repository_quality.html")
```