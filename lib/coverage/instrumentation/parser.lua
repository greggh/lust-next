---@class CoverageParser
---@field parse fun(source: string): table Parse Lua source code into tokens and logical lines
---@field identify_logical_lines fun(tokens: table): table Identify logical lines in token stream
---@field get_token_type fun(token: string): string Get the type of a token
---@field _VERSION string Version of this module
local M = {}

-- Dependencies
local error_handler = require("lib.tools.error_handler")
local logger = require("lib.tools.logging")
local central_config = require("lib.core.central_config")

-- Constants
local TOKEN_TYPES = {
  KEYWORD = "keyword",
  IDENTIFIER = "identifier",
  NUMBER = "number",
  STRING = "string",
  COMMENT = "comment",
  OPERATOR = "operator",
  PUNCTUATION = "punctuation",
  WHITESPACE = "whitespace",
  EOL = "eol",  -- End of line
  EOF = "eof"   -- End of file
}

-- List of Lua keywords
local KEYWORDS = {
  ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
  ["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["if"] = true,
  ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
  ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true, ["until"] = true,
  ["while"] = true
}

-- List of Lua operators
local OPERATORS = {
  ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true, ["^"] = true,
  ["#"] = true, ["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, ["<"] = true,
  [">"] = true, ["="] = true, ["("] = true, [")"] = true, ["{"] = true, ["}"] = true,
  ["["] = true, ["]"] = true, ["::"] = true, [";"] = true, [":"] = true, [","] = true,
  ["."] = true, [".."] = true, ["..."] = true
}

-- Version
M._VERSION = "0.1.0"

--- Determines the type of a token based on its content
---@param token string The token to analyze
---@return string token_type The type of the token
function M.get_token_type(token)
  -- Check if it's a keyword
  if KEYWORDS[token] then
    return TOKEN_TYPES.KEYWORD
  end
  
  -- Check if it's an operator or punctuation
  if OPERATORS[token] then
    return TOKEN_TYPES.OPERATOR
  end
  
  -- Check if it's a number (including scientific notation)
  if token:match("^%d+$") or token:match("^%d+%.%d*$") or token:match("^%d*%.%d+$") or 
     token:match("^0x[%da-fA-F]+$") or token:match("^%d+[eE][%+%-]?%d+$") or 
     token:match("^%d*%.%d+[eE][%+%-]?%d+$") or token:match("^%d+%.%d*[eE][%+%-]?%d+$") then
    return TOKEN_TYPES.NUMBER
  end
  
  -- Check if it's a string
  if (token:sub(1, 1) == '"' and token:sub(-1) == '"') or
     (token:sub(1, 1) == "'" and token:sub(-1) == "'") or
     (token:sub(1, 2) == "[[" and token:sub(-2) == "]]") or 
     (token:sub(1, 3):match("%[=*%[") and token:sub(-#token:sub(1, 3)):match("%]=*%]")) then
    return TOKEN_TYPES.STRING
  end
  
  -- Check if it's a comment
  if token:sub(1, 2) == "--" then
    if token:sub(3, 4) == "[[" or token:sub(3, 3) == "[" and token:sub(4, 4) == "=" then
      return TOKEN_TYPES.COMMENT -- Long comment
    else
      return TOKEN_TYPES.COMMENT -- Line comment
    end
  end
  
  -- Check if it's whitespace
  if token:match("^%s+$") then
    return TOKEN_TYPES.WHITESPACE
  end
  
  -- Check if it's an end of line
  if token == "\n" or token == "\r" or token == "\r\n" then
    return TOKEN_TYPES.EOL
  end
  
  -- Default to identifier for variable names, function names, etc.
  return TOKEN_TYPES.IDENTIFIER
end

--- Tokenizes Lua source code into individual tokens
---@param source string The Lua source code
---@return table tokens List of tokens with position and type information
local function tokenize(source)
  if not source then
    return {}
  end
  
  local tokens = {}
  local position = 1
  local line = 1
  local column = 1
  local source_length = #source
  
  while position <= source_length do
    local char = source:sub(position, position)
    
    -- Handle whitespace
    if char:match("%s") and char ~= "\n" and char ~= "\r" then
      local whitespace_start = position
      local whitespace = char
      
      position = position + 1
      column = column + 1
      
      -- Consume additional whitespace
      while position <= source_length and source:sub(position, position):match("%s") and 
            source:sub(position, position) ~= "\n" and source:sub(position, position) ~= "\r" do
        whitespace = whitespace .. source:sub(position, position)
        position = position + 1
        column = column + 1
      end
      
      table.insert(tokens, {
        type = TOKEN_TYPES.WHITESPACE,
        value = whitespace,
        line = line,
        column = column - #whitespace,
        position = whitespace_start
      })
    
    -- Handle end of line
    elseif char == "\n" or char == "\r" then
      local eol_start = position
      local eol = char
      
      position = position + 1
      
      -- Handle Windows-style line endings (\r\n)
      if char == "\r" and position <= source_length and source:sub(position, position) == "\n" then
        eol = eol .. "\n"
        position = position + 1
      end
      
      table.insert(tokens, {
        type = TOKEN_TYPES.EOL,
        value = eol,
        line = line,
        column = column,
        position = eol_start
      })
      
      line = line + 1
      column = 1
    
    -- Handle comments
    elseif char == "-" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "-" then
      local comment_start = position
      local comment = "--"
      
      position = position + 2
      column = column + 2
      
      -- Check for long comment --[[ ]]
      if position <= source_length and source:sub(position, position) == "[" then
        local level = 0
        
        -- Count equals signs for nesting level
        if position + 1 <= source_length and source:sub(position + 1, position + 1) == "[" then
          comment = comment .. "["
          position = position + 1
          column = column + 1
          
          comment = comment .. "["
          position = position + 1
          column = column + 1
          
          -- Parse until end of long comment
          local terminated = false
          while position <= source_length and not terminated do
            char = source:sub(position, position)
            comment = comment .. char
            
            if char == "]" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "]" then
              comment = comment .. source:sub(position + 1, position + 1)
              position = position + 2
              column = column + 2
              terminated = true
            else
              if char == "\n" or (char == "\r" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "\n") then
                if char == "\r" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "\n" then
                  comment = comment .. source:sub(position + 1, position + 1)
                  position = position + 1
                end
                line = line + 1
                column = 1
              else
                column = column + 1
              end
              position = position + 1
            end
          end
        elseif position + 1 <= source_length and source:sub(position + 1, position + 1) == "=" then
          -- Handle [=[...]=] style comments with equals signs
          comment = comment .. "["
          position = position + 1
          column = column + 1
          
          local equals_count = 0
          while position <= source_length and source:sub(position, position) == "=" do
            comment = comment .. "="
            equals_count = equals_count + 1
            position = position + 1
            column = column + 1
          end
          
          if position <= source_length and source:sub(position, position) == "[" then
            comment = comment .. "["
            position = position + 1
            column = column + 1
            
            -- Look for matching closing pattern
            local close_pattern = "]" .. string.rep("=", equals_count) .. "]"
            local terminated = false
            
            while position <= source_length and not terminated do
              local chunk = source:sub(position, position + #close_pattern - 1)
              
              if chunk == close_pattern then
                comment = comment .. chunk
                position = position + #close_pattern
                column = column + #close_pattern
                terminated = true
              else
                char = source:sub(position, position)
                comment = comment .. char
                
                if char == "\n" or (char == "\r" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "\n") then
                  if char == "\r" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "\n" then
                    comment = comment .. source:sub(position + 1, position + 1)
                    position = position + 1
                  end
                  line = line + 1
                  column = 1
                else
                  column = column + 1
                end
                position = position + 1
              end
            end
          else
            -- Not a properly formed long comment, treat as line comment
            while position <= source_length and source:sub(position, position) ~= "\n" and source:sub(position, position) ~= "\r" do
              comment = comment .. source:sub(position, position)
              position = position + 1
              column = column + 1
            end
          end
        else
          -- Regular single-line comment
          while position <= source_length and source:sub(position, position) ~= "\n" and source:sub(position, position) ~= "\r" do
            comment = comment .. source:sub(position, position)
            position = position + 1
            column = column + 1
          end
        end
      else
        -- Regular single-line comment
        while position <= source_length and source:sub(position, position) ~= "\n" and source:sub(position, position) ~= "\r" do
          comment = comment .. source:sub(position, position)
          position = position + 1
          column = column + 1
        end
      end
      
      table.insert(tokens, {
        type = TOKEN_TYPES.COMMENT,
        value = comment,
        line = line,
        column = column - #comment,
        position = comment_start
      })
    
    -- Handle strings
    elseif char == "'" or char == '"' then
      local string_start = position
      local str = char
      local string_delimiter = char
      
      position = position + 1
      column = column + 1
      
      local escaped = false
      local terminated = false
      
      while position <= source_length and not terminated do
        char = source:sub(position, position)
        str = str .. char
        
        if escaped then
          escaped = false
        elseif char == "\\" then
          escaped = true
        elseif char == string_delimiter then
          terminated = true
        elseif char == "\n" or char == "\r" then
          -- Strings can't span multiple lines unless using escape sequences
          -- For simplicity, we'll just handle this as a terminated string
          break
        end
        
        position = position + 1
        column = column + 1
      end
      
      table.insert(tokens, {
        type = TOKEN_TYPES.STRING,
        value = str,
        line = line,
        column = column - #str,
        position = string_start
      })
    
    -- Handle long strings [[ ]]
    elseif char == "[" and position + 1 <= source_length and 
           (source:sub(position + 1, position + 1) == "[" or source:sub(position + 1, position + 1) == "=") then
      local string_start = position
      local str = "["
      
      position = position + 1
      column = column + 1
      
      -- Count equals signs for nesting level
      local equals_count = 0
      while position <= source_length and source:sub(position, position) == "=" do
        str = str .. "="
        equals_count = equals_count + 1
        position = position + 1
        column = column + 1
      end
      
      if position <= source_length and source:sub(position, position) == "[" then
        str = str .. "["
        position = position + 1
        column = column + 1
        
        -- Look for matching closing pattern
        local close_pattern = "]" .. string.rep("=", equals_count) .. "]"
        local terminated = false
        
        while position <= source_length and not terminated do
          local chunk = source:sub(position, position + #close_pattern - 1)
          
          if chunk == close_pattern then
            str = str .. chunk
            position = position + #close_pattern
            column = column + #close_pattern
            terminated = true
          else
            char = source:sub(position, position)
            str = str .. char
            
            if char == "\n" or (char == "\r" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "\n") then
              if char == "\r" and position + 1 <= source_length and source:sub(position + 1, position + 1) == "\n" then
                str = str .. source:sub(position + 1, position + 1)
                position = position + 1
              end
              line = line + 1
              column = 1
            else
              column = column + 1
            end
            position = position + 1
          end
        end
        
        table.insert(tokens, {
          type = TOKEN_TYPES.STRING,
          value = str,
          line = line,
          column = column - #str,
          position = string_start
        })
      else
        -- Not a properly formed long string, treat as operator
        table.insert(tokens, {
          type = TOKEN_TYPES.OPERATOR,
          value = "[",
          line = line,
          column = column - 1,
          position = string_start
        })
        
        -- Process equals signs as separate operators
        for i = 1, equals_count do
          table.insert(tokens, {
            type = TOKEN_TYPES.OPERATOR,
            value = "=",
            line = line,
            column = column - equals_count + i - 1,
            position = string_start + i
          })
        end
      end
    
    -- Handle numeric literals
    elseif char:match("%d") then
      local number_start = position
      local number = char
      
      position = position + 1
      column = column + 1
      
      -- Handle decimal part
      local has_decimal = false
      local has_exponent = false
      
      while position <= source_length do
        char = source:sub(position, position)
        
        -- Handle hexadecimal numbers (0x...)
        if number == "0" and char:lower() == "x" then
          number = number .. char
          position = position + 1
          column = column + 1
          
          -- Parse hexadecimal digits
          while position <= source_length and source:sub(position, position):match("[%da-fA-F]") do
            number = number .. source:sub(position, position)
            position = position + 1
            column = column + 1
          end
          break
        end
        
        -- Handle decimal point
        if char == "." and not has_decimal and not has_exponent then
          number = number .. char
          has_decimal = true
          position = position + 1
          column = column + 1
          goto continue_number
        end
        
        -- Handle exponent
        if (char:lower() == "e") and not has_exponent then
          number = number .. char
          has_exponent = true
          position = position + 1
          column = column + 1
          
          -- Handle optional sign in exponent
          if position <= source_length and (source:sub(position, position) == "+" or source:sub(position, position) == "-") then
            number = number .. source:sub(position, position)
            position = position + 1
            column = column + 1
          end
          
          -- Parse exponent digits
          local has_exponent_digits = false
          while position <= source_length and source:sub(position, position):match("%d") do
            number = number .. source:sub(position, position)
            has_exponent_digits = true
            position = position + 1
            column = column + 1
          end
          
          -- If no digits after e, it's not a valid number
          if not has_exponent_digits then
            -- Roll back the exponent part
            number = number:sub(1, -2)
            position = position - 1
            column = column - 1
            has_exponent = false
          end
          
          break
        end
        
        -- Handle digits
        if char:match("%d") then
          number = number .. char
          position = position + 1
          column = column + 1
        else
          break
        end
        
        ::continue_number::
      end
      
      table.insert(tokens, {
        type = TOKEN_TYPES.NUMBER,
        value = number,
        line = line,
        column = column - #number,
        position = number_start
      })
    
    -- Handle operators and punctuation
    elseif OPERATORS[char] or char:match("[%(%);,%[%]{}%.]") then
      local op_start = position
      local op = char
      
      position = position + 1
      column = column + 1
      
      -- Handle multi-character operators
      if char == "." and position <= source_length and source:sub(position, position) == "." then
        op = op .. "."
        position = position + 1
        column = column + 1
        
        -- Handle ... (varargs)
        if position <= source_length and source:sub(position, position) == "." then
          op = op .. "."
          position = position + 1
          column = column + 1
        end
      elseif char == "=" and position <= source_length and source:sub(position, position) == "=" then
        op = op .. "="
        position = position + 1
        column = column + 1
      elseif char == "~" and position <= source_length and source:sub(position, position) == "=" then
        op = op .. "="
        position = position + 1
        column = column + 1
      elseif char == "<" and position <= source_length and source:sub(position, position) == "=" then
        op = op .. "="
        position = position + 1
        column = column + 1
      elseif char == ">" and position <= source_length and source:sub(position, position) == "=" then
        op = op .. "="
        position = position + 1
        column = column + 1
      elseif char == ":" and position <= source_length and source:sub(position, position) == ":" then
        op = op .. ":"
        position = position + 1
        column = column + 1
      end
      
      table.insert(tokens, {
        type = TOKEN_TYPES.OPERATOR,
        value = op,
        line = line,
        column = column - #op,
        position = op_start
      })
    
    -- Handle identifiers and keywords
    elseif char:match("[%a_]") then
      local id_start = position
      local id = char
      
      position = position + 1
      column = column + 1
      
      while position <= source_length and source:sub(position, position):match("[%a%d_]") do
        id = id .. source:sub(position, position)
        position = position + 1
        column = column + 1
      end
      
      -- Determine if it's a keyword or an identifier
      local token_type = KEYWORDS[id] and TOKEN_TYPES.KEYWORD or TOKEN_TYPES.IDENTIFIER
      
      table.insert(tokens, {
        type = token_type,
        value = id,
        line = line,
        column = column - #id,
        position = id_start
      })
    
    -- Handle any other characters
    else
      table.insert(tokens, {
        type = TOKEN_TYPES.OPERATOR, -- Default to operator for unrecognized characters
        value = char,
        line = line,
        column = column,
        position = position
      })
      
      position = position + 1
      column = column + 1
    end
  end
  
  -- Add EOF token
  table.insert(tokens, {
    type = TOKEN_TYPES.EOF,
    value = "",
    line = line,
    column = column,
    position = position
  })
  
  return tokens
end

--- Identifies logical lines in a token stream
---@param tokens table The token stream
---@return table logical_lines List of logical lines with their tokens
function M.identify_logical_lines(tokens)
  if not tokens or #tokens == 0 then
    return {}
  end
  
  local logical_lines = {}
  local current_line = {
    tokens = {},
    line_number = tokens[1].line,
    start_position = tokens[1].position,
    end_position = 0,
    is_statement = false,
    is_expression = false,
    is_executable = false
  }
  
  local is_in_multiline_string = false
  local is_in_multiline_comment = false
  local block_level = 0
  local statement_keywords = {
    ["if"] = true, ["for"] = true, ["while"] = true, ["repeat"] = true,
    ["function"] = true, ["local"] = true, ["return"] = true,
    ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
    ["end"] = true, ["until"] = true
  }
  
  for i, token in ipairs(tokens) do
    -- Skip EOF token
    if token.type == TOKEN_TYPES.EOF then
      break
    end
    
    -- Handle multiline strings
    if token.type == TOKEN_TYPES.STRING and (token.value:sub(1, 2) == "[[" or token.value:match("^%[=+%[")) then
      local lines_in_string = 0
      for _ in token.value:gmatch("\n") do
        lines_in_string = lines_in_string + 1
      end
      
      if lines_in_string > 0 then
        is_in_multiline_string = true
      end
    end
    
    -- Handle multiline comments
    if token.type == TOKEN_TYPES.COMMENT and (token.value:sub(1, 4) == "--[[" or token.value:match("^%-%-%[=+%[")) then
      local lines_in_comment = 0
      for _ in token.value:gmatch("\n") do
        lines_in_comment = lines_in_comment + 1
      end
      
      if lines_in_comment > 0 then
        is_in_multiline_comment = true
      end
    end
    
    -- Track block level for statement detection
    if token.type == TOKEN_TYPES.KEYWORD then
      if token.value == "do" or token.value == "then" or token.value == "function" or token.value == "repeat" then
        block_level = block_level + 1
      elseif token.value == "end" or token.value == "until" then
        block_level = math.max(0, block_level - 1)
      end
    elseif token.type == TOKEN_TYPES.OPERATOR then
      if token.value == "{" then
        block_level = block_level + 1
      elseif token.value == "}" then
        block_level = math.max(0, block_level - 1)
      end
    end
    
    -- Add token to current line
    table.insert(current_line.tokens, token)
    current_line.end_position = token.position + #token.value
    
    -- Mark as statement if it contains a statement keyword
    if token.type == TOKEN_TYPES.KEYWORD and statement_keywords[token.value] then
      current_line.is_statement = true
      current_line.is_executable = true
    end
    
    -- Check for expressions (assignments, function calls, etc.)
    if (token.type == TOKEN_TYPES.OPERATOR and (token.value == "=" or token.value == "(" or token.value == "[" or token.value == "{")) or
       (token.type == TOKEN_TYPES.IDENTIFIER and i < #tokens and tokens[i+1].type == TOKEN_TYPES.OPERATOR and tokens[i+1].value == "(") then
      current_line.is_expression = true
      current_line.is_executable = true
    end
    
    -- Check for end of logical line
    if token.type == TOKEN_TYPES.EOL and not is_in_multiline_string and not is_in_multiline_comment then
      -- End of physical line
      if i < #tokens and (tokens[i+1].type == TOKEN_TYPES.EOL or tokens[i+1].line > token.line) then
        -- Empty line or end of current line
        if #current_line.tokens > 0 then
          table.insert(logical_lines, current_line)
        end
        
        -- Start a new logical line
        current_line = {
          tokens = {},
          line_number = tokens[i+1].line,
          start_position = tokens[i+1].position,
          end_position = 0,
          is_statement = false,
          is_expression = false,
          is_executable = false
        }
      end
    elseif token.type == TOKEN_TYPES.OPERATOR and token.value == ";" then
      -- Explicit statement terminator
      if #current_line.tokens > 0 then
        current_line.is_executable = true
        table.insert(logical_lines, current_line)
      end
      
      -- Start a new logical line (same physical line)
      if i < #tokens and tokens[i+1].line == token.line then
        current_line = {
          tokens = {},
          line_number = token.line,
          start_position = tokens[i+1].position,
          end_position = 0,
          is_statement = false,
          is_expression = false,
          is_executable = false
        }
      else if i < #tokens then
        -- Next token is on a new line
        current_line = {
          tokens = {},
          line_number = tokens[i+1].line,
          start_position = tokens[i+1].position,
          end_position = 0,
          is_statement = false,
          is_expression = false,
          is_executable = false
        }
      end
      end
    end
    
    -- Reset multiline flags if we've processed the entire multiline token
    if is_in_multiline_string and token.type == TOKEN_TYPES.STRING and 
       (token.value:sub(-2) == "]]" or token.value:match("%]=+%]$")) then
      is_in_multiline_string = false
    end
    
    if is_in_multiline_comment and token.type == TOKEN_TYPES.COMMENT and 
       (token.value:sub(-2) == "]]" or token.value:match("%]=+%]$")) then
      is_in_multiline_comment = false
    end
  end
  
  -- Add the last logical line if it's not empty
  if #current_line.tokens > 0 then
    table.insert(logical_lines, current_line)
  end
  
  return logical_lines
end

--- Parse Lua source code into tokens and logical lines
---@param source string The Lua source code
---@return table result Parsed representation of the code
function M.parse(source)
  -- Parameter validation
  error_handler.assert(type(source) == "string", "source must be a string", error_handler.CATEGORY.VALIDATION)
  
  -- Tokenize the source code
  local tokens = tokenize(source)
  
  -- Identify logical lines
  local logical_lines = M.identify_logical_lines(tokens)
  
  -- Calculate line metadata
  local lines = {}
  local line_is_executable = {}
  local line_is_comment = {}
  local line_is_blank = {}
  
  for i, line in ipairs(logical_lines) do
    local line_number = line.line_number
    
    if not lines[line_number] then
      lines[line_number] = {
        content = "",
        is_executable = false,
        is_comment = false,
        is_blank = true,
        tokens = {}
      }
    end
    
    -- Combine token values to get line content
    for _, token in ipairs(line.tokens) do
      lines[line_number].content = lines[line_number].content .. token.value
      table.insert(lines[line_number].tokens, token)
      
      -- Update line type flags
      if token.type == TOKEN_TYPES.COMMENT then
        lines[line_number].is_comment = true
      elseif token.type ~= TOKEN_TYPES.WHITESPACE and token.type ~= TOKEN_TYPES.EOL then
        lines[line_number].is_blank = false
      end
    end
    
    -- Mark line as executable based on logical line analysis
    if line.is_executable then
      lines[line_number].is_executable = true
      line_is_executable[line_number] = true
    end
    
    -- Mark as comment if it only contains comments and whitespace
    local has_code = false
    for _, token in ipairs(line.tokens) do
      if token.type ~= TOKEN_TYPES.COMMENT and token.type ~= TOKEN_TYPES.WHITESPACE and token.type ~= TOKEN_TYPES.EOL then
        has_code = true
        break
      end
    end
    
    if not has_code and not lines[line_number].is_blank then
      lines[line_number].is_comment = true
      line_is_comment[line_number] = true
    end
    
    -- Keep track of blank lines
    if lines[line_number].is_blank then
      line_is_blank[line_number] = true
    end
  end
  
  return {
    tokens = tokens,
    logical_lines = logical_lines,
    lines = lines,
    line_is_executable = line_is_executable,
    line_is_comment = line_is_comment,
    line_is_blank = line_is_blank
  }
end

return M