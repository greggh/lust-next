# Session Summary: Condition Expression Tracking Implementation

## Date: 2025-03-16

## Overview

In this session, we focused on implementing comprehensive condition expression tracking in the static analyzer module. This enhancement allows us to track not just whether a condition was executed, but also which paths were taken (true or false) and how complex conditional expressions are composed. This capability is crucial for measuring condition coverage, an important metric in code quality assessment.

## Key Changes

1. **Enhanced Condition Extraction**
   - Improved the `extract_conditions` function to identify and decompose complex conditional expressions
   - Added support for AND, OR, and NOT operations as compound conditions
   - Implemented tracking of condition components and relationships
   - Added metadata for condition type and expression details

2. **Condition Relationship Tracking**
   - Implemented a parent-child relationship between composite conditions and their components
   - Created a system to track relationships between conditions in compound expressions
   - Added support for condition graph visualization

3. **Expression Outcome Tracking**
   - Enhanced condition objects to track not just execution but outcome states
   - Added metadata for true/false outcomes and execution count
   - Implemented utilities to analyze condition coverage completeness

4. **Public API Enhancements**
   - Created new functions for condition-specific analysis
   - Enhanced existing block-related functions to include condition data
   - Added statistical functions for condition coverage metrics

5. **Test Suite**
   - Created a comprehensive test suite for condition tracking
   - Implemented tests for various expression types and compositions
   - Added tests for complex nested conditions

## Implementation Details

### Condition Extraction Enhancement

The enhanced condition extraction system now decomposes compound conditions into their component parts:

```lua
-- Enhanced condition extraction with compound condition support
local function extract_conditions(node, conditions, content, parent_id, is_child)
  conditions = conditions or {}
  parent_id = parent_id or "root"
  local condition_id

  -- Process node if it's a conditional operation
  if node and node.tag and CONDITION_TAGS[node.tag] then
    if node.pos and node.end_pos then
      -- Create a unique ID for this condition
      local condition_type = node.tag:lower()
      condition_id = condition_type .. "_" .. #conditions + 1
      
      -- Get line boundaries for the condition
      local start_line = get_line_for_position(content, node.pos)
      local end_line = get_line_for_position(content, node.end_pos)
      
      -- Only add valid conditions
      if start_line and end_line and start_line <= end_line then
        -- Create the condition entry
        local condition = {
          id = condition_id,
          type = condition_type,
          parent_id = parent_id,
          start_line = start_line,
          end_line = end_line,
          is_compound = (node.tag == "Op" and (node[1] == "and" or node[1] == "or")),
          operator = node.tag == "Op" and node[1] or nil,
          components = {},
          executed = false,
          executed_true = false,
          executed_false = false,
          execution_count = 0,
          metadata = {
            ast_pos = node.pos,
            ast_end_pos = node.end_pos
          }
        }
        
        -- Add the condition to our collection
        table.insert(conditions, condition)
        
        -- For binary operations like AND/OR, add the left and right components
        if node.tag == "Op" and (node[1] == "and" or node[1] == "or") then
          -- Extract left operand conditions
          local left_id = extract_conditions(node[2], conditions, content, condition_id, true)
          if left_id then
            table.insert(condition.components, left_id)
          end
          
          -- Extract right operand conditions
          local right_id = extract_conditions(node[3], conditions, content, condition_id, true)
          if right_id then
            table.insert(condition.components, right_id)
          end
        end
        
        -- For NOT operations, extract the negated condition
        if node.tag == "Not" then
          local comp_id = extract_conditions(node[1], conditions, content, condition_id, true)
          if comp_id then
            table.insert(condition.components, comp_id)
          end
        end
        
        -- Return the condition ID for parent linkage
        if not is_child then
          return conditions
        else
          return condition_id
        end
      end
    end
  end
  
  -- If no condition was extracted but the node has children, process them
  if not condition_id and node then
    for i = 1, #node do
      if type(node[i]) == "table" then
        -- Only process AST nodes, not scalar values
        extract_conditions(node[i], conditions, content, parent_id, false)
      end
    end
  end
  
  if not is_child then
    return conditions
  else
    return nil
  end
end
```

### Condition Processing in Control Structures

We enhanced the processing of control structures to include condition tracking:

```lua
-- Enhanced function to process If blocks with condition tracking
local function process_if_block(blocks, parent_block, node, content, block_id_counter, parent_id)
  local condition_id, then_id, else_id
  
  -- Process condition expression
  if node[1] then
    -- Extract all conditions in the expression
    local conditions = extract_conditions(node[1], {}, content, parent_id, false)
    
    -- Link conditions to the parent block
    for _, condition in ipairs(conditions) do
      if condition.parent_id == parent_id then
        table.insert(parent_block.conditions, condition.id)
      end
    end
    
    -- Add all extracted conditions to the blocks array
    for _, condition in ipairs(conditions) do
      table.insert(blocks, condition)
    end
  end
  
  -- Process then branch
  -- [implementation not changed]
  
  -- Process else branch
  -- [implementation not changed]
end
```

### Public API Functions

New and enhanced API functions for condition tracking:

