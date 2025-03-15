-- Test file for line classification in the static analyzer
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

-- Import modules
local static_analyzer = require("lib.coverage.static_analyzer")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")

describe("static_analyzer line classification", function()
  -- Setup and teardown
  before(function()
    -- Initialize the static analyzer with default settings
    static_analyzer.init()
    static_analyzer.clear_cache()
  end)
  
  after(function()
    -- Reset the static analyzer
    static_analyzer.clear_cache()
  end)
  
  -- Helper function to test line classification
  local function test_line_classification(code, expected_results)
    local ast, code_map = static_analyzer.parse_content(code, "inline")
    expect(ast).to.exist()
    expect(code_map).to.exist()
    
    -- Check each line's classification
    for line_num, expected_executable in pairs(expected_results) do
      local result = static_analyzer.is_line_executable(code_map, line_num)
      expect(result).to.equal(expected_executable, "Line " .. line_num .. " classification incorrect")
    end
  end
  
  describe("comments", function()
    it("should classify single-line comments as non-executable", function()
      local code = [=[
        -- This is a comment
        local a = 1 -- This is a comment after code
        --[[ This is a multi
        line comment ]]
        print("test")
      ]=]
      
      local expected = {
        [1] = false, -- Single line comment
        [2] = true,  -- Code with trailing comment
        [3] = false, -- Multiline comment start
        [4] = false, -- Multiline comment end
        [5] = true   -- Code
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should handle nested multiline comments", function()
      local code = [=[
        --[[ Outer comment
          --[[ Nested comment ]]
        end of outer comment ]]
        local a = 1
      ]=]
      
      local expected = {
        [1] = false, -- Multiline comment start
        [2] = false, -- Nested comment
        [3] = false, -- Multiline comment end
        [4] = true   -- Code
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should handle mixed code and comments", function()
      local code = [=[
        local a = 1 --[[ This is a
        multiline comment
        that continues ]] local b = 2
      ]=]
      
      local expected = {
        [1] = true,  -- Code with comment start
        [2] = false, -- Comment
        [3] = true   -- Comment end and code
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify empty lines and whitespace as non-executable", function()
      local code = [=[
        
           
        local a = 1
        
      ]=]
      
      local expected = {
        [1] = false, -- Empty line
        [2] = false, -- Whitespace only
        [3] = true,  -- Code
        [4] = false  -- Empty line
      }
      
      test_line_classification(code, expected)
    end)
  end)
  
  describe("control flow", function()
    it("should classify if/then/else/end structures correctly", function()
      local code = [=[
        if condition then
          statement1()
        else
          statement2()
        end
      ]=]
      
      local expected = {
        [1] = true, -- if condition then
        [2] = true, -- statement1()
        [3] = true, -- else
        [4] = true, -- statement2()
        [5] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify for loops correctly", function()
      local code = [=[
        for i=1,10 do
          print(i)
        end
      ]=]
      
      local expected = {
        [1] = true, -- for loop declaration
        [2] = true, -- body
        [3] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify while loops correctly", function()
      local code = [=[
        while condition do
          statement()
        end
      ]=]
      
      local expected = {
        [1] = true, -- while declaration
        [2] = true, -- body
        [3] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify repeat-until loops correctly", function()
      local code = [=[
        repeat
          statement()
        until condition
      ]=]
      
      local expected = {
        [1] = true, -- repeat
        [2] = true, -- body
        [3] = true  -- until condition
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify standalone control flow keywords (do/end) correctly", function()
      local code = [=[
        do
          statement()
        end
      ]=]
      
      local expected = {
        [1] = true, -- do
        [2] = true, -- body
        [3] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
  end)
  
  describe("function definitions", function()
    it("should classify local function definitions correctly", function()
      local code = [=[
        local function test()
          local a = 1
          return a
        end
      ]=]
      
      local expected = {
        [1] = true, -- function definition
        [2] = true, -- body
        [3] = true, -- return
        [4] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify global function definitions correctly", function()
      local code = [=[
        function test()
          local a = 1
          return a
        end
      ]=]
      
      local expected = {
        [1] = true, -- function definition
        [2] = true, -- body
        [3] = true, -- return
        [4] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify anonymous function assignments correctly", function()
      local code = [=[
        local f = function()
          local a = 1
          return a
        end
      ]=]
      
      local expected = {
        [1] = true, -- function assignment
        [2] = true, -- body
        [3] = true, -- return
        [4] = true  -- end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify table function definitions correctly", function()
      local code = [=[
        local t = {
          method = function()
            return true
          end
        }
      ]=]
      
      local expected = {
        [1] = true, -- table start
        [2] = true, -- function definition
        [3] = true, -- return
        [4] = true, -- function end
        [5] = true  -- table end
      }
      
      test_line_classification(code, expected)
    end)
  end)
  
  describe("table definitions", function()
    it("should classify table definitions correctly", function()
      local code = [=[
        local t = {
          key1 = "value1",
          key2 = "value2",
        }
      ]=]
      
      local expected = {
        [1] = true, -- table start
        [2] = true, -- key-value pair
        [3] = true, -- key-value pair
        [4] = true  -- table end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should classify array-style table definitions correctly", function()
      local code = [=[
        local t = {
          "value1",
          "value2",
        }
      ]=]
      
      local expected = {
        [1] = true, -- table start
        [2] = true, -- array item
        [3] = true, -- array item
        [4] = true  -- table end
      }
      
      test_line_classification(code, expected)
    end)
  end)
  
  describe("complex cases", function()
    it("should handle chained method calls correctly", function()
      local code = [=[
        result = obj:method1()
          :method2()
          :method3()
      ]=]
      
      local expected = {
        [1] = true, -- initial call
        [2] = true, -- chained call
        [3] = true  -- chained call
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should handle multi-line strings correctly", function()
      local code = [=[
        local s = [[
          This is a multi-line
          string that should not
          be considered executable
        ]]
        local t = 1
      ]=]
      
      local expected = {
        [1] = true,  -- string start
        [2] = false, -- string content
        [3] = false, -- string content
        [4] = false, -- string content
        [5] = true   -- code
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should handle multi-line function calls correctly", function()
      local code = [=[
        call_function(
          arg1,
          arg2,
          arg3
        )
      ]=]
      
      local expected = {
        [1] = true, -- call start
        [2] = true, -- argument
        [3] = true, -- argument
        [4] = true, -- argument
        [5] = true  -- call end
      }
      
      test_line_classification(code, expected)
    end)
    
    it("should handle require statements correctly", function()
      local code = [=[
        local module = require("path.to.module")
        local result = module.function()
      ]=]
      
      local expected = {
        [1] = true, -- require
        [2] = true  -- function call
      }
      
      test_line_classification(code, expected)
    end)
  end)
  
  -- Test control_flow_keywords_executable configuration
  describe("configuration", function()
    it("should classify end keywords based on configuration", function()
      -- Set control_flow_keywords_executable to false
      static_analyzer.init({ control_flow_keywords_executable = false })
      
      local code = [=[
        if true then
          print("test")
        end
      ]=]
      
      -- With control_flow_keywords_executable = false, 'end' should not be executable
      local expected_with_false = {
        [1] = true,  -- if line
        [2] = true,  -- body
        [3] = false  -- end - not executable with this config
      }
      
      test_line_classification(code, expected_with_false)
      
      -- Reset to default (control_flow_keywords_executable = true)
      static_analyzer.init()
      
      -- With control_flow_keywords_executable = true, 'end' should be executable
      local expected_with_true = {
        [1] = true, -- if line
        [2] = true, -- body
        [3] = true  -- end - executable with default config
      }
      
      test_line_classification(code, expected_with_true)
    end)
  end)
end)
