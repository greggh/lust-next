--[[
This module implements a pretty printer for the AST
Based on lua-parser by Andre Murbach Maidl (https://github.com/andremm/lua-parser)
]]

local M = {}

local logging
local logger

-- Try to load logging module (may not be available during initial load)
local function get_logger()
  if not logger then
    local success, log_module = pcall(require, "lib.tools.logging")
    if success then
      logging = log_module
      logger = logging.get_logger("parser.pp")
      logging.configure_from_config("parser.pp")
    end
  end
  return logger
end

local block2str, stm2str, exp2str, var2str
local explist2str, varlist2str, parlist2str, fieldlist2str

-- Check if a character is a control character
local function iscntrl(x)
  if (x >= 0 and x <= 31) or (x == 127) then return true end
  return false
end

-- Check if a character is printable
local function isprint(x)
  return not iscntrl(x)
end

-- Format a string for display with proper escaping
local function fixed_string(str)
  local new_str = ""
  for i=1,string.len(str) do
    local char = string.byte(str, i)
    if char == 34 then new_str = new_str .. string.format("\\\"")
    elseif char == 92 then new_str = new_str .. string.format("\\\\")
    elseif char == 7 then new_str = new_str .. string.format("\\a")
    elseif char == 8 then new_str = new_str .. string.format("\\b")
    elseif char == 12 then new_str = new_str .. string.format("\\f")
    elseif char == 10 then new_str = new_str .. string.format("\\n")
    elseif char == 13 then new_str = new_str .. string.format("\\r")
    elseif char == 9 then new_str = new_str .. string.format("\\t")
    elseif char == 11 then new_str = new_str .. string.format("\\v")
    else
      if isprint(char) then
        new_str = new_str .. string.format("%c", char)
      else
        new_str = new_str .. string.format("\\%03d", char)
      end
    end
  end
  return new_str
end

-- Format a name for display
local function name2str(name)
  return string.format('"%s"', name)
end

-- Format a boolean for display
local function boolean2str(b)
  return string.format('"%s"', tostring(b))
end

-- Format a number for display
local function number2str(n)
  return string.format('"%s"', tostring(n))
end

-- Format a string for display
local function string2str(s)
  return string.format('"%s"', fixed_string(s))
end

-- Format a variable for display
function var2str(var)
  local tag = var.tag
  local str = "`" .. tag
  if tag == "Id" then -- `Id{ <string> }
    str = str .. " " .. name2str(var[1])
  elseif tag == "Index" then -- `Index{ expr expr }
    str = str .. "{ "
    str = str .. exp2str(var[1]) .. ", "
    str = str .. exp2str(var[2])
    str = str .. " }"
  else
    error("expecting a variable, but got a " .. tag)
  end
  return str
end

-- Format a variable list for display
function varlist2str(varlist)
  local l = {}
  for k, v in ipairs(varlist) do
    l[k] = var2str(v)
  end
  return "{ " .. table.concat(l, ", ") .. " }"
end

-- Format a parameter list for display
function parlist2str(parlist)
  local l = {}
  local len = #parlist
  local is_vararg = false
  if len > 0 and parlist[len].tag == "Dots" then
    is_vararg = true
    len = len - 1
  end
  local i = 1
  while i <= len do
    l[i] = var2str(parlist[i])
    i = i + 1
  end
  if is_vararg then
    l[i] = "`" .. parlist[i].tag
  end
  return "{ " .. table.concat(l, ", ") .. " }"
end

-- Format a field list for display
function fieldlist2str(fieldlist)
  local l = {}
  for k, v in ipairs(fieldlist) do
    local tag = v.tag
    if tag == "Pair" then -- `Pair{ expr expr }
      l[k] = "`" .. tag .. "{ "
      l[k] = l[k] .. exp2str(v[1]) .. ", " .. exp2str(v[2])
      l[k] = l[k] .. " }"
    else -- expr
      l[k] = exp2str(v)
    end
  end
  if #l > 0 then
    return "{ " .. table.concat(l, ", ") .. " }"
  else
    return ""
  end
end

-- Format an expression for display
function exp2str(exp)
  local tag = exp.tag
  local str = "`" .. tag
  if tag == "Nil" or
     tag == "Dots" then
  elseif tag == "Boolean" then -- `Boolean{ <boolean> }
    str = str .. " " .. boolean2str(exp[1])
  elseif tag == "Number" then -- `Number{ <number> }
    str = str .. " " .. number2str(exp[1])
  elseif tag == "String" then -- `String{ <string> }
    str = str .. " " .. string2str(exp[1])
  elseif tag == "Function" then -- `Function{ { `Id{ <string> }* `Dots? } block }
    str = str .. "{ "
    str = str .. parlist2str(exp[1]) .. ", "
    str = str .. block2str(exp[2])
    str = str .. " }"
  elseif tag == "Table" then -- `Table{ ( `Pair{ expr expr } | expr )* }
    str = str .. fieldlist2str(exp)
  elseif tag == "Op" then -- `Op{ opid expr expr? }
    str = str .. "{ "
    str = str .. name2str(exp[1]) .. ", "
    str = str .. exp2str(exp[2])
    if exp[3] then
      str = str .. ", " .. exp2str(exp[3])
    end
    str = str .. " }"
  elseif tag == "Paren" then -- `Paren{ expr }
    str = str .. "{ " .. exp2str(exp[1]) .. " }"
  elseif tag == "Call" then -- `Call{ expr expr* }
    str = str .. "{ "
    str = str .. exp2str(exp[1])
    if exp[2] then
      for i=2, #exp do
        str = str .. ", " .. exp2str(exp[i])
      end
    end
    str = str .. " }"
  elseif tag == "Invoke" then -- `Invoke{ expr `String{ <string> } expr* }
    str = str .. "{ "
    str = str .. exp2str(exp[1]) .. ", "
    str = str .. exp2str(exp[2])
    if exp[3] then
      for i=3, #exp do
        str = str .. ", " .. exp2str(exp[i])
      end
    end
    str = str .. " }"
  elseif tag == "Id" or -- `Id{ <string> }
         tag == "Index" then -- `Index{ expr expr }
    str = var2str(exp)
  else
    error("expecting an expression, but got a " .. tag)
  end
  return str
end

-- Format an expression list for display
function explist2str(explist)
  local l = {}
  for k, v in ipairs(explist) do
    l[k] = exp2str(v)
  end
  if #l > 0 then
    return "{ " .. table.concat(l, ", ") .. " }"
  else
    return ""
  end
end

-- Format a statement for display
function stm2str(stm)
  local tag = stm.tag
  local str = "`" .. tag
  if tag == "Do" then -- `Do{ stat* }
    local l = {}
    for k, v in ipairs(stm) do
      l[k] = stm2str(v)
    end
    str = str .. "{ " .. table.concat(l, ", ") .. " }"
  elseif tag == "Set" then -- `Set{ {lhs+} {expr+} }
    str = str .. "{ "
    str = str .. varlist2str(stm[1]) .. ", "
    str = str .. explist2str(stm[2])
    str = str .. " }"
  elseif tag == "While" then -- `While{ expr block }
    str = str .. "{ "
    str = str .. exp2str(stm[1]) .. ", "
    str = str .. block2str(stm[2])
    str = str .. " }"
  elseif tag == "Repeat" then -- `Repeat{ block expr }
    str = str .. "{ "
    str = str .. block2str(stm[1]) .. ", "
    str = str .. exp2str(stm[2])
    str = str .. " }"
  elseif tag == "If" then -- `If{ (expr block)+ block? }
    str = str .. "{ "
    local len = #stm
    if len % 2 == 0 then
      local l = {}
      for i=1,len-2,2 do
        str = str .. exp2str(stm[i]) .. ", " .. block2str(stm[i+1]) .. ", "
      end
      str = str .. exp2str(stm[len-1]) .. ", " .. block2str(stm[len])
    else
      local l = {}
      for i=1,len-3,2 do
        str = str .. exp2str(stm[i]) .. ", " .. block2str(stm[i+1]) .. ", "
      end
      str = str .. exp2str(stm[len-2]) .. ", " .. block2str(stm[len-1]) .. ", "
      str = str .. block2str(stm[len])
    end
    str = str .. " }"
  elseif tag == "Fornum" then -- `Fornum{ ident expr expr expr? block }
    str = str .. "{ "
    str = str .. var2str(stm[1]) .. ", "
    str = str .. exp2str(stm[2]) .. ", "
    str = str .. exp2str(stm[3]) .. ", "
    if stm[5] then
      str = str .. exp2str(stm[4]) .. ", "
      str = str .. block2str(stm[5])
    else
      str = str .. block2str(stm[4])
    end
    str = str .. " }"
  elseif tag == "Forin" then -- `Forin{ {ident+} {expr+} block }
    str = str .. "{ "
    str = str .. varlist2str(stm[1]) .. ", "
    str = str .. explist2str(stm[2]) .. ", "
    str = str .. block2str(stm[3])
    str = str .. " }"
  elseif tag == "Local" then -- `Local{ {ident+} {expr+}? }
    str = str .. "{ "
    str = str .. varlist2str(stm[1])
    if #stm[2] > 0 then
      str = str .. ", " .. explist2str(stm[2])
    else
      str = str .. ", " .. "{  }"
    end
    str = str .. " }"
  elseif tag == "Localrec" then -- `Localrec{ ident expr }
    str = str .. "{ "
    str = str .. "{ " .. var2str(stm[1][1]) .. " }, "
    str = str .. "{ " .. exp2str(stm[2][1]) .. " }"
    str = str .. " }"
  elseif tag == "Goto" or -- `Goto{ <string> }
         tag == "Label" then -- `Label{ <string> }
    str = str .. "{ " .. name2str(stm[1]) .. " }"
  elseif tag == "Return" then -- `Return{ <expr>* }
    str = str .. explist2str(stm)
  elseif tag == "Break" then
  elseif tag == "Call" then -- `Call{ expr expr* }
    str = str .. "{ "
    str = str .. exp2str(stm[1])
    if stm[2] then
      for i=2, #stm do
        str = str .. ", " .. exp2str(stm[i])
      end
    end
    str = str .. " }"
  elseif tag == "Invoke" then -- `Invoke{ expr `String{ <string> } expr* }
    str = str .. "{ "
    str = str .. exp2str(stm[1]) .. ", "
    str = str .. exp2str(stm[2])
    if stm[3] then
      for i=3, #stm do
        str = str .. ", " .. exp2str(stm[i])
      end
    end
    str = str .. " }"
  else
    error("expecting a statement, but got a " .. tag)
  end
  return str
end

-- Format a block for display
function block2str(block)
  local l = {}
  for k, v in ipairs(block) do
    l[k] = stm2str(v)
  end
  return "{ " .. table.concat(l, ", ") .. " }"
end

-- Convert an AST to a string representation
function M.tostring(t)
  assert(type(t) == "table")
  return block2str(t)
end

-- Print an AST
function M.print(t)
  assert(type(t) == "table")
  local log = get_logger()
  
  -- If logger is available, use it, otherwise fall back to io.write
  if log then
    log.debug("AST structure", {ast_string = M.tostring(t)})
  else
    io.write("AST structure: " .. M.tostring(t) .. "\n")
  end
end

-- Dump an AST with detailed formatting
function M.dump(t, i, use_logger)
  i = i or 0
  use_logger = use_logger or false
  
  local log_str = ""
  local function append(str)
    if use_logger then
      log_str = log_str .. str
    else
      io.write(str)
    end
  end
  
  append(string.format("{\n"))
  append(string.format("%s[tag] = %s\n", string.rep(" ", i+2), t.tag or "nil"))
  append(string.format("%s[pos] = %s\n", string.rep(" ", i+2), t.pos or "nil"))
  
  for k,v in ipairs(t) do
    append(string.format("%s[%s] = ", string.rep(" ", i+2), tostring(k)))
    if type(v) == "table" then
      if use_logger then
        log_str = log_str .. M.dump(v, i+2, true)
      else
        M.dump(v, i+2)
      end
    else
      append(string.format("%s\n", tostring(v)))
    end
  end
  
  append(string.format("%s}\n", string.rep(" ", i)))
  
  if use_logger then
    return log_str
  end
end

-- Dump an AST with logging
function M.log_dump(t)
  local log = get_logger()
  if log then
    log.debug("AST detailed dump", {ast_dump = M.dump(t, 0, true)})
  else
    M.dump(t)
  end
end

return M