```lua
-- Get all conditions in a file
function M.find_conditions(code_map)
  -- Ensure we have a valid code map with AST
  if not code_map or not code_map.ast or not code_map.content then
    return {}
  end
  
  -- Extract all conditions from the AST
  local conditions = extract_conditions(code_map.ast, {}, code_map.content, "root", false)
  
  -- Debug logging if enabled
  if logger.is_debug_enabled() then
    logger.debug({
      message = "Found " .. #conditions .. " conditions in file",
      file = code_map.file_path,
      condition_count = #conditions,
      operation = "find_conditions"
    })
  end
  
  return conditions
end

-- Get composite condition information
function M.get_condition_components(code_map, condition_id)
  if not code_map or not code_map.conditions then
    return {}
  end
  
  -- Find the specified condition
  local target_condition
  for _, condition in ipairs(code_map.conditions) do
    if condition.id == condition_id then
      target_condition = condition
      break
    end
  end
  
  if not target_condition or not target_condition.components then
    return {}
  end
  
  -- Get component details
  local components = {}
  for _, comp_id in ipairs(target_condition.components) do
    for _, condition in ipairs(code_map.conditions) do
      if condition.id == comp_id then
        table.insert(components, condition)
        break
      end
    end
  end
  
  return components
end

-- Calculate detailed condition coverage metrics
function M.calculate_detailed_condition_coverage(code_map)
  if not code_map or not code_map.conditions then
    return {
      total_conditions = 0,
      executed_conditions = 0,
      fully_covered_conditions = 0,
      compound_conditions = 0,
      simple_conditions = 0,
      coverage_by_type = {},
      coverage_percent = 0,
      outcome_coverage_percent = 0
    }
  end
  
  local metrics = {
    total_conditions = #code_map.conditions,
    executed_conditions = 0,
    fully_covered_conditions = 0,
    compound_conditions = 0,
    simple_conditions = 0,
    coverage_by_type = {},
    coverage_percent = 0,
    outcome_coverage_percent = 0
  }
  
  -- Count condition types
  for _, condition in ipairs(code_map.conditions) do
    -- Track by condition type
    if not metrics.coverage_by_type[condition.type] then
      metrics.coverage_by_type[condition.type] = {
        total = 0,
        executed = 0,
        fully_covered = 0
      }
    end
    
    metrics.coverage_by_type[condition.type].total = 
      metrics.coverage_by_type[condition.type].total + 1
      
    -- Count simple vs compound conditions
    if condition.is_compound then
      metrics.compound_conditions = metrics.compound_conditions + 1
    else
      metrics.simple_conditions = metrics.simple_conditions + 1
    end
    
    -- Track execution
    if condition.executed then
      metrics.executed_conditions = metrics.executed_conditions + 1
      metrics.coverage_by_type[condition.type].executed = 
        metrics.coverage_by_type[condition.type].executed + 1
        
      -- Track full coverage (both true and false outcomes)
      if condition.executed_true and condition.executed_false then
        metrics.fully_covered_conditions = metrics.fully_covered_conditions + 1
        metrics.coverage_by_type[condition.type].fully_covered = 
          metrics.coverage_by_type[condition.type].fully_covered + 1
      end
    end
  end
  
  -- Calculate percentages
  if metrics.total_conditions > 0 then
    metrics.coverage_percent = (metrics.executed_conditions / metrics.total_conditions) * 100
    metrics.outcome_coverage_percent = (metrics.fully_covered_conditions / metrics.total_conditions) * 100
  end
  
  return metrics
end
```

### Integration with Block Finding

We updated the `find_blocks` function to incorporate condition tracking:

```lua
-- Connect blocks with their conditions
local function link_blocks_with_conditions(blocks, conditions)
  if not blocks or not conditions then
    return
  end
  
  -- Create a block map for faster lookup
  local block_map = {}
  for _, block in ipairs(blocks) do
    block_map[block.id] = block
  end
  
  -- Assign conditions to their parent blocks
  for _, condition in ipairs(conditions) do
    if condition.parent_id and condition.parent_id ~= "root" and block_map[condition.parent_id] then
      local parent_block = block_map[condition.parent_id]
      
      -- Initialize conditions array if not exists
      parent_block.conditions = parent_block.conditions or {}
      
      -- Add condition ID to the block
      table.insert(parent_block.conditions, condition.id)
    end
  end
end
```

### Code Map Update

We updated the code map generation to include conditions:

```lua
function M.generate_code_map(file_path, ast, content)
  -- [existing implementation]
  
  -- Find blocks and conditions
  local blocks = M.find_blocks(code_map)
  local conditions = M.find_conditions(code_map)
  
  -- Link blocks with conditions
  link_blocks_with_conditions(blocks, conditions)
  
  -- Update code map with blocks and conditions
  code_map.blocks = blocks
  code_map.conditions = conditions
  
  -- [rest of implementation]
end
```

## Testing

We created a dedicated test file `condition_expression_test.lua` to verify our implementation:

