# Parser Examples

This document provides practical examples of using Firmo's parser module to analyze and work with Lua source code.

## Basic Parsing

### Parsing Lua Source Code

```lua
local parser = require("lib.tools.parser")

-- Sample Lua code
local source = [[
local function factorial(n)
  if n <= 1 then
    return 1
  else
    return n * factorial(n - 1)
  end
end

print(factorial(5))
]]

-- Parse the code into an AST
local ast, err = parser.parse(source, "factorial.lua")
if not ast then
  print("Parse error:", err)
  return
end

print("Successfully parsed the code!")
```

### Parsing From Files

```lua
local parser = require("lib.tools.parser")

-- Parse a Lua file
local ast, err = parser.parse_file("/path/to/module.lua")
if not ast then
  print("Failed to parse file:", err)
  return
end

print("Successfully parsed the file!")
```

### Visualizing the AST

```lua
local parser = require("lib.tools.parser")

-- Parse a simple expression
local source = "local x = 1 + 2 * 3"
local ast = parser.parse(source)

-- Pretty print the AST
local ast_string = parser.pretty_print(ast)
print(ast_string)

-- Result will be a readable representation of the AST structure
```

## Code Analysis

### Identifying Executable Lines

```lua
local parser = require("lib.tools.parser")

local source = [[
local function test(a, b)
  -- This is a comment, not executable
  local result
  
  if a > b then
    result = a
  else
    result = b
  end
  
  return result
end
]]

local ast = parser.parse(source)
local executable_lines = parser.get_executable_lines(ast, source)

print("Executable lines:")
local lines = {}
for line_num in pairs(executable_lines) do
  table.insert(lines, line_num)
end

-- Sort line numbers for readability
table.sort(lines)
for _, line_num in ipairs(lines) do
  print(line_num, source:match("()[^\n]*", (source:find("\n", 1, true) or 0) * (line_num - 1) + 1))
end

-- Expected output:
-- Executable lines:
-- 1  local function test(a, b)
-- 3    local result
-- 5    if a > b then
-- 6      result = a
-- 8      result = b
-- 11   return result
```

### Finding Function Definitions

```lua
local parser = require("lib.tools.parser")

local source = [[
-- Regular function
local function add(a, b)
  return a + b
end

-- Anonymous function
local subtract = function(a, b)
  return a - b
end

-- Method in a table
local calculator = {
  multiply = function(a, b)
    return a * b
  end
}

-- Method using colon syntax
function calculator:divide(a, b)
  return a / b
end
]]

local ast = parser.parse(source)
local functions = parser.get_functions(ast, source)

for i, func in ipairs(functions) do
  print(string.format("%d. Function: %s (lines %d-%d)",
    i, func.name, func.line_start, func.line_end))
  
  print("   Parameters:", table.concat(func.params, ", "))
  if func.is_method then
    print("   Is a method (automatically receives 'self' parameter)")
  end
  print("")
end

-- Expected output:
-- 1. Function: add (lines 2-4)
--    Parameters: a, b
--
-- 2. Function: subtract (lines 7-9)
--    Parameters: a, b
--
-- 3. Function: calculator.multiply (lines 13-15)
--    Parameters: a, b
--
-- 4. Function: calculator:divide (lines 19-21)
--    Parameters: a, b
--    Is a method (automatically receives 'self' parameter)
```

### Creating a Comprehensive Code Map

