-- Test for processing large files with the static analyzer
local lust_next = require("lust-next")
local describe, it, expect = lust_next.describe, lust_next.it, lust_next.expect

-- Import modules for testing
local coverage = require("lib.coverage")
local fs = require("lib.tools.filesystem")
local static_analyzer = require("lib.coverage.static_analyzer")

describe("Large File Processing", function()
  
  it("should successfully analyze the largest file in the project", function()
    -- Process the largest file in our project: lust-next.lua
    local file_path = "/home/gregg/Projects/lua-library/lust-next/lust-next.lua"
    
    -- Time the operation
    local start_time = os.clock()
    
    -- Parse the file
    local ast, code_map = static_analyzer.parse_file(file_path)
    
    -- Calculate duration
    local duration = os.clock() - start_time
    print(string.format("Parsed lust-next.lua in %.2f seconds", duration))
    
    -- Verify results
    expect(ast).to.be.a("table")
    expect(code_map).to.be.a("table")
    
    -- Print some details about the file
    local line_count = 0
    for _ in pairs(code_map.lines) do
      line_count = line_count + 1
    end
    
    local executable_lines = static_analyzer.get_executable_lines(code_map)
    
    print(string.format("File stats - Total lines: %d, Executable lines: %d", 
      line_count, #executable_lines))
  end)
  
end)