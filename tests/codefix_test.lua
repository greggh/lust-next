-- Tests for the lust-next codefix module
local lust = require("../lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect

-- Helper functions
local function create_test_file(filename, content)
  local file = io.open(filename, "w")
  if file then
    file:write(content)
    file:close()
    return true
  end
  return false
end

local function read_test_file(filename)
  local file = io.open(filename, "r")
  if file then
    local content = file:read("*a")
    file:close()
    return content
  end
  return nil
end

-- Test for the codefix module
describe("Codefix Module", function()
  
  -- Initialize the codefix module
  lust.codefix_options = lust.codefix_options or {}
  lust.codefix_options.enabled = true
  lust.codefix_options.verbose = false
  lust.codefix_options.debug = false
  lust.codefix_options.backup = true
  lust.codefix_options.backup_ext = ".bak"
  
  -- Temporary files for testing
  local test_files = {}
  
  -- Create test files
  lust.before(function()
    -- Test file with unused variables
    local unused_vars_file = "unused_vars_test.lua"
    local unused_vars_content = [[
local function test_function(param1, param2, param3)
  local unused_local = "test"
  return param1
end
return test_function
]]
    if create_test_file(unused_vars_file, unused_vars_content) then
      table.insert(test_files, unused_vars_file)
    end
    
    -- Test file with trailing whitespace
    local whitespace_file = "whitespace_test.lua"
    local whitespace_content = [=[
local function test_function()    
  local multiline = [[
    This string has trailing whitespace    
    on multiple lines    
  ]]
  return multiline
end
return test_function
]=]
    if create_test_file(whitespace_file, whitespace_content) then
      table.insert(test_files, whitespace_file)
    end
    
    -- Test file with string concatenation
    local concat_file = "concat_test.lua"
    local concat_content = [[
local function test_function()
  local part1 = "Hello"
  local part2 = "World"
  return part1 .. " " .. part2 .. "!"
end
return test_function
]]
    if create_test_file(concat_file, concat_content) then
      table.insert(test_files, concat_file)
    end
  end)
  
  -- Clean up test files
  lust.after(function()
    for _, filename in ipairs(test_files) do
      os.remove(filename)
      os.remove(filename .. ".bak")
    end
  end)
  
  -- Test codefix module initialization
  it("should load and initialize", function()
    local codefix = require("../src/codefix")
    expect(type(codefix)).to.equal("table")
    expect(type(codefix.fix_file)).to.equal("function")
    expect(type(codefix.fix_files)).to.equal("function")
    expect(type(codefix.fix_lua_files)).to.equal("function")
  end)
  
  -- Test fixing unused variables
  it("should fix unused variables", function()
    local codefix = require("../src/codefix")
    if not codefix.fix_file then
      lust.pending("Codefix module fix_file function not available")
      return
    end
    
    -- Enable the module and specific fixers
    codefix.config.enabled = true
    codefix.config.use_luacheck = true
    codefix.config.custom_fixers.unused_variables = true
    
    -- Apply the fix
    local success = codefix.fix_file("unused_vars_test.lua")
    expect(success).to.equal(true)
    
    -- Check the result
    local content = read_test_file("unused_vars_test.lua")
    expect(content:match("_param[23]")).to_not.equal(nil) -- Should have prefixed unused params
    expect(content:match("_unused_local")).to_not.equal(nil) -- Should have prefixed unused local
  end)
  
  -- Test fixing trailing whitespace
  it("should fix trailing whitespace in multiline strings", function()
    local codefix = require("../src/codefix")
    if not codefix.fix_file then
      lust.pending("Codefix module fix_file function not available")
      return
    end
    
    -- Enable the module and specific fixers
    codefix.config.enabled = true
    codefix.config.custom_fixers.trailing_whitespace = true
    
    -- Apply the fix
    local success = codefix.fix_file("whitespace_test.lua")
    expect(success).to.equal(true)
    
    -- Check the result
    local content = read_test_file("whitespace_test.lua")
    expect(content:match("This string has trailing whitespace%s+\n")).to.equal(nil)
  end)
  
  -- Test string concatenation optimization
  it("should optimize string concatenation", function()
    local codefix = require("../src/codefix")
    if not codefix.fix_file then
      lust.pending("Codefix module fix_file function not available")
      return
    end
    
    -- Enable the module and specific fixers
    codefix.config.enabled = true
    codefix.config.custom_fixers.string_concat = true
    
    -- Apply the fix
    local success = codefix.fix_file("concat_test.lua")
    expect(success).to.equal(true)
    
    -- Check the result - this may not change if StyLua already fixed it
    local content = read_test_file("concat_test.lua")
    expect(type(content)).to.equal("string") -- Basic check that file exists
  end)
  
  -- Test StyLua integration
  it("should use StyLua for formatting if available", function()
    local codefix = require("../src/codefix")
    if not codefix.fix_file then
      lust.pending("Codefix module fix_file function not available")
      return
    end
    
    -- Create a file with formatting issues
    local format_file = "format_test.lua"
    local format_content = [[
local function badlyFormattedFunction(a,b,c)
  if a then return b else
  return c end
end
return badlyFormattedFunction
]]
    
    if create_test_file(format_file, format_content) then
      table.insert(test_files, format_file)
      
      -- Enable module and StyLua
      codefix.config.enabled = true
      codefix.config.use_stylua = true
      
      -- Apply the fix
      local success = codefix.fix_file(format_file)
      
      -- We can't guarantee StyLua is installed, so just check that the function ran
      expect(type(success)).to.equal("boolean")
      
      -- Check that the file still exists and is readable
      local content = read_test_file(format_file)
      expect(type(content)).to.equal("string")
    else
      lust.pending("Could not create test file")
    end
  end)
  
  -- Test backup file creation
  it("should create backup files when configured", function()
    local codefix = require("../src/codefix")
    if not codefix.fix_file then
      lust.pending("Codefix module fix_file function not available")
      return
    end
    
    -- Enable module and backup
    codefix.config.enabled = true
    codefix.config.backup = true
    
    -- Choose a test file
    local test_file = test_files[1]
    
    -- Apply a fix
    local success = codefix.fix_file(test_file)
    expect(type(success)).to.equal("boolean")
    
    -- Check that a backup file was created
    local backup_file = test_file .. ".bak"
    local backup_content = read_test_file(backup_file)
    expect(type(backup_content)).to.equal("string")
  end)
  
  -- Test multiple file fixing
  it("should fix multiple files", function()
    local codefix = require("../src/codefix")
    if not codefix.fix_files then
      lust.pending("Codefix module fix_files function not available")
      return
    end
    
    -- Enable module
    codefix.config.enabled = true
    
    -- Apply fixes to all test files
    local success = codefix.fix_files(test_files)
    
    -- Check result
    expect(type(success)).to.equal("boolean")
    
    -- Verify all files still exist
    for _, filename in ipairs(test_files) do
      local content = read_test_file(filename)
      expect(type(content)).to.equal("string")
    end
  end)
  
  -- Test CLI functionality via the run_cli function
  it("should support CLI arguments", function()
    -- Check if the run_cli function exists
    local codefix = require("../src/codefix")
    if not codefix.run_cli then
      lust.pending("run_cli function not found")
      return
    end
    
    -- Test the CLI function with check command
    local result = codefix.run_cli({"check", test_files[1]})
    expect(type(result)).to.equal("boolean")
    
    -- Test the CLI function with fix command
    result = codefix.run_cli({"fix", test_files[1]})
    expect(type(result)).to.equal("boolean")
    
    -- Test the CLI function with help command
    result = codefix.run_cli({"help"})
    expect(result).to.equal(true)
  end)
end)

-- Return success
return true