--[[
    quality_filesystem_integration.lua - Example showing quality module using filesystem module
    
    This example demonstrates the integration between the quality module and
    the filesystem module for test file analysis and reporting.
    
    Run this example with:
    lua examples/quality_filesystem_integration.lua
]]

local quality = require("lib.quality")
local fs = require("lib.tools.filesystem")

print("Quality Module with Filesystem Integration")
print("-----------------------------------------\n")

-- Set up quality configuration
quality.config.enabled = true
quality.config.level = 2 -- Standard level
quality.init()

-- Analyze test files
print("Analyzing test files...")
local test_dir = "tests"
local lua_files = fs.discover_files({test_dir}, {"*.lua"}, {})

-- Analyze each test file
local results = {}
for _, file_path in ipairs(lua_files) do
    print("  Analyzing: " .. file_path)
    local analysis = quality.analyze_file(file_path)
    table.insert(results, analysis)
end

-- Print summary of results
print("\nAnalysis results:")
print("  Files analyzed: " .. #results)

local quality_levels = {}
for i = 1, 5 do
    quality_levels[i] = 0
end

for _, result in ipairs(results) do
    local level = result.quality_level
    quality_levels[level] = quality_levels[level] + 1
end

print("\nQuality level distribution:")
for i = 1, 5 do
    print("  Level " .. i .. " (" .. quality.get_level_name(i) .. "): " .. quality_levels[i] .. " files")
end

-- Generate and save a quality report
print("\nGenerating quality report...")
local report_path = "/tmp/quality-report.html"
local success, err = quality.save_report(report_path, "html")

if success then
    print("Quality report saved to: " .. report_path)
else
    print("Error saving report: " .. (err or "unknown error"))
end

print("\nReport content stats:")
local report_content = fs.read_file(report_path)
if report_content then
    print("  Report size: " .. #report_content .. " bytes")
    print("  Report lines: " .. select(2, report_content:gsub("\n", "\n")))
else
    print("  Unable to read report")
end

print("\nDone!")