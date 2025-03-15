local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local static_analyzer = require("lib.coverage.static_analyzer")
local error_handler = require("lib.tools.error_handler")
local fs = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Helper function to create code map for test code
local function create_code_map_for_string(code_string)
    local temp_path = temp_file.create_with_content(code_string)
    local ast, err = static_analyzer.parse_file(temp_path)
    if not ast then
        fs.delete_file(temp_path)
        return nil, err
    end
    
    local code_map = static_analyzer.get_code_map_for_ast(ast, temp_path)
    fs.delete_file(temp_path)
    return code_map, nil
end

describe("Function Detection", function()
    describe("Basic Function Detection", function()
        it("should detect global functions", function()
            local code = [[
function hello_world()
    print("Hello World")
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("hello_world")
            expect(code_map.functions[1].line_start).to.equal(1)
        end)

        it("should detect local functions", function()
            local code = [[
local function hello_world()
    print("Hello World")
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("hello_world")
            expect(code_map.functions[1].line_start).to.equal(1)
        end)

        it("should detect anonymous functions", function()
            local code = [[
local handler = function()
    print("Anonymous function")
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("handler") -- Should extract from assignment
            expect(code_map.functions[1].line_start).to.equal(1)
        end)

        it("should detect truly anonymous functions", function()
            local code = [[
local result = (function()
    return "Anonymous function"
end)()
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("<anonymous>") -- No name to extract
            expect(code_map.functions[1].line_start).to.equal(1)
        end)
    end)

    describe("Complex Function Detection", function()
        it("should detect module functions", function()
            local code = [[
local M = {}
M.hello_world = function()
    print("Hello World")
end
return M
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("M.hello_world")
            expect(code_map.functions[1].line_start).to.equal(2)
        end)

        it("should detect nested functions", function()
            local code = [[
local function outer()
    local function inner()
        print("Inner function")
    end
    inner()
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(2)
            -- Functions should include both outer and inner
            local has_outer = false
            local has_inner = false
            for _, func in ipairs(code_map.functions) do
                if func.name == "outer" then
                    has_outer = true
                    expect(func.line_start).to.equal(1)
                elseif func.name == "inner" then
                    has_inner = true
                    expect(func.line_start).to.equal(2)
                end
            end
            expect(has_outer).to.be_truthy()
            expect(has_inner).to.be_truthy()
        end)

        it("should detect functions passed as arguments", function()
            local code = [[
local result = process(function(x)
    return x * 2
end)
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("<anonymous>")
            expect(code_map.functions[1].line_start).to.equal(1)
        end)

        it("should detect method definitions", function()
            local code = [[
local Class = {}
function Class:method()
    print("Method call")
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("Class:method")
            expect(code_map.functions[1].line_start).to.equal(2)
        end)

        it("should detect class-style table method definitions", function()
            local code = [[
local Class = {
    method = function(self)
        print("Method call")
    end
}
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].name).to.equal("Class.method")
            expect(code_map.functions[1].line_start).to.equal(2)
        end)
    end)

    describe("Function End Line Detection", function()
        it("should detect function end lines for simple functions", function()
            local code = [[
function simple()
    print("Line 2")
    print("Line 3")
end -- Line 4
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].line_end).to.equal(4)
        end)

        it("should detect function end lines for nested functions", function()
            local code = [[
function outer()
    print("Line 2")
    local function inner()
        print("Line 4")
    end -- Line 5
    print("Line 6")
end -- Line 7
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(2)
            
            -- Find the functions by name
            local outer_func = nil
            local inner_func = nil
            for _, func in ipairs(code_map.functions) do
                if func.name == "outer" then
                    outer_func = func
                elseif func.name == "inner" then
                    inner_func = func
                end
            end
            
            expect(outer_func).to.exist()
            expect(inner_func).to.exist()
            expect(outer_func.line_end).to.equal(7)
            expect(inner_func.line_end).to.equal(5)
        end)
    end)

    describe("Function Parameter Detection", function()
        it("should detect function parameters", function()
            local code = [[
function with_params(a, b, c)
    return a + b + c
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].params).to.exist()
            expect(#code_map.functions[1].params).to.equal(3)
            expect(code_map.functions[1].params[1]).to.equal("a")
            expect(code_map.functions[1].params[2]).to.equal("b")
            expect(code_map.functions[1].params[3]).to.equal("c")
        end)

        it("should handle varargs in parameters", function()
            local code = [[
function with_varargs(a, ...)
    return a
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(1)
            expect(code_map.functions[1].params).to.exist()
            expect(#code_map.functions[1].params).to.equal(2)
            expect(code_map.functions[1].params[1]).to.equal("a")
            expect(code_map.functions[1].params[2]).to.equal("...")
            expect(code_map.functions[1].has_varargs).to.be_truthy()
        end)
    end)

    describe("Function Type Detection", function()
        it("should identify function types", function()
            local code = [[
-- Global function
function global_func()
    print("Global")
end

-- Local function
local function local_func()
    print("Local")
end

-- Module function
local M = {}
M.module_func = function()
    print("Module")
end

-- Method
local Class = {}
function Class:method()
    print("Method")
end
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(4)
            
            -- Check function types
            local types = {}
            for _, func in ipairs(code_map.functions) do
                types[func.name] = func.type
            end
            
            expect(types["global_func"]).to.equal("global")
            expect(types["local_func"]).to.equal("local")
            expect(types["M.module_func"]).to.equal("module")
            expect(types["Class:method"]).to.equal("method")
        end)
    end)

    describe("Error Handling", function()
        it("should handle syntax errors gracefully", function()
            local code = [[
function broken_syntax(
    -- Missing closing parenthesis
    print("This will cause a syntax error")
end
]]
            local code_map, err = create_code_map_for_string(code)
            expect(code_map).to_not.exist()
            expect(err).to.exist()
            -- Check that it's a SYNTAX error type, or if not available, at least an error
            local has_syntax_category = false
            if err.category and error_handler.CATEGORY and error_handler.CATEGORY.SYNTAX then
                has_syntax_category = (err.category == error_handler.CATEGORY.SYNTAX)
            end
            expect(has_syntax_category or err.message:match("syntax") ~= nil).to.be_truthy()
        end)

        it("should handle empty input", function()
            local code_map, err = create_code_map_for_string("")
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(0)
        end)

        it("should handle input with no functions", function()
            local code = [[
local x = 1
local y = 2
return x + y
]]
            local code_map = create_code_map_for_string(code)
            expect(code_map).to.exist()
            expect(code_map.functions).to.exist()
            expect(#code_map.functions).to.equal(0)
        end)
    end)
end)
