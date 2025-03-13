--[[
This module implements a validator for the AST
Based on lua-parser by Andre Murbach Maidl (https://github.com/andremm/lua-parser)
]]

local logging = require("lib.tools.logging")

-- Initialize module logger
local logger = logging.get_logger("validator")
logging.configure_from_config("validator")

local M = {
  -- Module version
  _VERSION = "1.0.0"
}

-- Utility functions for scope management
local scope_util = {}

-- Calculate line number from a position in a string
function scope_util.lineno(subject, pos)
  if pos > #subject then pos = #subject end
  local line, col = 1, 1
  for i = 1, pos do
    if subject:sub(i, i) == '\n' then
      line = line + 1
      col = 1
    else
      col = col + 1
    end
  end
  return line, col
end

-- Create a new function scope
function scope_util.new_function(env)
  env.fscope = env.fscope + 1
  env["function"][env.fscope] = { is_vararg = false }
  return env.fscope
end

-- End a function scope
function scope_util.end_function(env)
  env.fscope = env.fscope - 1
  return env.fscope
end

-- Create a new scope
function scope_util.new_scope(env)
  env.scope = env.scope + 1
  env.maxscope = env.scope
  env[env.scope] = { label = {}, ["goto"] = {} }
  return env.scope
end

-- End a scope
function scope_util.end_scope(env)
  env.scope = env.scope - 1
  return env.scope
end

-- Begin a loop
function scope_util.begin_loop(env)
  env.loop = env.loop + 1
  return env.loop
end

-- End a loop
function scope_util.end_loop(env)
  env.loop = env.loop - 1
  return env.loop
end

-- Check if inside a loop
function scope_util.insideloop(env)
  return env.loop > 0
end

-- Creates an error message for the input string
local function syntaxerror(errorinfo, pos, msg)
  local l, c = scope_util.lineno(errorinfo.subject, pos)
  local error_msg = "%s:%d:%d: syntax error, %s"
  
  logger.error("Syntax error in source", {
    filename = errorinfo.filename,
    line = l,
    column = c,
    message = msg,
    position = pos
  })
  
  return string.format(error_msg, errorinfo.filename, l, c, msg)
end

-- Check if a label exists in the environment
local function exist_label(env, scope, stm)
  local l = stm[1]
  for s=scope, 0, -1 do
    if env[s]["label"][l] then return true end
  end
  return false
end

-- Set a label in the current scope
local function set_label(env, label, pos)
  logger.debug("Setting label in current scope", {
    label = label,
    scope = env.scope,
    position = pos
  })
  
  local scope = env.scope
  local l = env[scope]["label"][label]
  
  if not l then
    env[scope]["label"][label] = { name = label, pos = pos }
    logger.debug("Label set successfully", {
      label = label,
      scope = scope
    })
    return true
  else
    local line = scope_util.lineno(env.errorinfo.subject, l.pos)
    local msg = "label '%s' already defined at line %d"
    msg = string.format(msg, label, line)
    
    logger.error("Label already defined", {
      label = label,
      existing_line = line,
      new_position = pos
    })
    
    return nil, syntaxerror(env.errorinfo, pos, msg)
  end
end

-- Set a pending goto statement
local function set_pending_goto(env, stm)
  local scope = env.scope
  
  logger.debug("Setting pending goto statement", {
    label = stm[1],
    scope = scope,
    position = stm.pos
  })
  
  table.insert(env[scope]["goto"], stm)
  return true
end

-- Verify all pending goto statements
local function verify_pending_gotos(env)
  logger.debug("Verifying all pending goto statements", {
    max_scope = env.maxscope
  })
  
  local goto_count = 0
  for s=env.maxscope, 0, -1 do
    goto_count = goto_count + #env[s]["goto"]
  end
  
  logger.debug("Found pending goto statements", {
    count = goto_count
  })
  
  for s=env.maxscope, 0, -1 do
    for k, v in ipairs(env[s]["goto"]) do
      logger.debug("Checking goto statement", {
        label = v[1],
        scope = s,
        index = k
      })
      
      if not exist_label(env, s, v) then
        local msg = "no visible label '%s' for <goto>"
        msg = string.format(msg, v[1])
        
        logger.error("No visible label for goto", {
          label = v[1],
          scope = s,
          position = v.pos
        })
        
        return nil, syntaxerror(env.errorinfo, v.pos, msg)
      end
    end
  end
  
  logger.debug("All goto statements verified successfully")
  return true
end

-- Set vararg status for the current function
local function set_vararg(env, is_vararg)
  env["function"][env.fscope].is_vararg = is_vararg
end

-- Forward declarations
local traverse_stm, traverse_exp, traverse_var
local traverse_block, traverse_explist, traverse_varlist, traverse_parlist

-- Traverse a parameter list
function traverse_parlist(env, parlist)
  local len = #parlist
  local is_vararg = false
  if len > 0 and parlist[len].tag == "Dots" then
    is_vararg = true
  end
  set_vararg(env, is_vararg)
  return true
end

-- Traverse a function definition
local function traverse_function(env, exp)
  scope_util.new_function(env)
  scope_util.new_scope(env)
  local status, msg = traverse_parlist(env, exp[1])
  if not status then return status, msg end
  status, msg = traverse_block(env, exp[2])
  if not status then return status, msg end
  scope_util.end_scope(env)
  scope_util.end_function(env)
  return true
end

-- Traverse an operation
local function traverse_op(env, exp)
  local status, msg = traverse_exp(env, exp[2])
  if not status then return status, msg end
  if exp[3] then
    status, msg = traverse_exp(env, exp[3])
    if not status then return status, msg end
  end
  return true
end

-- Traverse a parenthesized expression
local function traverse_paren(env, exp)
  local status, msg = traverse_exp(env, exp[1])
  if not status then return status, msg end
  return true
end

-- Traverse a table constructor
local function traverse_table(env, fieldlist)
  for k, v in ipairs(fieldlist) do
    local tag = v.tag
    if tag == "Pair" then
      local status, msg = traverse_exp(env, v[1])
      if not status then return status, msg end
      status, msg = traverse_exp(env, v[2])
      if not status then return status, msg end
    else
      local status, msg = traverse_exp(env, v)
      if not status then return status, msg end
    end
  end
  return true
end

-- Traverse a vararg expression
local function traverse_vararg(env, exp)
  logger.debug("Traversing vararg expression", {
    position = exp.pos,
    function_scope = env.fscope
  })
  
  if not env["function"][env.fscope].is_vararg then
    local msg = "cannot use '...' outside a vararg function"
    
    logger.error("Invalid vararg usage", {
      position = exp.pos,
      function_scope = env.fscope,
      is_vararg = false
    })
    
    return nil, syntaxerror(env.errorinfo, exp.pos, msg)
  end
  
  logger.debug("Vararg expression is valid")
  return true
end

-- Traverse a function call
local function traverse_call(env, call)
  local status, msg = traverse_exp(env, call[1])
  if not status then return status, msg end
  for i=2, #call do
    status, msg = traverse_exp(env, call[i])
    if not status then return status, msg end
  end
  return true
end

-- Traverse a method invocation
local function traverse_invoke(env, invoke)
  local status, msg = traverse_exp(env, invoke[1])
  if not status then return status, msg end
  for i=3, #invoke do
    status, msg = traverse_exp(env, invoke[i])
    if not status then return status, msg end
  end
  return true
end

-- Traverse a variable assignment
local function traverse_assignment(env, stm)
  local status, msg = traverse_varlist(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_explist(env, stm[2])
  if not status then return status, msg end
  return true
end

-- Traverse a break statement
local function traverse_break(env, stm)
  logger.debug("Traversing break statement", {
    position = stm.pos,
    inside_loop = scope_util.insideloop(env),
    loop_count = env.loop
  })
  
  if not scope_util.insideloop(env) then
    local msg = "<break> not inside a loop"
    
    logger.error("Invalid break statement", {
      position = stm.pos,
      inside_loop = false,
      loop_count = env.loop
    })
    
    return nil, syntaxerror(env.errorinfo, stm.pos, msg)
  end
  
  logger.debug("Break statement is valid")
  return true
end

-- Traverse a for-in loop
local function traverse_forin(env, stm)
  scope_util.begin_loop(env)
  scope_util.new_scope(env)
  local status, msg = traverse_explist(env, stm[2])
  if not status then return status, msg end
  status, msg = traverse_block(env, stm[3])
  if not status then return status, msg end
  scope_util.end_scope(env)
  scope_util.end_loop(env)
  return true
end

-- Traverse a numeric for loop
local function traverse_fornum(env, stm)
  local status, msg
  scope_util.begin_loop(env)
  scope_util.new_scope(env)
  status, msg = traverse_exp(env, stm[2])
  if not status then return status, msg end
  status, msg = traverse_exp(env, stm[3])
  if not status then return status, msg end
  if stm[5] then
    status, msg = traverse_exp(env, stm[4])
    if not status then return status, msg end
    status, msg = traverse_block(env, stm[5])
    if not status then return status, msg end
  else
    status, msg = traverse_block(env, stm[4])
    if not status then return status, msg end
  end
  scope_util.end_scope(env)
  scope_util.end_loop(env)
  return true
end

-- Traverse a goto statement
local function traverse_goto(env, stm)
  local status, msg = set_pending_goto(env, stm)
  if not status then return status, msg end
  return true
end

-- Traverse an if statement
local function traverse_if(env, stm)
  local len = #stm
  if len % 2 == 0 then
    for i=1, len, 2 do
      local status, msg = traverse_exp(env, stm[i])
      if not status then return status, msg end
      status, msg = traverse_block(env, stm[i+1])
      if not status then return status, msg end
    end
  else
    for i=1, len-1, 2 do
      local status, msg = traverse_exp(env, stm[i])
      if not status then return status, msg end
      status, msg = traverse_block(env, stm[i+1])
      if not status then return status, msg end
    end
    local status, msg = traverse_block(env, stm[len])
    if not status then return status, msg end
  end
  return true
end

-- Traverse a label statement
local function traverse_label(env, stm)
  local status, msg = set_label(env, stm[1], stm.pos)
  if not status then return status, msg end
  return true
end

-- Traverse a local variable assignment
local function traverse_let(env, stm)
  local status, msg = traverse_explist(env, stm[2])
  if not status then return status, msg end
  return true
end

-- Traverse a local recursive assignment
local function traverse_letrec(env, stm)
  local status, msg = traverse_exp(env, stm[2][1])
  if not status then return status, msg end
  return true
end

-- Traverse a repeat-until loop
local function traverse_repeat(env, stm)
  scope_util.begin_loop(env)
  local status, msg = traverse_block(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_exp(env, stm[2])
  if not status then return status, msg end
  scope_util.end_loop(env)
  return true
end

-- Traverse a return statement
local function traverse_return(env, stm)
  local status, msg = traverse_explist(env, stm)
  if not status then return status, msg end
  return true
end

-- Traverse a while loop
local function traverse_while(env, stm)
  scope_util.begin_loop(env)
  local status, msg = traverse_exp(env, stm[1])
  if not status then return status, msg end
  status, msg = traverse_block(env, stm[2])
  if not status then return status, msg end
  scope_util.end_loop(env)
  return true
end

-- Traverse a variable reference
function traverse_var(env, var)
  local tag = var.tag
  if tag == "Id" then -- `Id{ <string> }
    return true
  elseif tag == "Index" then -- `Index{ expr expr }
    local status, msg = traverse_exp(env, var[1])
    if not status then return status, msg end
    status, msg = traverse_exp(env, var[2])
    if not status then return status, msg end
    return true
  else
    error("expecting a variable, but got a " .. tag)
  end
end

-- Traverse a list of variables
function traverse_varlist(env, varlist)
  for k, v in ipairs(varlist) do
    local status, msg = traverse_var(env, v)
    if not status then return status, msg end
  end
  return true
end

-- Traverse an expression
function traverse_exp(env, exp)
  local tag = exp.tag
  if tag == "Nil" or
     tag == "Boolean" or -- `Boolean{ <boolean> }
     tag == "Number" or -- `Number{ <number> }
     tag == "String" then -- `String{ <string> }
    return true
  elseif tag == "Dots" then
    return traverse_vararg(env, exp)
  elseif tag == "Function" then -- `Function{ { `Id{ <string> }* `Dots? } block }
    return traverse_function(env, exp)
  elseif tag == "Table" then -- `Table{ ( `Pair{ expr expr } | expr )* }
    return traverse_table(env, exp)
  elseif tag == "Op" then -- `Op{ opid expr expr? }
    return traverse_op(env, exp)
  elseif tag == "Paren" then -- `Paren{ expr }
    return traverse_paren(env, exp)
  elseif tag == "Call" then -- `Call{ expr expr* }
    return traverse_call(env, exp)
  elseif tag == "Invoke" then -- `Invoke{ expr `String{ <string> } expr* }
    return traverse_invoke(env, exp)
  elseif tag == "Id" or -- `Id{ <string> }
         tag == "Index" then -- `Index{ expr expr }
    return traverse_var(env, exp)
  else
    error("expecting an expression, but got a " .. tag)
  end
end

-- Traverse a list of expressions
function traverse_explist(env, explist)
  for k, v in ipairs(explist) do
    local status, msg = traverse_exp(env, v)
    if not status then return status, msg end
  end
  return true
end

-- Traverse a statement
function traverse_stm(env, stm)
  local tag = stm.tag
  if tag == "Do" then -- `Do{ stat* }
    return traverse_block(env, stm)
  elseif tag == "Set" then -- `Set{ {lhs+} {expr+} }
    return traverse_assignment(env, stm)
  elseif tag == "While" then -- `While{ expr block }
    return traverse_while(env, stm)
  elseif tag == "Repeat" then -- `Repeat{ block expr }
    return traverse_repeat(env, stm)
  elseif tag == "If" then -- `If{ (expr block)+ block? }
    return traverse_if(env, stm)
  elseif tag == "Fornum" then -- `Fornum{ ident expr expr expr? block }
    return traverse_fornum(env, stm)
  elseif tag == "Forin" then -- `Forin{ {ident+} {expr+} block }
    return traverse_forin(env, stm)
  elseif tag == "Local" then -- `Local{ {ident+} {expr+}? }
    return traverse_let(env, stm)
  elseif tag == "Localrec" then -- `Localrec{ ident expr }
    return traverse_letrec(env, stm)
  elseif tag == "Goto" then -- `Goto{ <string> }
    return traverse_goto(env, stm)
  elseif tag == "Label" then -- `Label{ <string> }
    return traverse_label(env, stm)
  elseif tag == "Return" then -- `Return{ <expr>* }
    return traverse_return(env, stm)
  elseif tag == "Break" then
    return traverse_break(env, stm)
  elseif tag == "Call" then -- `Call{ expr expr* }
    return traverse_call(env, stm)
  elseif tag == "Invoke" then -- `Invoke{ expr `String{ <string> } expr* }
    return traverse_invoke(env, stm)
  else
    error("expecting a statement, but got a " .. tag)
  end
end

-- Traverse a block of statements
function traverse_block(env, block)
  scope_util.new_scope(env)
  for k, v in ipairs(block) do
    local status, msg = traverse_stm(env, v)
    if not status then return status, msg end
  end
  scope_util.end_scope(env)
  return true
end

-- Validate an AST
function M.validate(ast, errorinfo)
  logger.debug("Starting AST validation")
  
  assert(type(ast) == "table")
  assert(type(errorinfo) == "table")
  
  local env = { 
    errorinfo = errorinfo, 
    ["function"] = {}, 
    scope = -1, 
    maxscope = -1, 
    fscope = -1, 
    loop = 0 
  }
  
  logger.debug("Initialized validation environment", {
    has_errorinfo = errorinfo ~= nil,
    ast_type = type(ast)
  })
  
  scope_util.new_function(env)
  set_vararg(env, true)
  
  logger.debug("Starting block traversal")
  local status, msg = traverse_block(env, ast)
  if not status then 
    logger.error("Block traversal failed", {
      error = msg
    })
    return status, msg 
  end
  
  scope_util.end_function(env)
  
  logger.debug("Verifying pending goto statements")
  status, msg = verify_pending_gotos(env)
  if not status then 
    logger.error("Goto verification failed", {
      error = msg
    })
    return status, msg 
  end
  
  logger.debug("AST validation completed successfully")
  return ast
end

-- Helper function for creating syntax error messages
function M.syntaxerror(errorinfo, pos, msg)
  logger.error("Syntax error encountered", {
    filename = errorinfo and errorinfo.filename or "unknown",
    position = pos,
    message = msg
  })
  return syntaxerror(errorinfo, pos, msg)
end

return M