```lua
describe("condition expression tracking", function()
  local static_analyzer = require("lib.coverage.static_analyzer")
  local fs = require("lib.tools.filesystem")
  local temp_file = require("lib.tools.temp_file")
  
  before(function()
    static_analyzer.init()
  end)
  
  it("should extract simple conditions", function()
    local code = [[
      if x > 5 then
        print("x is greater than 5")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    expect(#conditions).to.be.a("number")
    expect(#conditions).to.be_greater_than(0)
    expect(conditions[1].type).to.equal("op")
    expect(conditions[1].is_compound).to_not.be_truthy()
    
    temp_file.remove(temp)
  end)
  
  it("should extract compound AND conditions", function()
    local code = [[
      if x > 5 and y < 10 then
        print("x is greater than 5 and y is less than 10")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    -- Should have the main compound condition and two components
    expect(#conditions).to.equal(3)
    
    -- Find the compound condition
    local compound_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "and" then
        compound_condition = cond
        break
      end
    end
    
    expect(compound_condition).to.exist()
    expect(#compound_condition.components).to.equal(2)
    
    temp_file.remove(temp)
  end)
  
  it("should extract compound OR conditions", function()
    local code = [[
      if x > 5 or y < 10 then
        print("x is greater than 5 or y is less than 10")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    -- Should have the main compound condition and two components
    expect(#conditions).to.equal(3)
    
    -- Find the compound condition
    local compound_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "or" then
        compound_condition = cond
        break
      end
    end
    
    expect(compound_condition).to.exist()
    expect(#compound_condition.components).to.equal(2)
    
    temp_file.remove(temp)
  end)
  
  it("should extract NOT conditions", function()
    local code = [[
      if not (x > 5) then
        print("x is not greater than 5")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    -- Should have the NOT condition and its component
    expect(#conditions).to.equal(2)
    
    -- Find the NOT condition
    local not_condition
    for _, cond in ipairs(conditions) do
      if cond.type == "not" then
        not_condition = cond
        break
      end
    end
    
    expect(not_condition).to.exist()
    expect(#not_condition.components).to.equal(1)
    
    temp_file.remove(temp)
  end)
  
  it("should extract complex nested conditions", function()
    local code = [[
      if (x > 5 and y < 10) or (z == 15 and (a ~= nil or b == false)) then
        print("Complex condition")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    -- Should have multiple conditions in a hierarchy
    expect(#conditions).to.be_greater_than(5)
    
    -- Find the top-level OR condition
    local top_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "or" and cond.parent_id == "root" then
        top_condition = cond
        break
      end
    end
    
    expect(top_condition).to.exist()
    expect(#top_condition.components).to.equal(2)
    
    temp_file.remove(temp)
  end)
  
  it("should calculate correct condition coverage metrics", function()
    local code = [[
      if x > 5 and y < 10 then
        print("Both conditions met")
      elseif x > 5 or y < 10 then
        print("At least one condition met")
      else
        print("No conditions met")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    
    -- Simulate execution data
    local conditions = static_analyzer.get_conditions(code_map)
    for i, condition in ipairs(conditions) do
      if i % 2 == 0 then
        condition.executed = true
        condition.executed_true = true
        condition.execution_count = 1
      elseif i % 3 == 0 then
        condition.executed = true
        condition.executed_true = true
        condition.executed_false = true
        condition.execution_count = 2
      end
    end
    
    local metrics = static_analyzer.calculate_detailed_condition_coverage(code_map)
    
    expect(metrics.total_conditions).to.equal(#conditions)
    expect(metrics.executed_conditions).to.be_greater_than(0)
    expect(metrics.fully_covered_conditions).to.be_greater_than(0)
    expect(metrics.compound_conditions).to.be_greater_than(0)
    expect(metrics.simple_conditions).to.be_greater_than(0)
    
    temp_file.remove(temp)
  end)
end)
```

## Challenges and Solutions

1. **Challenge**: Complex nested conditions with multiple operators
   **Solution**: Implemented a recursive extraction process that properly handles nested conditions at any depth

2. **Challenge**: Tracking parent-child relationships for conditions
   **Solution**: Added component tracking and parent IDs to create a proper hierarchy of conditions

3. **Challenge**: AST structure variation for different expression types
   **Solution**: Added specific handlers for different expression types to properly extract conditions

4. **Challenge**: Preventing duplicate condition extraction
   **Solution**: Implemented a condition ID system that ensures uniqueness

5. **Challenge**: Correctly mapping AST nodes to line numbers
   **Solution**: Enhanced the line mapping function to handle edge cases with multiline expressions

## Next Steps

With condition expression tracking now implemented, our next steps are:

1. **Debug Hook Enhancements**
   - Integrate condition tracking with the debug hook
   - Implement mechanisms to track condition outcomes during execution
   - Add tracking of condition execution counts

2. **Integration Testing**
   - Create integration tests between static analyzer and debug hook
   - Test condition coverage in real-world scenarios
   - Validate accuracy of condition tracking

3. **Visualization Enhancements**
   - Update HTML formatter to visualize condition coverage
   - Add tooltips to show condition details
   - Implement coverage highlights for condition expressions

This implementation completes the Static Analyzer improvements section of Phase 2 in our coverage module repair plan.