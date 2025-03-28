-- firmo v3 coverage parser tests
local firmo = require("firmo")
local parser = require("lib.coverage.v3.instrumentation.parser")
local test_helper = require("lib.tools.test_helper")

local describe, it, expect = firmo.describe, firmo.it, firmo.expect

describe("Coverage v3 Parser", function()
  it("should parse simple Lua code", function()
    local source = [[
      local x = 1
      local y = 2
      return x + y
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(ast.tag).to.equal("Chunk")
  end)

  it("should preserve line numbers", function()
    local source = [[
      local x = 1 -- line 1
      
      local y = 2 -- line 3
      
      return x + y -- line 5
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    
    -- First statement should be on line 1
    expect(ast[1].pos).to.exist()
    expect(ast[1].line).to.equal(1)
    
    -- Last statement should be on line 5
    expect(ast[#ast].pos).to.exist()
    expect(ast[#ast].line).to.equal(5)
  end)

  it("should handle syntax errors gracefully", { expect_error = true }, function()
    local source = [[
      local x = -- incomplete statement
      return x
    ]]
    
    local result, err = test_helper.with_error_capture(function()
      return parser.parse(source)
    end)()
    
    expect(result).to_not.exist()
    expect(err).to.exist()
    expect(err.message).to.match("syntax error")
  end)

  it("should preserve comments", function()
    local source = [[
      -- Header comment
      local x = 1 -- Line comment
      --[[ Block
         comment ]]
      return x
    ]]
    
    local ast = parser.parse(source)
    expect(ast).to.exist()
    expect(ast.comments).to.exist()
    expect(#ast.comments).to.equal(3)
  end)
end)