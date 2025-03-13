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
    local project_root = fs.get_absolute_path(".")
    local file_path = fs.join_paths(project_root, "lust-next.lua")
    
    -- Time the operation
    local start_time = os.clock()
    
    -- Parse the file
    local ast, code_map = static_analyzer.parse_file(file_path)
    
    -- Calculate duration
    local duration = os.clock() - start_time
    lust_next.log.info({ 
      message = "Parsed large file", 
      file = file_path,
      duration_seconds = string.format("%.2f", duration)
    })
    
    -- Verify results
    expect(ast).to.be.a("table")
    expect(code_map).to.be.a("table")
    
    -- Print some details about the file
    local line_count = 0
    for _ in pairs(code_map.lines) do
      line_count = line_count + 1
    end
    
    local executable_lines = static_analyzer.get_executable_lines(code_map)
    
    lust_next.log.info({ 
      message = "File stats", 
      file = file_path,
      total_lines = line_count,
      executable_lines = #executable_lines
    })
  end)
  
end)