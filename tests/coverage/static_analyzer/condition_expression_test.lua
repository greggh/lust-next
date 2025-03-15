-- Tests for the condition expression tracking in the static analyzer

-- Import firmo
local firmo = require("firmo")
local describe, it, expect = firmo.describe, firmo.it, firmo.expect
local before, after = firmo.before, firmo.after

local static_analyzer = require("lib.coverage.static_analyzer")
local temp_file = require("lib.tools.temp_file")

describe("condition expression tracking", function()
  before(function()
    static_analyzer.init()
  end)
  
  after(function()
    static_analyzer.clear_cache()
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
    
    -- Find the condition
    local op_condition
    for _, cond in ipairs(conditions) do
      if cond.type == "op" then
        op_condition = cond
        break
      end
    end
    
    expect(op_condition).to.exist()
    expect(op_condition.is_compound).to_not.be_truthy()
    
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
    
    -- Should have the compound condition and possibly component conditions
    expect(#conditions).to.be_greater_than(1)
    
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
    
    -- Should have the compound condition and possibly component conditions
    expect(#conditions).to.be_greater_than(1)
    
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
  
  it("should link conditions to blocks", function()
    local code = [[
      if x > 5 then
        print("x is greater than 5")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local blocks = static_analyzer.get_blocks(code_map)
    
    -- Find the if block
    local if_block
    for _, block in ipairs(blocks) do
      if block.type == "If" then
        if_block = block
        break
      end
    end
    
    expect(if_block).to.exist()
    expect(if_block.conditions).to.be.a("table")
    expect(#if_block.conditions).to.be_greater_than(0)
    
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
    
    -- Additional checks for detailed metrics
    expect(metrics.simple_conditions).to.be.a("number")
    expect(metrics.compound_conditions).to.be.a("number")
    expect(metrics.coverage_by_type).to.be.a("table")
    expect(metrics.coverage_percent).to.be.a("number")
    
    temp_file.remove(temp)
  end)
  
  it("should get condition components correctly", function()
    local code = [[
      if (x > 5 and y < 10) then
        print("Both conditions met")
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    -- Find the AND condition
    local and_condition
    for _, cond in ipairs(conditions) do
      if cond.is_compound and cond.operator == "and" then
        and_condition = cond
        break
      end
    end
    
    expect(and_condition).to.exist()
    
    -- Get components
    local components = static_analyzer.get_condition_components(code_map, and_condition.id)
    expect(components).to.be.a("table")
    expect(#components).to.equal(2)
    
    temp_file.remove(temp)
  end)
  
  it("should handle conditions in loops", function()
    local code = [[
      while x > 10 do
        print("x is greater than 10")
      end
      
      repeat
        print("y is less than 20")
      until y >= 20
      
      for i = 1, 10 do
        if i % 2 == 0 then
          print("i is even")
        end
      end
    ]]
    
    local temp = temp_file.create(code)
    local code_map = static_analyzer.analyze_file(temp.path)
    local conditions = static_analyzer.get_conditions(code_map)
    
    -- Should have multiple conditions for different loop types
    expect(#conditions).to.be_greater_than(3)
    
    -- Find the while condition
    local while_condition
    for _, cond in ipairs(conditions) do
      if cond.type == "op" and cond.parent_id:match("^while") then
        while_condition = cond
        break
      end
    end
    
    expect(while_condition).to.exist()
    
    -- Find the until condition
    local until_condition
    for _, cond in ipairs(conditions) do
      if cond.parent_id:match("^repeat") then
        until_condition = cond
        break
      end
    end
    
    expect(until_condition).to.exist()
    
    temp_file.remove(temp)
  end)
end)
