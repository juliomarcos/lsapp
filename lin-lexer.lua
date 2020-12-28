local Tape = require('tape-buffer').Tape
local vl = require('validation')

local lexer = {}

local LinTokens = {
    Number = "number",
    EndEquation = "end_equation"
}
lexer.LinTokens = LinTokens

local token_meta = {
    __tostring = function(self)
        return string.format("[%s]: '%s'", self.type, self.literal)
    end
}

function lexer.produce_token(type, literal)
    local token = {
        type = type,
        literal = literal
    }
    setmetatable(token, token_meta)
    return token
end

function lexer.read_number(first_digit, tape)
    local digits = { first_digit }
    while tape:has_data() do
        local c = tape:get_next_char()
        if not (c:match('%s') or c:match(vl.Charsets.Operations)) then
            digits[#digits + 1] = c
        else
            tape:rotate(-1)
            goto produce_literal
        end
    end
    :: produce_literal ::
    local literal = table.concat(digits)
    return lexer.produce_token(LinTokens.Number, literal)
end

function lexer.read_file(filename)
    local all_tokens = {}

    for line in io.lines(filename) do
        local line_buffer = Tape.new(line)
        while line_buffer:has_data() do
            local c = line_buffer:get_next_char()
            if c ~= ' ' then
                local token = lexer.read_number(c, line_buffer)
                all_tokens[#all_tokens + 1] = token
            end
        end
        local end_eq_token = lexer.produce_token(LinTokens.EndEquation)
        all_tokens[#all_tokens + 1] = end_eq_token
    end

    return all_tokens
end

return lexer