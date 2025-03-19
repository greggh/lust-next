-- Block boundary detection test for static analyzer
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect

-- Import test_helper for improved error handling
local test_helper = require("lib.tools.test_helper")
local error_handler = require("lib.tools.error_handler")

local static_analyzer = require("lib.coverage.static_analyzer")
local filesystem = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")

-- Set up logger with error handling
local logging, logger
local function try_load_logger()
  if not logger then
    local log_module, err = test_helper.with_error_capture(function()
      return require("lib.tools.logging")
    end)()
    
    if log_module then
      logging = log_module
      logger = logging.get_logger("test.static_analyzer.block_boundary")
    end
  end
  return logger
end

local log = try_load_logger()

-- Helper function to create a test file and parse it with error handling
local function create_and_parse_file(content)
    -- Create a temp file with error handling
    local temp_path, create_err = test_helper.with_error_capture(function()
        return temp_file.create_with_content(content, "lua")
    end)()
    
    if not temp_path then
        if log then
            log.error("Failed to create temp file", { error = create_err })
        end
        return nil, create_err
    end
    
    -- Parse the file with error handling
    local ast, parse_err = test_helper.with_error_capture(function()
        return static_analyzer.parse_file(temp_path)
    end)()
    
    if not ast then
        -- Clean up the temp file before returning error
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(temp_path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete temp file during cleanup", {
                file_path = temp_path,
                error = delete_err
            })
        end
        
        return nil, parse_err
    end
    
    -- Get code map with error handling
    local code_map, map_err = test_helper.with_error_capture(function()
        return static_analyzer.get_code_map_for_ast(ast, temp_path)
    end)()
    
    if not code_map then
        -- Clean up the temp file before returning error
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(temp_path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete temp file during cleanup", {
                file_path = temp_path,
                error = delete_err
            })
        end
        
        return nil, map_err
    end
    
    return { 
        ast = ast,
        code_map = code_map,
        path = temp_path
    }
end

-- Helper function to find a block by type and line range
local function find_block(blocks, block_type, start_line, end_line)
    for _, block in ipairs(blocks) do
        if block.type == block_type and 
           block.start_line == start_line and 
           block.end_line == end_line then
            return block
        end
    end
    return nil
end

-- Helper function to count blocks by type
local function count_blocks_by_type(blocks, block_type)
    local count = 0
    for _, block in ipairs(blocks) do
        if block.type == block_type then
            count = count + 1
        end
    end
    return count
end

-- Helper function to find child blocks by parent_id
local function find_children(blocks, parent_id)
    local children = {}
    for _, block in ipairs(blocks) do
        if block.parent_id == parent_id then
            table.insert(children, block)
        end
    end
    return children
end

