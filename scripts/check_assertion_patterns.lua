#!/usr/bin/env lua
--
-- check_assertion_patterns.lua
-- Script to check for incorrect assertion patterns in the codebase
-- Usage: lua scripts/check_assertion_patterns.lua [directory]
--

local fs = require("lib.tools.filesystem")

-- Patterns to check for
local PATTERNS = {
    {
        name = "Numeric to.be",
        description = "Should use .to.equal() instead of .to.be() for numeric comparisons",
        pattern = "expect%([^)]+%).to%.be%(%s*%d+%s*[%),]",
        suggestion = "expect(value).to.equal(number)"
    },
    {
        name = "Numeric to_not.be",
        description = "Should use .to_not.equal() instead of .to_not.be() for numeric comparisons",
        pattern = "expect%([^)]+%).to_not%.be%(%s*%d+%s*[%),]",
        suggestion = "expect(value).to_not.equal(number)"
    },
    {
        name = "Boolean true comparison",
        description = "Should use .to.be_truthy() instead of .to.be(true)",
        pattern = "expect%([^)]+%).to%.be%(%s*true%s*[%),]",
        suggestion = "expect(value).to.be_truthy()"
    },
    {
        name = "Boolean false negation",
        description = "Should use .to_not.be_truthy() instead of .to.be(false)",
        pattern = "expect%([^)]+%).to%.be%(%s*false%s*[%),]",
        suggestion = "expect(value).to_not.be_truthy()"
    },
    {
        name = "Busted-style assert.equals",
        description = "Uses busted-style assert.equals instead of expect().to.equal()",
        pattern = "assert%.equals%(",
        suggestion = "expect(actual).to.equal(expected)"
    },
    {
        name = "Busted-style assert.is_true",
        description = "Uses busted-style assert.is_true instead of expect().to.be_truthy()",
        pattern = "assert%.is_true%(",
        suggestion = "expect(value).to.be_truthy()"
    },
    {
        name = "Busted-style assert.is_false",
        description = "Uses busted-style assert.is_false instead of expect().to_not.be_truthy()",
        pattern = "assert%.is_false%(",
        suggestion = "expect(value).to_not.be_truthy()"
    }
}

-- ANSI color codes
local colors = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    white = "\27[37m"
}

-- Function to check a file for incorrect assertion patterns
local function check_file(file_path)
    local content = fs.read_file(file_path)
    if not content then
        print(colors.red .. "Could not read file: " .. file_path .. colors.reset)
        return {}
    end
    
    local findings = {}
    local line_number = 1
    local lines = {}
    
    -- Split content into lines
    for line in content:gmatch("([^\n]*)\n?") do
        lines[line_number] = line
        line_number = line_number + 1
    end
    
    -- Check each line for each pattern
    for line_num, line in pairs(lines) do
        for _, pattern_def in ipairs(PATTERNS) do
            if line:match(pattern_def.pattern) then
                table.insert(findings, {
                    pattern = pattern_def.name,
                    description = pattern_def.description,
                    line_number = line_num,
                    line = line:gsub("^%s+", ""):gsub("%s+$", ""),
                    suggestion = pattern_def.suggestion,
                    file_path = file_path
                })
            end
        end
    end
    
    return findings
end

-- Function to scan a directory for test files
local function scan_directory(dir_path)
    local findings = {}
    local files = fs.discover_files({dir_path}, {"*.lua"})
    
    for _, file_path in ipairs(files) do
        -- Skip vendor directories and non-test files
        if not file_path:match("/vendor/") then
            local file_findings = check_file(file_path)
            
            if #file_findings > 0 then
                table.insert(findings, {
                    file_path = file_path,
                    findings = file_findings
                })
            end
        end
    end
    
    return findings
end

-- Main function
local function main()
    local dir_path = arg[1] or "tests"
    print(colors.cyan .. "Checking for assertion patterns in: " .. dir_path .. colors.reset)
    
    local findings = scan_directory(dir_path)
    
    -- Print findings
    if #findings == 0 then
        print(colors.green .. "No incorrect assertion patterns found!" .. colors.reset)
        return 0
    end
    
    -- Format output
    print(colors.yellow .. string.format("Found %d files with incorrect assertion patterns:", #findings) .. colors.reset)
    
    local total_issues = 0
    for _, file_data in ipairs(findings) do
        print(colors.blue .. "\nFile: " .. file_data.file_path .. colors.reset)
        
        for _, finding in ipairs(file_data.findings) do
            total_issues = total_issues + 1
            print(colors.yellow .. string.format("  Line %d: %s", finding.line_number, finding.pattern) .. colors.reset)
            print(colors.white .. string.format("    %s", finding.line) .. colors.reset)
            print(colors.green .. string.format("    Suggestion: %s", finding.suggestion) .. colors.reset)
        end
    end
    
    print(colors.red .. string.format("\nTotal issues found: %d in %d files", total_issues, #findings) .. colors.reset)
    return 1
end

-- Run main function
os.exit(main())