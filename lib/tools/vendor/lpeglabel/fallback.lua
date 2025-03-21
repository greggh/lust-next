-- Fallback module for LPegLabel
-- This provides a limited subset of the LPegLabel functionality
-- for systems where compilation of the C module is not possible

---@class lpeglabel.fallback
---@field _VERSION string Module version
---@field version fun(): string Get the version of the fallback module
---@field P fun(p: string|table|number): table Create a pattern (limited functionality)
---@field S fun(set: string): table Create a set pattern (limited functionality)
---@field R fun(range: string): table Create a range pattern (limited functionality)
---@field V fun(v: string|number): table Create a variable pattern (limited functionality)
---@field match fun(pattern: table, subject: string, init?: number): number|nil Match a pattern against a string
---@field type fun(pattern: any): string|nil Get the type of a pattern
---@field C fun(p: table): table Create a capture pattern (limited functionality)
---@field Ct fun(p: table): table Create a table capture pattern (limited functionality)
---@field Cc fun(...): table Create a constant capture pattern (limited functionality)
---@field T fun(label: string): table Create a labeled failure pattern (limited functionality)
---@field Cmt fun(p: table, f: function): table Create a match-time capture pattern (limited functionality)
---@field Cp fun(): table Create a position capture pattern (limited functionality)
---@field setlabels fun(labels: table): table Set failure labels for patterns (stub implementation)
---@field B fun(p: table): table Create a back reference pattern (limited functionality)
---@field Carg fun(n: number): table Create an argument capture pattern (limited functionality)
---@field Cb fun(name: string): table Create a back capture pattern (limited functionality)
---@field Cf fun(p: table, f: function): table Create a fold capture pattern (limited functionality)
---@field Cg fun(p: table, name?: string): table Create a group capture pattern (limited functionality)
---@field Cs fun(p: table): table Create a substitution capture pattern (limited functionality)
---@field Lc fun(p: table): table Create a labeled failure capture pattern (limited functionality)
---@field locale fun(t: table): table Set locale for patterns (stub implementation)
---@field is_fallback boolean Flag indicating this is the fallback implementation

local M = {}

-- Version info
M.version = function() return "Fallback 0.1 (Limited Functionality)" end

-- Pattern constructors with limited functionality
M.P = function(p)
  if type(p) == "string" then
    return { pattern = p, type = "literal" }
  elseif type(p) == "table" and p.type then
    return p
  elseif type(p) == "number" then
    return { pattern = p, type = "lenght" }
  else
    error("Not supported in fallback implementation")
  end
end

M.S = function(set)
  return { pattern = set, type = "set" }
end

M.R = function(range)
  return { pattern = range, type = "range" }
end

M.V = function(v)
  return { pattern = v, type = "variable" }
end

-- Captures
M.C = function(patt)
  return { pattern = patt, type = "capture" }
end

M.Ct = function(patt)
  return { pattern = patt, type = "table_capture" }
end

-- Placeholder for pattern matching
function M.match(patt, subject, init)
  print("Warning: Using fallback LPegLabel implementation with very limited functionality")
  print("Certain operations will not work correctly without the C module")
  
  -- Only support very basic literal string matching in the fallback
  if type(patt) == "table" and patt.type == "literal" and type(patt.pattern) == "string" then
    init = init or 1
    local s = subject:find(patt.pattern, init, true)
    if s then
      return s + #patt.pattern
    end
    return nil
  end
  
  error("Complex pattern matching not supported in fallback implementation")
end

-- Attach match method to patterns
local mt = {
  __index = {
    match = function(self, subject, init)
      return M.match(self, subject, init)
    end
  }
}

-- Set metatable for all pattern constructors
local function set_pattern_metatable(p)
  return setmetatable(p, mt)
end

local original_P = M.P
M.P = function(p)
  return set_pattern_metatable(original_P(p))
end

-- Add additional operators which won't really work in the fallback
-- but prevent errors when code tries to use them
M.B = M.P
M.Carg = M.P
M.Cb = M.P
M.Cc = M.P
M.Cf = M.P
M.Cg = M.P
M.Cp = M.P
M.Cs = M.P
M.T = M.P
M.locale = function() return {} end
M.release = M.version

-- Add error label functions (won't work in fallback)
M.T = function() error("T not supported in fallback") end
M.Rec = function() error("Rec not supported in fallback") end
M.RecT = function() error("RecT not supported in fallback") end
M.setlabels = function() error("setlabels not supported in fallback") end

return M