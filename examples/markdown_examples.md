# Markdown Module Examples

This document provides practical examples of using the Firmo markdown module to fix and improve Markdown formatting in documentation files. These examples show how to use the module for different use cases and workflow scenarios.

## Table of Contents

- [Basic Usage Examples](#basic-usage-examples)
- [Formatting Specific Issues](#formatting-specific-issues)
- [Working with Multiple Files](#working-with-multiple-files)
- [Integration with Codefix](#integration-with-codefix)
- [Advanced Usage Examples](#advanced-usage-examples)
- [Workflow Integration Examples](#workflow-integration-examples)
- [Complete Examples](#complete-examples)

## Basic Usage Examples

### Example 1: Fix a Single File

```lua
local markdown = require("lib.tools.markdown")

-- Fix a specific markdown file
local success, err = markdown.fix_file("docs/README.md")

if success then
  print("README.md fixed successfully")
else
  print("Error fixing README.md: " .. (err and err.message or "unknown error"))
end
```

### Example 2: Fix Content Directly

```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Read the content
local content, read_err = fs.read_file("docs/guide.md")
if not content then
  print("Error reading file: " .. (read_err or "unknown error"))
  return
end

-- Apply comprehensive fixes
local fixed_content, fix_err = markdown.fix_comprehensive(content)
if not fixed_content then
  print("Error fixing content: " .. (fix_err and fix_err.message or "unknown error"))
  return
end

-- Check if content was changed
if content == fixed_content then
  print("No changes needed for guide.md")
else
  -- Write the fixed content back
  local success, write_err = fs.write_file("docs/guide.md", fixed_content)
  if not success then
    print("Error writing file: " .. (write_err or "unknown error"))
    return
  end
  print("guide.md fixed successfully")
end
```

### Example 3: Find Markdown Files

```lua
local markdown = require("lib.tools.markdown")

-- Find all markdown files in the docs directory
local files, err = markdown.find_markdown_files("docs")

if not files then
  print("Error finding markdown files: " .. (err and err.message or "unknown error"))
  return
end

print("Found " .. #files .. " markdown files:")
for i, file_path in ipairs(files) do
  print("  " .. i .. ". " .. file_path)
end
```

## Formatting Specific Issues

### Example 4: Fix Heading Levels

```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Original content with incorrect heading structure
local content = [[
# Main Title

Some intro text.

### This is a heading that skips H2 level

Content under this section.

#### Subsection that's too deep

More content.

## Now back at H2

Conclusion.
]]

-- Fix heading levels
local fixed_content = markdown.fix_heading_levels(content)

print("Original content:")
print(content)
print("\nFixed content:")
print(fixed_content)

-- Expected output will have proper heading hierarchy:
-- # Main Title (h1)
-- ## This is a heading that skips H2 level (changed from h3 to h2)
-- ### Subsection that's too deep (changed from h4 to h3)
-- ## Now back at H2 (unchanged)
```

### Example 5: Fix List Numbering

```lua
local markdown = require("lib.tools.markdown")

-- Original content with incorrect list numbering
local content = [[
Here's a list:

1. First item
1. Second item
1. Third item

Another list:
1. Item A
3. Item B
7. Item C

Nested list:
1. Main item 1
   1. Sub item 1
   1. Sub item 2
2. Main item 2
   5. Wrong numbering here
   6. Another wrong number
]]

-- Fix list numbering
local fixed_content = markdown.fix_list_numbering(content)

print("Original content:")
print(content)
print("\nFixed content:")
print(fixed_content)

-- Expected output will have sequential numbering for all lists
```

### Example 6: Fix Code Blocks and Spacing

```lua
local markdown = require("lib.tools.markdown")

-- Original content with spacing and code block issues
local content = [[
# Heading
Text immediately after heading without space.
## Another heading
* List item 1
* List item 2
Text immediately after list without space.

```
Code block without language specifier
```

Text immediately after code block.]]

-- Apply comprehensive fixes
local fixed_content = markdown.fix_comprehensive(content)

print("Original content:")
print(content)
print("\nFixed content:")
print(fixed_content)

-- Expected output will have proper spacing around all elements
-- and proper code block formatting
```

## Working with Multiple Files

### Example 7: Fix All Files in a Directory

```lua
local markdown = require("lib.tools.markdown")

-- Fix all markdown files in the docs directory
local fixed_count, err = markdown.fix_all_in_directory("docs")

if err then
  print("Error fixing markdown files: " .. err.message)
else
  print("Fixed " .. fixed_count .. " files in docs directory")
end
```

### Example 8: Process Files with Custom Logic

```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Find all markdown files first
local files, find_err = markdown.find_markdown_files("docs")

if not files then
  print("Error finding markdown files: " .. (find_err and find_err.message or "unknown error"))
  return
end

-- Process each file with custom logic
local fixed_count = 0
local error_count = 0

for _, file_path in ipairs(files) do
  -- Read file content
  local content, read_err = fs.read_file(file_path)
  if not content then
    print("Error reading " .. file_path .. ": " .. (read_err or "unknown error"))
    error_count = error_count + 1
    goto continue
  end
  
  -- Check if file needs formatting
  if not content:match("# Table of Contents") then
    -- Generate table of contents
    local toc = markdown.generate_table_of_contents(content)
    
    -- Add TOC to beginning of document
    content = "# Table of Contents\n\n" .. toc .. "\n\n" .. content
    
    -- Apply other fixes
    local fixed_content = markdown.fix_comprehensive(content)
    
    -- Write fixed content back
    local success, write_err = fs.write_file(file_path, fixed_content)
    if not success then
      print("Error writing " .. file_path .. ": " .. (write_err or "unknown error"))
      error_count = error_count + 1
    else
      print("Added TOC and fixed formatting in " .. file_path)
      fixed_count = fixed_count + 1
    end
  end
  
  ::continue::
end

print("Summary: fixed " .. fixed_count .. " files, encountered " .. error_count .. " errors")
```

## Integration with Codefix

### Example 9: Register with Codefix

```lua
local codefix = require("lib.tools.codefix")
local markdown = require("lib.tools.markdown")

-- Configure codefix
codefix.config.enabled = true
codefix.config.verbose = true

-- Register markdown fixer with codefix
local result, err = markdown.register_with_codefix(codefix)

if not result then
  print("Error registering markdown fixer: " .. (err and err.message or "unknown error"))
  return
end

print("Markdown fixer registered with codefix")
```

### Example 10: Use Codefix to Fix Markdown Files

```lua
local codefix = require("lib.tools.codefix")
local markdown = require("lib.tools.markdown")

-- Register markdown with codefix
markdown.register_with_codefix(codefix)

-- Fix a single markdown file using codefix
local success = codefix.fix_file("docs/README.md")
if success then
  print("README.md fixed successfully using codefix")
else
  print("Error fixing README.md with codefix")
end

-- Fix all markdown files in a directory
local files_success, files_results = codefix.fix_lua_files("docs", {
  include = { "%.md$" },
  exclude = { "node_modules", "%.git" }
})

if files_success then
  print("Fixed all markdown files in docs directory using codefix")
else
  print("Some markdown files could not be fixed")
  for _, result in ipairs(files_results) do
    if not result.success then
      print("Failed to fix: " .. result.file)
    end
  end
end
```

## Advanced Usage Examples

### Example 11: Extract and Analyze Heading Structure

```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Read the file
local content, read_err = fs.read_file("docs/guide.md")
if not content then
  print("Error reading file: " .. (read_err or "unknown error"))
  return
end

-- Extract headings
local headings = markdown.extract_headings(content)

-- Display heading structure
print("Heading structure in docs/guide.md:")
for i, heading in ipairs(headings) do
  print(string.rep("  ", heading.level - 1) .. 
        "- " .. heading.text .. " (Level h" .. heading.level .. ", Line " .. heading.line .. ")")
end

-- Find problems in heading structure
local problems = {}
local prev_level = 0

for i, heading in ipairs(headings) do
  if i == 1 and heading.level > 1 then
    table.insert(problems, "Document doesn't start with h1 heading")
  elseif heading.level > prev_level + 1 then
    table.insert(problems, "Heading level jump from h" .. prev_level .. 
                  " to h" .. heading.level .. " at line " .. heading.line)
  end
  prev_level = heading.level
end

if #problems > 0 then
  print("\nHeading structure problems:")
  for _, problem in ipairs(problems) do
    print("- " .. problem)
  end
else
  print("\nHeading structure is valid")
end
```

### Example 12: Generate Table of Contents

```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Read the file
local content, read_err = fs.read_file("docs/guide.md")
if not content then
  print("Error reading file: " .. (read_err or "unknown error"))
  return
end

-- Check if TOC already exists
if content:match("# Table of Contents") or content:match("## Table of Contents") then
  print("Table of contents already exists in the document")
  return
end

-- Extract headings
local headings = markdown.extract_headings(content)

-- Generate TOC
local toc = "## Table of Contents\n\n"

for i, heading in ipairs(headings) do
  -- Skip the main title and the TOC itself
  if i == 1 or heading.text == "Table of Contents" then
    goto continue
  end
  
  -- Add indentation based on heading level
  local indent = string.rep("  ", heading.level - 2)
  
  -- Create anchor link (lowercase with hyphens)
  local anchor = heading.text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
  
  -- Add TOC entry
  toc = toc .. indent .. "- [" .. heading.text .. "](#" .. anchor .. ")\n"
  
  ::continue::
end

-- Insert TOC after first heading
local content_with_toc = content:gsub("(# [^\n]+\n\n)", "%1" .. toc .. "\n")

-- Write back to file
local success, write_err = fs.write_file("docs/guide.md", content_with_toc)
if not success then
  print("Error writing file: " .. (write_err or "unknown error"))
  return
end

print("Added table of contents to docs/guide.md")
```

### Example 13: Validate Markdown

```lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Read the file
local content, read_err = fs.read_file("docs/guide.md")
if not content then
  print("Error reading file: " .. (read_err or "unknown error"))
  return
end

-- Validate markdown
local is_valid, issues = markdown.validate_markdown(content)

if not is_valid then
  print("Markdown validation failed for docs/guide.md:")
  for _, issue in ipairs(issues) do
    print("Line " .. issue.line .. ": " .. issue.message)
  end
  
  -- Ask user if they want to automatically fix issues
  io.write("Would you like to automatically fix these issues? (y/n) ")
  local answer = io.read():lower()
  
  if answer == "y" or answer == "yes" then
    -- Apply comprehensive fixes
    local fixed_content = markdown.fix_comprehensive(content)
    
    -- Write back to file
    local success, write_err = fs.write_file("docs/guide.md", fixed_content)
    if success then
      print("Fixed markdown issues in docs/guide.md")
    else
      print("Error writing file: " .. (write_err or "unknown error"))
    end
  end
else
  print("Markdown validation passed for docs/guide.md")
end
```

## Workflow Integration Examples

### Example 14: Pre-commit Hook

```lua
-- pre-commit.lua
local markdown = require("lib.tools.markdown")

-- Get list of staged markdown files from git
local function get_staged_markdown_files()
  local handle = io.popen("git diff --cached --name-only --diff-filter=ACM | grep '\\.md$'")
  if not handle then
    return {}
  end
  
  local result = handle:read("*a")
  handle:close()
  
  local files = {}
  for file in result:gmatch("[^\r\n]+") do
    table.insert(files, file)
  end
  
  return files
end

-- Main function
local function main()
  local files = get_staged_markdown_files()
  
  if #files == 0 then
    print("No staged markdown files found")
    return 0
  end
  
  print("Found " .. #files .. " staged markdown files")
  
  -- Fix each file and add back to staging
  local fixed_count = 0
  for _, file in ipairs(files) do
    print("Fixing " .. file)
    local success, err = markdown.fix_file(file)
    
    if success then
      fixed_count = fixed_count + 1
      -- Add fixed file back to git staging
      os.execute("git add " .. file)
    else
      print("Error fixing " .. file .. ": " .. (err and err.message or "unknown error"))
    end
  end
  
  print("Fixed " .. fixed_count .. " of " .. #files .. " markdown files")
  return 0
end

os.exit(main())
```

### Example 15: Continuous Integration Check

```lua
-- ci-check.lua
local markdown = require("lib.tools.markdown")

-- Function to check all markdown files
local function check_markdown_files(dir)
  local files, err = markdown.find_markdown_files(dir)
  if not files then
    print("Error finding markdown files: " .. (err and err.message or "unknown error"))
    return false
  end
  
  print("Checking " .. #files .. " markdown files...")
  local invalid_count = 0
  
  for _, file in ipairs(files) do
    local content, read_err = require("lib.tools.filesystem").read_file(file)
    if not content then
      print("Error reading " .. file .. ": " .. (read_err or "unknown error"))
      invalid_count = invalid_count + 1
    else
      local is_valid, issues = markdown.validate_markdown(content)
      
      if not is_valid then
        print("Invalid markdown in " .. file .. ":")
        for _, issue in ipairs(issues) do
          print("  Line " .. issue.line .. ": " .. issue.message)
        end
        invalid_count = invalid_count + 1
      end
    end
  end
  
  if invalid_count > 0 then
    print("Found " .. invalid_count .. " invalid markdown files")
    return false
  else
    print("All markdown files passed validation")
    return true
  end
end

-- Main function
local function main()
  local success = check_markdown_files("docs")
  return success and 0 or 1
end

os.exit(main())
```

### Example 16: Editor Integration

```lua
-- markdown-on-save.lua
local markdown = require("lib.tools.markdown")
local fs = require("lib.tools.filesystem")

-- Function to watch for file changes
local function watch_file(file_path, callback)
  local last_modified = fs.get_modification_time(file_path)
  
  -- Check file periodically
  while true do
    local current_modified = fs.get_modification_time(file_path)
    
    if current_modified > last_modified then
      callback(file_path)
      last_modified = current_modified
    end
    
    -- Sleep for a short time
    os.execute("sleep 1")
  end
end

-- Format markdown file on save
local function format_on_save(file_path)
  if not file_path:match("%.md$") then
    return
  end
  
  print("File changed: " .. file_path)
  local success, err = markdown.fix_file(file_path)
  
  if success then
    print("Formatted " .. file_path)
  else
    print("Error formatting " .. file_path .. ": " .. (err and err.message or "unknown error"))
  end
end

-- Main function
local function main()
  local file_path = arg[1]
  if not file_path then
    print("Usage: lua markdown-on-save.lua <file-path>")
    return 1
  end
  
  print("Watching for changes to " .. file_path)
  watch_file(file_path, format_on_save)
  return 0
end

main()
```

## Complete Examples

### Example 17: Documentation Build System

```lua
-- build-docs.lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Configuration
local config = {
  source_dir = "docs-src",
  output_dir = "docs",
  generate_toc = true,
  fix_markdown = true,
  validate = true
}

-- Function to process a single markdown file
local function process_markdown_file(source_path, dest_path)
  print("Processing " .. source_path)
  
  -- Read source file
  local content, read_err = fs.read_file(source_path)
  if not content then
    print("Error reading " .. source_path .. ": " .. (read_err or "unknown error"))
    return false
  end
  
  -- Validate if configured
  if config.validate then
    local is_valid, issues = markdown.validate_markdown(content)
    if not is_valid then
      print("Validation issues in " .. source_path .. ":")
      for _, issue in ipairs(issues) do
        print("  Line " .. issue.line .. ": " .. issue.message)
      end
    end
  end
  
  -- Fix markdown if configured
  if config.fix_markdown then
    content = markdown.fix_comprehensive(content)
  end
  
  -- Generate TOC if configured
  if config.generate_toc and not content:match("# Table of Contents") then
    local toc = markdown.generate_table_of_contents(content)
    content = "# Table of Contents\n\n" .. toc .. "\n\n" .. content
  end
  
  -- Create output directory if it doesn't exist
  local dest_dir = dest_path:match("(.+)/[^/]+$")
  if dest_dir and not fs.directory_exists(dest_dir) then
    fs.create_directory(dest_dir, true)
  end
  
  -- Write to destination
  local success, write_err = fs.write_file(dest_path, content)
  if not success then
    print("Error writing " .. dest_path .. ": " .. (write_err or "unknown error"))
    return false
  end
  
  print("  --> " .. dest_path)
  return true
end

-- Function to process all markdown files
local function process_all_markdown_files()
  -- Create output directory if it doesn't exist
  if not fs.directory_exists(config.output_dir) then
    fs.create_directory(config.output_dir, true)
  end
  
  -- Find all markdown files
  local files, find_err = markdown.find_markdown_files(config.source_dir)
  if not files then
    print("Error finding markdown files: " .. (find_err and find_err.message or "unknown error"))
    return false
  end
  
  print("Processing " .. #files .. " markdown files...")
  local success_count = 0
  
  for _, source_path in ipairs(files) do
    -- Calculate destination path
    local rel_path = source_path:sub(#config.source_dir + 2)
    local dest_path = config.output_dir .. "/" .. rel_path
    
    if process_markdown_file(source_path, dest_path) then
      success_count = success_count + 1
    end
  end
  
  print("Successfully processed " .. success_count .. " of " .. #files .. " files")
  return success_count == #files
end

-- Main function
local function main()
  print("Building documentation...")
  print("  Source: " .. config.source_dir)
  print("  Destination: " .. config.output_dir)
  
  local success = process_all_markdown_files()
  return success and 0 or 1
end

os.exit(main())
```

### Example 18: Documentation Quality Check

```lua
-- check-docs-quality.lua
local fs = require("lib.tools.filesystem")
local markdown = require("lib.tools.markdown")

-- Configuration
local config = {
  docs_dir = "docs",
  required_sections = {
    "Introduction",
    "Installation",
    "Usage",
    "API Reference",
    "Examples"
  },
  min_word_count = 300,
  require_code_examples = true,
  max_heading_level = 4
}

-- Count words in text
local function count_words(text)
  local count = 0
  for _ in text:gmatch("%S+") do
    count = count + 1
  end
  return count
end

-- Check if text has code examples
local function has_code_examples(text)
  return text:match("```lua") ~= nil
end

-- Check heading levels
local function check_heading_levels(headings)
  local max_level = 0
  local issues = {}
  
  for i, heading in ipairs(headings) do
    if heading.level > max_level then
      max_level = heading.level
    end
    
    if heading.level > config.max_heading_level then
      table.insert(issues, "Heading level " .. heading.level .. " exceeds maximum ("
                  .. config.max_heading_level .. ") at line " .. heading.line)
    end
  end
  
  return max_level, issues
end

-- Check sections
local function check_required_sections(headings)
  local found_sections = {}
  local issues = {}
  
  for _, heading in ipairs(headings) do
    for _, required in ipairs(config.required_sections) do
      if heading.text:match(required) then
        found_sections[required] = true
      end
    end
  end
  
  for _, required in ipairs(config.required_sections) do
    if not found_sections[required] then
      table.insert(issues, "Missing required section: " .. required)
    end
  end
  
  return issues
end

-- Check a single file
local function check_file_quality(file_path)
  print("Checking " .. file_path)
  
  -- Read file
  local content, read_err = fs.read_file(file_path)
  if not content then
    print("Error reading " .. file_path .. ": " .. (read_err or "unknown error"))
    return false, {"Could not read file"}
  end
  
  local issues = {}
  
  -- Check word count
  local words = count_words(content)
  if words < config.min_word_count then
    table.insert(issues, "Word count too low: " .. words .. " (minimum " .. config.min_word_count .. ")")
  end
  
  -- Check code examples
  if config.require_code_examples and not has_code_examples(content) then
    table.insert(issues, "No code examples found (requires at least one ```lua block)")
  end
  
  -- Extract and check headings
  local headings = markdown.extract_headings(content)
  
  -- Check heading levels
  local max_level, level_issues = check_heading_levels(headings)
  for _, issue in ipairs(level_issues) do
    table.insert(issues, issue)
  end
  
  -- Check required sections
  local section_issues = check_required_sections(headings)
  for _, issue in ipairs(section_issues) do
    table.insert(issues, issue)
  end
  
  -- Report results
  if #issues > 0 then
    print("  Issues found in " .. file_path .. ":")
    for _, issue in ipairs(issues) do
      print("  - " .. issue)
    end
    return false, issues
  else
    print("  Passed quality check: " .. words .. " words, headings to level " .. max_level)
    return true, {}
  end
end

-- Check all files
local function check_all_files()
  -- Find all markdown files
  local files, find_err = markdown.find_markdown_files(config.docs_dir)
  if not files then
    print("Error finding markdown files: " .. (find_err and find_err.message or "unknown error"))
    return false
  end
  
  print("Checking quality of " .. #files .. " markdown files...")
  local passed_count = 0
  local failed_files = {}
  
  for _, file_path in ipairs(files) do
    local passed, issues = check_file_quality(file_path)
    if passed then
      passed_count = passed_count + 1
    else
      table.insert(failed_files, {file = file_path, issues = issues})
    end
  end
  
  print("\nSummary:")
  print("  Passed: " .. passed_count .. " of " .. #files .. " files")
  
  if #failed_files > 0 then
    print("  Failed: " .. #failed_files .. " files")
    print("\nIssues by file:")
    for _, fail in ipairs(failed_files) do
      print("  " .. fail.file .. ": " .. #fail.issues .. " issues")
    end
    return false
  else
    print("  All files passed quality check")
    return true
  end
end

-- Main function
local function main()
  print("Running documentation quality check...")
  local success = check_all_files()
  return success and 0 or 1
end

os.exit(main())
```

These examples demonstrate various ways to use the Markdown module for different use cases, from simple formatting fixes to complex documentation workflows. You can adapt and combine these examples to suit your specific documentation needs.