```lua
local parser = require("lib.tools.parser")

local source = [[
local values = {1, 2, 3, 4, 5}

local function process(items)
  local sum = 0
  local count = #items
  
  for i, value in ipairs(items) do
    sum = sum + value
    print(string.format("Item %d: %d", i, value))
  end
  
  return {
    sum = sum,
    average = sum / count
  }
end

local result = process(values)
print("Sum:", result.sum)
print("Average:", result.average)
]]

local code_map = parser.create_code_map(source, "stats.lua")

if code_map.valid then
  print("Code Analysis Summary:")
  print(string.format("- Total lines: %d", code_map.source_lines))
  
  local executable_count = 0
  for _ in pairs(code_map.executable_lines) do
    executable_count = executable_count + 1
  end
  print(string.format("- Executable lines: %d", executable_count))
  
  print(string.format("- Functions found: %d", #code_map.functions))
  
  print("\nFunctions:")
  for _, func in ipairs(code_map.functions) do
    print(string.format("  %s (lines %d-%d)", 
      func.name, func.line_start, func.line_end))
  end
  
  print("\nCode Structure:")
  print("- Top-level statements:", #code_map.ast)
  
  -- Print the first few lines with their status
  print("\nFirst 5 lines with status:")
  for i = 1, 5 do
    if i <= code_map.source_lines then
      local status = code_map.executable_lines[i] and "executable" or "non-executable"
      print(string.format("  Line %d: %s (%s)",
        i, code_map.lines[i], status))
    end
  end
end
```

## Advanced Usage

### AST Node Navigation

```lua
local parser = require("lib.tools.parser")

-- Sample code with different node types
local source = [[
local x = 10
local y = 20
local z = x + y

if z > 25 then
  print("Result is greater than 25")
else
  print("Result is not greater than 25")
end
]]

local ast = parser.parse(source)

-- Function to traverse the AST and count node types
local function analyze_ast(node)
  if type(node) ~= "table" then
    return {}
  end
  
  local counts = {}
  
  -- Count this node type if it has a tag
  if node.tag then
    counts[node.tag] = 1
  end
  
  -- Process all children
  for i, child in ipairs(node) do
    if type(child) == "table" then
      local child_counts = analyze_ast(child)
      
      -- Merge child counts into our counts
      for tag, count in pairs(child_counts) do
        counts[tag] = (counts[tag] or 0) + count
      end
    end
  end
  
  return counts
end

local node_counts = analyze_ast(ast)

-- Sort and display node type counts
print("AST Node Types:")
local sorted_types = {}
for tag in pairs(node_counts) do
  table.insert(sorted_types, tag)
end
table.sort(sorted_types)

for _, tag in ipairs(sorted_types) do
  print(string.format("  %s: %d", tag, node_counts[tag]))
end
```

### Finding Specific Code Patterns

```lua
local parser = require("lib.tools.parser")

-- Sample code with variable uses
local source = [[
local count = 0

local function increment(value)
  count = count + (value or 1)
  return count
end

local function reset()
  count = 0
end

increment(5)
increment(10)
reset()
increment()
]]

local ast = parser.parse(source)

-- Function to find all references to a specific variable
local function find_variable_references(ast, var_name)
  local references = {}
  
  local function search_node(node)
    if not node or type(node) ~= "table" then
      return
    end
    
    -- Check if this is a variable reference
    if node.tag == "Id" and node[1] == var_name then
      table.insert(references, {
        pos = node.pos,
        end_pos = node.end_pos
      })
    end
    
    -- Search all child nodes
    for i, child in ipairs(node) do
      if type(child) == "table" then
        search_node(child)
      end
    end
  end
  
  search_node(ast)
  return references
end

-- Find all references to the "count" variable
local count_refs = find_variable_references(ast, "count")

-- Convert positions to line/column information
local function get_line_col(source, pos)
  local line, col = 1, 1
  for i = 1, pos do
    if source:sub(i, i) == '\n' then
      line = line + 1
      col = 1
    else
      col = col + 1
    end
  end
  return line, col
end

print(string.format("Found %d references to 'count':", #count_refs))
for i, ref in ipairs(count_refs) do
  local line, col = get_line_col(source, ref.pos)
  print(string.format("  Reference %d: line %d, column %d", 
    i, line, col))
end
```

### Detecting Function Complexity

