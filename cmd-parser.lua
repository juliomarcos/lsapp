local log = require('log')
local ast = require('ast')
local vl = require('validation')
local lexer = require('lin-lexer')
local dbg = require('dbg')
local Tape = require('tape-buffer').Tape

local cmd = {}

local CmdTokens = {
    Quit = 'quit',
    Identifier = 'identifier',
    Assignment = 'assignment',
    Operator = 'operator',
    Number = 'number',
    NoOp = 'nop',
}

local function read_identifier(c, buffer)
    local name = { c }
    while buffer:has_data() do
        local c = buffer:get_next_char()
        if c:match(vl.Charsets.Operations) then
            buffer:rotate(-1)
            goto produce_token
        elseif not c:match('%s') then
            name[#name + 1] = c
        else
            goto produce_token
        end
    end

    :: produce_token ::
    local literal = table.concat(name)
    if literal == 'q' or literal == 'quit' then
        return lexer.produce_token(CmdTokens.Quit)
    else
        return lexer.produce_token(CmdTokens.Identifier, literal)
    end
end

local function read_operator(c)
    return lexer.produce_token(CmdTokens.Operator, c)
end

local function read_assignment_sign(c)
    return lexer.produce_token(CmdTokens.Assignment, c)
end

function cmd.lex(input)
    local tape = Tape.new(input)
    local all_tokens = {}

    while tape:has_data() do
        :: read_next_char ::
        local c = tape:get_next_char()
        -- eat whitespaces
        if c:match('%s') then
            goto read_next_char
        end

        local token

        -- is it an assignment sign
        if c == '=' then
            token = read_assignment_sign(c)
            -- is it an identifier?
        elseif c:match('%a') then
            token = read_identifier(c, tape)
            -- is it an operator?
        elseif c:match('[%+%-%*/]') then
            token = read_operator(c)
            -- only other choice is number
        else
            token = lexer.read_number(c, tape)
        end

        all_tokens[#all_tokens + 1] = token
    end

    return Tape.new(all_tokens)
end

local OpsPrecedence = {
    ['*'] = 2,
    ['/'] = 2,
    ['+'] = 1,
    ['-'] = 1,
}

local function tok_precedence(tok)
    if tok == nil then return 0 end
    return OpsPrecedence[tok.literal] or 0
end

local function parse_expression(expr_tape, last_op_token)
    local tok = expr_tape:next_token()

    local left
    if vl.valid_line_name(tok.literal) then
        left = ast.line_ref_node(tok)
    else
        left = ast.value_node(tok)
    end

    while expr_tape:has_data() do
        local next_tok = expr_tape:peek_token()
        local next_precedence = tok_precedence(next_tok)
        local cur_precedence = tok_precedence(last_op_token)
        if next_tok.type == CmdTokens.Operator and next_precedence > cur_precedence then
            expr_tape:rotate(1) -- consumes operator
            local op = next_tok.literal
            local right = parse_expression(expr_tape, next_tok)
            left = ast.operation(left, op, right)
        else
            return left
        end
    end

    return left
end

local function find_line_target(expr_tape)
    local first_found
    while expr_tape:has_data() do
        local tok = expr_tape:next_token()
        if vl.valid_line_name(tok.literal) then
            first_found = tok.literal
            goto finish
        end
    end

    ::finish::
    if first_found == nil then
        return log.se("couldn't find any line identifier.")
    end

    expr_tape:rewind()
    return {
        type = ast.NodeTypes.LineIdentifier,
        identifier = first_found
    }
end

local function parse_line_operation(expr_tokens)
    local line_target = find_line_target(expr_tokens)
    local expression = parse_expression(expr_tokens)
    --dbg.logobj(expression)
    return ast.line_op(line_target, expression)
end

local function parse_keyword_cmd(keyword)
    return ast.keyword_cmd(keyword.type)
end

local function parse_line_assignment(expr_tokens)
end

local command_parsers = {
    [CmdTokens.Identifier] = parse_line_operation,
    [CmdTokens.Number] = parse_line_operation,
    [CmdTokens.Quit] = parse_keyword_cmd
}

function cmd.parse(expr_tokens)
    log.d('parse_command(..)')
    dbg.logobj(expr_tokens)
    local token = expr_tokens:next_token()
    if token == nil then return ast.no_op_node end

    local parse_fn = command_parsers[token.type]
    if parse_fn == nil then
        if token.type == CmdTokens.Assignment then
            local previous_tok = expr_tokens:prev_token()
            local what = 'nothing.'
            if expr_tokens.i ~= 1 then
                what = previous_tok.literal
            end

            log.se(string.format('a line name (l1, l2, ...) was expected before the = sign, got %s', what))
        end
        return ast.no_op_node
    end

    expr_tokens:rotate(-1)
    return parse_fn(expr_tokens)
end

return cmd