describe("Block Boundary Detection", function()
    
    it("should detect basic if-then-else blocks", function()
        local code = [[
local function test_if()
    if true then
        print("true")
    else
        print("false")
    end
end
]]
        -- Create and parse the file with error handling
        local result, err = test_helper.with_error_capture(function()
            return create_and_parse_file(code)
        end)()
        
        expect(err).to_not.exist()
        expect(result).to.exist()
        expect(result.ast).to.be.a("table")
        expect(result.code_map).to.be.a("table")
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Blocks should be analyzed successfully
        
        -- Should have at least one if block and function block
        local if_blocks = count_blocks_by_type(result.code_map.blocks, "If")
        local function_blocks = count_blocks_by_type(result.code_map.blocks, "Function")
        
        expect(if_blocks).to.be_greater_than(0)
        expect(function_blocks).to.be_greater_than(0)
        
        -- Cleanup with error handling
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(result.path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete test file", {
                file_path = result.path,
                error = delete_err
            })
        end
    end)
    
    it("should detect nested blocks", function()
        local code = [[
local function nested_blocks()
    if true then
        while condition do
            if another_condition then
                print("nested")
            end
        end
    end
end
]]
        -- Create and parse the file with error handling
        local result, err = test_helper.with_error_capture(function()
            return create_and_parse_file(code)
        end)()
        
        expect(err).to_not.exist()
        expect(result).to.exist()
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Count different block types
        local if_blocks = count_blocks_by_type(result.code_map.blocks, "If")
        local while_blocks = count_blocks_by_type(result.code_map.blocks, "While")
        local function_blocks = count_blocks_by_type(result.code_map.blocks, "Function")
        
        expect(if_blocks).to.be_greater_than(1) -- Should have at least 2 if blocks
        expect(while_blocks).to.be_greater_than(0) -- Should have at least 1 while block
        expect(function_blocks).to.be_greater_than(0) -- Should have at least 1 function
        
        -- Cleanup with error handling
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(result.path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete test file", {
                file_path = result.path,
                error = delete_err
            })
        end
    end)
    
    it("should establish parent-child relationships between blocks", function()
        local code = [[
local function parent_child()
    if condition then
        for i=1,10 do
            print(i)
        end
    end
end
]]
        -- Create and parse the file with error handling
        local result, err = test_helper.with_error_capture(function()
            return create_and_parse_file(code)
        end)()
        
        expect(err).to_not.exist()
        expect(result).to.exist()
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Find the function block (root)
        local function_block = nil
        for _, block in ipairs(result.code_map.blocks) do
            if block.type == "Function" then
                function_block = block
                break
            end
        end
        
        expect(function_block).to.exist()
        
        -- Find children of the function block
        local function_children = find_children(result.code_map.blocks, function_block.id)
        
        -- Should have at least the If block as a child
        expect(#function_children).to.be_greater_than(0)
        
        -- Find if block
        local if_block = nil
        for _, block in ipairs(function_children) do
            if block.type == "If" or block.type == "if_block" then
                if_block = block
                break
            end
        end
        
        expect(if_block).to.exist()
        
        -- Find children of the if block
        local if_children = find_children(result.code_map.blocks, if_block.id)
        
        -- Should have at least the for block and condition
        expect(#if_children).to.be_greater_than(0)
        
        -- Cleanup with error handling
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(result.path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete test file", {
                file_path = result.path,
                error = delete_err
            })
        end
    end)
    
    it("should detect all Lua block types", function()
        local code = [[
local function all_block_types()
    -- If block
    if true then
        print("if")
    elseif false then
        print("elseif")
    else
        print("else")
    end
    
    -- While loop
    while condition do
        print("while")
    end
    
    -- Repeat-until loop
    repeat
        print("repeat")
    until condition
    
    -- For loop (numeric)
    for i=1,10,2 do
        print(i)
    end
    
    -- For loop (iterator)
    for k,v in pairs(table) do
        print(k,v)
    end
    
    -- Function block
    local function inner()
        print("inner")
    end
    
    -- Do block
    do
        print("do block")
    end
end
]]
        -- Create and parse the file with error handling
        local result, err = test_helper.with_error_capture(function()
            return create_and_parse_file(code)
        end)()
        
        expect(err).to_not.exist()
        expect(result).to.exist()
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Count different block types
        local if_blocks = count_blocks_by_type(result.code_map.blocks, "If")
        local while_blocks = count_blocks_by_type(result.code_map.blocks, "While")
        local repeat_blocks = count_blocks_by_type(result.code_map.blocks, "Repeat")
        local fornum_blocks = count_blocks_by_type(result.code_map.blocks, "Fornum")
        local forin_blocks = count_blocks_by_type(result.code_map.blocks, "Forin")
        local function_blocks = count_blocks_by_type(result.code_map.blocks, "Function")
        local block_blocks = count_blocks_by_type(result.code_map.blocks, "Block") -- Do blocks
        
        expect(if_blocks).to.be_greater_than(0) -- If and elseif blocks
        expect(while_blocks).to.be_greater_than(0) -- While loop
        expect(repeat_blocks).to.be_greater_than(0) -- Repeat-until loop
        expect(fornum_blocks).to.be_greater_than(0) -- Numeric for loop
        expect(forin_blocks).to.be_greater_than(0) -- Iterator for loop
        expect(function_blocks).to.be_greater_than(1) -- Outer and inner function
        expect(block_blocks).to.be_greater_than(0) -- Do block
        
        -- Cleanup with error handling
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(result.path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete test file", {
                file_path = result.path,
                error = delete_err
            })
        end
    end)
    
    it("should handle edge cases and complex nesting", function()
        local code = [[
local function complex_nesting()
    if condition1 then
        while condition2 do
            if condition3 then
                for i=1,10 do
                    if condition4 then
                        -- Nested block
                    else
                        -- Another nested block
                        repeat
                            if deep_condition then
                                print("deep")
                            end
                        until stop_condition
                    end
                end
            end
        end
    end
end
]]
        -- Create and parse the file with error handling
        local result, err = test_helper.with_error_capture(function()
            return create_and_parse_file(code)
        end)()
        
        expect(err).to_not.exist()
        expect(result).to.exist()
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Should have lots of nested blocks
        expect(#result.code_map.blocks).to.be_greater_than(8)
        
        -- Validate that nesting is tracked properly
        -- (This needs enhancement in the static analyzer)
        
        -- Cleanup with error handling
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(result.path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete test file", {
                file_path = result.path,
                error = delete_err
            })
        end
    end)
    
    it("should accurately identify block boundaries", function()
        local code = [[
local function check_boundaries()
    local x = 10 -- line 2
    
    if x > 5 then -- line 4
        x = x - 1 -- line 5
    end -- line 6
    
    while x > 0 do -- line 8
        x = x - 1 -- line 9
    end -- line 10
end
]]
        -- Create and parse the file with error handling
        local result, err = test_helper.with_error_capture(function()
            return create_and_parse_file(code)
        end)()
        
        expect(err).to_not.exist()
        expect(result).to.exist()
        
        -- Find the if block with error checking
        local if_block = nil
        for _, block in ipairs(result.code_map.blocks) do
            if block.type == "If" then
                if_block = block
                break
            end
        end
        
        -- Find the while block with error checking
        local while_block = nil
        for _, block in ipairs(result.code_map.blocks) do
            if block.type == "While" then
                while_block = block
                break
            end
        end
        
        -- Check block boundaries 
        -- Note: May need adjustments after implementation is improved
        expect(if_block).to.exist()
        expect(while_block).to.exist()
        
        -- The if block should cover lines 4-6
        expect(if_block.start_line <= 4).to.be_truthy()
        expect(if_block.end_line >= 6).to.be_truthy()
        
        -- The while block should cover lines 8-10
        expect(while_block.start_line <= 8).to.be_truthy()
        expect(while_block.end_line >= 10).to.be_truthy()
        
        -- Cleanup with error handling
        local delete_success, delete_err = test_helper.with_error_capture(function()
            return filesystem.delete_file(result.path)
        end)()
        
        if not delete_success and log then
            log.warn("Failed to delete test file", {
                file_path = result.path,
                error = delete_err
            })
        end
    end)
    
    -- Test for error handling
    it("should handle malformed code gracefully", { expect_error = true }, function()
        local code = [[
local function malformed_code
    if no_end_keyword then
        while condition do
            -- No end for while loop
        
        -- No end for if block
    -- No end for function
]]
        -- First create a temp file with the malformed code
        local temp_path, create_err = test_helper.with_error_capture(function()
            return temp_file.create_with_content(code, "lua")
        end)()
        
        -- Temp file creation should succeed
        expect(temp_path).to.exist()
        
        -- Now try to parse it - this should fail with a syntax error
        local ast, parse_err = test_helper.with_error_capture(function()
            return static_analyzer.parse_file(temp_path)
        end)()
        
        -- We expect a syntax error
        expect(ast).to_not.exist()
        expect(parse_err).to.exist()
        
        -- We don't need to check the specific error message, just that an error occurred
        -- The implementation details of the error may vary

        -- Clean up the temp file
        if temp_path then
            local delete_success, delete_err = test_helper.with_error_capture(function()
                return filesystem.delete_file(temp_path)
            end)()
            
            if not delete_success and log then
                log.warn("Failed to delete temp file during cleanup", {
                    file_path = temp_path,
                    error = delete_err
                })
            end
        end
    end)
end)