```lua
local parser = require("lib.tools.parser")

-- Sample code with functions of different complexity
local source = [[
-- Simple function
local function simple(x)
  return x * 2
end

-- Medium complexity
local function medium(x, y)
  local result = 0
  for i = 1, x do
    if i % 2 == 0 then
      result = result + i
    else
      result = result + y
    end
  end
  return result
end

-- Complex function
local function complex(data, options)
  local result = {}
  
  if not options then
    options = {threshold = 10, scale = 1}
  end
  
  for key, value in pairs(data) do
    if type(value) == "number" then
      if value > options.threshold then
        result[key] = value * options.scale
      else
        result[key] = value
      end
    elseif type(value) == "string" then
      result[key] = #value
    elseif type(value) == "table" then
      result[key] = complex(value, options)
    else
      result[key] = 0
    end
  end
  
  return result
end
]]

local ast = parser.parse(source)
local functions = parser.get_functions(ast, source)

-- Function to assess complexity based on various metrics
local function analyze_function_complexity(ast, func)
  local metrics = {
    if_count = 0,
    loop_count = 0,
    return_count = 0,
    parameter_count = #func.params,
    depth = 0,
    current_depth = 0
  }
  
  local function traverse(node)
    if not node or type(node) ~= "table" then
      return
    end
    
    -- Track nesting depth
    metrics.current_depth = metrics.current_depth + 1
    if metrics.current_depth > metrics.depth then
      metrics.depth = metrics.current_depth
    end
    
    -- Count control structures
    if node.tag == "If" then
      metrics.if_count = metrics.if_count + 1
    elseif node.tag == "While" or node.tag == "Repeat" or 
           node.tag == "Fornum" or node.tag == "Forin" then
      metrics.loop_count = metrics.loop_count + 1
    elseif node.tag == "Return" then
      metrics.return_count = metrics.return_count + 1
    end
    
    -- Process child nodes
    for i, child in ipairs(node) do
      if type(child) == "table" then
        traverse(child)
      end
    end
    
    -- Decrease depth when leaving this node
    metrics.current_depth = metrics.current_depth - 1
  end
  
  -- Find the function body in the AST
  local function find_func_body(ast)
    if not ast or type(ast) ~= "table" then
      return nil
    end
    
    -- Check if this is the function node we're looking for
    if ast.tag == "Function" and 
       ast.pos == func.pos and ast.end_pos == func.end_pos then
      return ast[2]  -- Function body is the second element
    end
    
    -- Search in child nodes
    for i, child in ipairs(ast) do
      if type(child) == "table" then
        local result = find_func_body(child)
        if result then return result end
      end
    end
    
    return nil
  end
  
  local body = find_func_body(ast)
  if body then
    traverse(body)
  end
  
  -- Calculate complexity score (simple formula)
  metrics.complexity_score = metrics.if_count + metrics.loop_count + 
                             metrics.parameter_count + metrics.depth
  
  return metrics
end

-- Analyze all functions
print("Function Complexity Analysis:")
for _, func in ipairs(functions) do
  local metrics = analyze_function_complexity(ast, func)
  
  print(string.format("\nFunction: %s (lines %d-%d)", 
    func.name, func.line_start, func.line_end))
  print(string.format("  Parameters: %d", metrics.parameter_count))
  print(string.format("  If statements: %d", metrics.if_count))
  print(string.format("  Loops: %d", metrics.loop_count))
  print(string.format("  Return statements: %d", metrics.return_count))
  print(string.format("  Maximum nesting depth: %d", metrics.depth))
  print(string.format("  Complexity score: %d", metrics.complexity_score))
  
  -- Classify complexity
  local complexity = "simple"
  if metrics.complexity_score > 15 then
    complexity = "high"
  elseif metrics.complexity_score > 5 then
    complexity = "medium"
  end
  print(string.format("  Classification: %s complexity", complexity))
end
```

### AST Transformation (Simple Example)

```lua
local parser = require("lib.tools.parser")

-- Sample code to transform
local source = [[
-- This is a simple test
local x = 10
local y = 20
local result = x + y
print(result)
]]

local ast = parser.parse(source)

-- Simple transformation: Change all numeric literals
local function transform_numbers(node)
  if not node or type(node) ~= "table" then
    return
  end
  
  -- Check if this is a number node
  if node.tag == "Number" then
    -- Double the value
    node[1] = node[1] * 2
  end
  
  -- Process all child nodes
  for i, child in ipairs(node) do
    if type(child) == "table" then
      transform_numbers(child)
    end
  end
  
  return node
end

-- Apply the transformation
transform_numbers(ast)

-- For demonstration, we'd need to convert back to code
-- This would normally require an AST-to-code converter
print("AST after transformation:")
print(parser.pretty_print(ast))

-- Expected result would show numbers like 10 changing to 20, etc.
```

