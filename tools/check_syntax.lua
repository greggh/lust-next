-- Simple script to check Lua syntax errors in a file
-- Usage: lua check_syntax.lua <file_path>

local file_path = arg[1]
if not file_path then
    print("Please provide a file path")
    os.exit(1)
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        print("Error: Could not open file " .. path)
        os.exit(1)
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function analyze_braces(content)
    local lines = {}
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    
    local function_stack = {}
    local open_blocks = 0
    
    for line_num, line in ipairs(lines) do
        -- Check for function starts
        if line:match("function[%s%(]") then
            table.insert(function_stack, {line = line_num, text = line})
            open_blocks = open_blocks + 1
        end
        
        -- Check for if/for/while/repeat blocks
        if line:match("if%s+") or line:match("for%s+") or line:match("while%s+") or 
           line:match("repeat%s+") or line:match("do%s*$") then
            open_blocks = open_blocks + 1
        end
        
        -- Check for end statements
        local end_count = 0
        for _ in line:gmatch("%send[%s%)%;,]") do
            end_count = end_count + 1
        end
        for _ in line:gmatch("%send$") do
            end_count = end_count + 1
        end
        open_blocks = open_blocks - end_count
        
        if end_count > 0 and #function_stack > 0 then
            table.remove(function_stack)
        end
        
        -- Check for suspicious closing braces that might be mistaken for 'end'
        if line:match("}%s*$") and not (line:match("{") or line:match("function") or 
                                     line:match("if") or line:match("for") or 
                                     line:match("while") or line:match("repeat")) then
            print(string.format("WARNING: Line %d has suspicious closing brace: %s", line_num, line))
        end
    end
    
    if open_blocks > 0 then
        print(string.format("WARNING: Unbalanced blocks: %d more 'function/if/for/while/repeat' than 'end'", open_blocks))
        for _, func in ipairs(function_stack) do
            print(string.format("  Unclosed function at line %d: %s", func.line, func.text))
        end
    elseif open_blocks < 0 then
        print(string.format("WARNING: Unbalanced blocks: %d more 'end' than 'function/if/for/while/repeat'", -open_blocks))
    else
        print("Block structure looks balanced")
    end
end

local content = read_file(file_path)
print("Analyzing file: " .. file_path)
analyze_braces(content)

-- Try to load the file and check for syntax errors
local result, err = loadfile(file_path)
if result then
    print("Syntax check passed: No syntax errors found")
else
    print("Syntax error found: " .. err)
end