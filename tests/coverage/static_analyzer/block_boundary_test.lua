-- Block boundary detection test for static analyzer
local lust = require("lust-next")
local describe, it, expect = lust.describe, lust.it, lust.expect
local static_analyzer = require("lib.coverage.static_analyzer")
local filesystem = require("lib.tools.filesystem")
local temp_file = require("lib.tools.temp_file")
local logging = require("lib.tools.logging")

-- We'll use print statements for debugging

-- Helper function to create a test file and parse it
local function create_and_parse_file(content)
    local temp_path = temp_file.create_with_content(content, "lua")
    local ast, err = static_analyzer.parse_file(temp_path)
    if not ast then
        filesystem.delete_file(temp_path)
        return nil, err
    end
    
    local code_map = static_analyzer.get_code_map_for_ast(ast, temp_path)
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
        local result = create_and_parse_file(code)
        expect(result.ast).to.be.a("table")
        expect(result.code_map).to.be.a("table")
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Blocks should be analyzed successfully
        
        -- Should have at least one if block and function block
        local if_blocks = count_blocks_by_type(result.code_map.blocks, "If")
        local function_blocks = count_blocks_by_type(result.code_map.blocks, "Function")
        
        expect(if_blocks).to.be_greater_than(0)
        expect(function_blocks).to.be_greater_than(0)
        
        -- Cleanup
        filesystem.delete_file(result.path)
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
        local result = create_and_parse_file(code)
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Count different block types
        local if_blocks = count_blocks_by_type(result.code_map.blocks, "If")
        local while_blocks = count_blocks_by_type(result.code_map.blocks, "While")
        local function_blocks = count_blocks_by_type(result.code_map.blocks, "Function")
        
        expect(if_blocks).to.be_greater_than(1) -- Should have at least 2 if blocks
        expect(while_blocks).to.be_greater_than(0) -- Should have at least 1 while block
        expect(function_blocks).to.be_greater_than(0) -- Should have at least 1 function
        
        -- Cleanup
        filesystem.delete_file(result.path)
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
        local result = create_and_parse_file(code)
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
        
        -- Cleanup
        filesystem.delete_file(result.path)
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
        local result = create_and_parse_file(code)
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
        
        -- Cleanup
        filesystem.delete_file(result.path)
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
        local result = create_and_parse_file(code)
        expect(result.code_map.blocks).to.be.a("table")
        
        -- Should have lots of nested blocks
        expect(#result.code_map.blocks).to.be_greater_than(8)
        
        -- Validate that nesting is tracked properly
        -- (This needs enhancement in the static analyzer)
        
        -- Cleanup
        filesystem.delete_file(result.path)
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
        local result = create_and_parse_file(code)
        
        -- Find the if block
        local if_block = nil
        for _, block in ipairs(result.code_map.blocks) do
            if block.type == "If" then
                if_block = block
                break
            end
        end
        
        -- Find the while block
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
        
        -- Cleanup
        filesystem.delete_file(result.path)
    end)
end)