### Error Detection and Handling

```lua
local parser = require("lib.tools.parser")

-- Function to detect syntax errors with detailed reporting
local function check_syntax(code, filename)
  local ast, err = parser.parse(code, filename or "input")
  
  if not ast then
    -- Parse the error message to extract line, column, and description
    local line, col, msg = err:match(".-:(%d+):(%d+): syntax error, (.+)")
    
    if line and col and msg then
      return {
        valid = false,
        line = tonumber(line),
        column = tonumber(col),
        message = msg,
        full_error = err
      }
    else
      return {
        valid = false,
        message = "Syntax error",
        full_error = err
      }
    end
  end
  
  return {
    valid = true,
    ast = ast
  }
end

-- Test with valid code
print("Testing valid code:")
local valid_code = "local x = 10\nprint(x + 5)"
local result1 = check_syntax(valid_code)
print("Valid:", result1.valid)

-- Test with syntax error
print("\nTesting invalid code:")
local invalid_code = "local x = 10\nprint(x +\nreturn x"
local result2 = check_syntax(invalid_code)
print("Valid:", result2.valid)
if not result2.valid then
  print(string.format("Error at line %d, column %d: %s", 
    result2.line, result2.column, result2.message))
end
```

### Batch Processing Multiple Files

```lua
local parser = require("lib.tools.parser")
local fs = require("lib.tools.filesystem")

-- Function to analyze a directory of Lua files
local function analyze_directory(dir_path)
  local results = {
    total_files = 0,
    parsed_files = 0,
    error_files = 0,
    total_lines = 0,
    executable_lines = 0,
    functions = 0,
    errors = {}
  }
  
  -- Get all Lua files
  local files = fs.scan_directory(dir_path, true) -- recursive
  local lua_files = {}
  
  for _, file in ipairs(files) do
    if file:match("%.lua$") then
      table.insert(lua_files, file)
    end
  end
  
  results.total_files = #lua_files
  
  -- Process each file
  for _, file_path in ipairs(lua_files) do
    local ast, err = parser.parse_file(file_path)
    
    if ast then
      results.parsed_files = results.parsed_files + 1
      
      -- Create code map for detailed analysis
      local code_map = parser.create_code_map_from_file(file_path)
      
      if code_map.valid then
        results.total_lines = results.total_lines + code_map.source_lines
        
        -- Count executable lines
        local executable_count = 0
        for _ in pairs(code_map.executable_lines) do
          executable_count = executable_count + 1
        end
        
        results.executable_lines = results.executable_lines + executable_count
        results.functions = results.functions + #code_map.functions
      end
    else
      results.error_files = results.error_files + 1
      table.insert(results.errors, {
        file = file_path,
        error = err
      })
    end
  end
  
  return results
end

-- Example usage
local dir_to_analyze = "/path/to/lua/project"
print("Analyzing directory:", dir_to_analyze)

local results = analyze_directory(dir_to_analyze)

print("\nAnalysis Results:")
print(string.format("Total files scanned: %d", results.total_files))
print(string.format("Successfully parsed: %d", results.parsed_files))
print(string.format("Files with errors: %d", results.error_files))
print(string.format("Total lines of code: %d", results.total_lines))
print(string.format("Executable lines: %d (%.1f%%)", 
  results.executable_lines, 
  results.total_lines > 0 and (results.executable_lines / results.total_lines * 100) or 0))
print(string.format("Functions found: %d", results.functions))

if results.error_files > 0 then
  print("\nFiles with errors:")
  for i, err_info in ipairs(results.errors) do
    print(string.format("%d. %s", i, err_info.file))
    print("   Error:", err_info.error:gsub("\n", "\n   "))
  end
end
```

These examples demonstrate a wide range of uses for the parser module, from basic parsing to advanced code analysis and transformation. By leveraging the parser, you can build powerful tools for code quality assessment, documentation generation, and automated refactoring.