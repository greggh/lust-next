-- Parser module tests

local firmo = require("firmo")
local parser = require("lib.tools.parser")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

describe("Parser Module", function()
  describe("Basic Parsing", function()
    local code = [[
local function test(a, b, ...)
  local sum = a + b
  print("The sum is:", sum)

  if sum > 10 then
    return true
  else
    return false
  end
end

-- Call the function
test(5, 10)
]]
    
    it("should parse Lua code successfully", function()
      local ast = parser.parse(code, "test_code")
      expect(ast).to.exist()
    end)
    
    it("should pretty print the AST", function()
      local ast = parser.parse(code, "test_code")
      local pp_output = parser.pretty_print(ast)
      expect(pp_output).to.be.a("string")
      expect(pp_output).to_not.be.empty()
    end)
    
    it("should detect executable lines", function()
      local ast = parser.parse(code, "test_code")
      local executable_lines = parser.get_executable_lines(ast, code)
      
      expect(executable_lines).to.be.a("table")
      
      -- Count executable lines
      local count = 0
      for _ in pairs(executable_lines) do
        count = count + 1
      end
      
      -- We should have several executable lines in our sample
      expect(count).to.be_greater_than(3)
    end)
    
    it("should detect functions", function()
      local ast = parser.parse(code, "test_code")
      local functions = parser.get_functions(ast, code)
      
      expect(functions).to.be.a("table")
      expect(#functions).to.equal(1)  -- Our sample has one function
      
      local func = functions[1]
      expect(func.name).to.equal("test")
      expect(func.params).to.be.a("table")
      expect(#func.params).to.equal(2)  -- a, b parameters
      expect(func.is_vararg).to.be_truthy()  -- Has vararg ...
    end)
    
    it("should create code map", function()
      local code_map = parser.create_code_map(code, "test_code")
      
      expect(code_map).to.be.a("table")
      expect(code_map.valid).to.be_truthy()
      expect(code_map.source_lines).to.be_greater_than(0)
    end)
  end)
  
  describe("Error Handling", function()
    it("should handle syntax errors gracefully", { expect_error = true }, function()
      local invalid_code = [[
function broken(
  -- Missing closing parenthesis
  return 5
end
]]
      
      local ast, err = parser.parse(invalid_code, "invalid_code")
      expect(ast).to_not.exist()
      expect(err).to.exist()
    end)
  end)
end)