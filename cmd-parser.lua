local log = require('log')
local ast = require('ast')
local vl = require('validation')
local lexer = require('lin-lexer')
local Tape = require('tape-buffer').Tape

local cmd = {}

local CmdTokens = {
    Quit = 'quit',
    Undo = 'undo',
    Identifier = 'identifier',
    Assignment = 'assignment',
    Swap = 'swap',
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
    elseif literal == 's' or literal == 'swap' then
        return lexer.produce_token(CmdTokens.Swap)
    elseif literal == 'u' or literal == 'undo' then
        return lexer.produce_token(CmdTokens.Undo)
    else
        return lexer.produce_token(CmdTokens.Identifier, literal)
    end
end

local function read_unary_sign(c, cmd_token)
    return lexer.produce_token(cmd_token, c)
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
            token = read_unary_sign(c, CmdTokens.Assignment)
        -- is it an identifier (keywords/commands also go here)?
        elseif c:match('%a') then
            token = read_identifier(c, tape)
        -- is it an operator?
        elseif c == '-' then
            -- might be an operator, a negative number or a negative line
            local d = tape:get_next_char()
            if d:match('%d') then
                tape:rotate(-1)
                token = lexer.read_number('-', tape)
            elseif d:match('%a') then
                all_tokens[#all_tokens + 1] = read_operator('-')
                token = read_identifier(d, tape)
            else
                token = read_unary_sign(c, CmdTokens.Operator)
            end
        elseif c:match('[%+%*/]') then
            token = read_unary_sign(c, CmdTokens.Operator)
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

local function parse_identifier(expr_tokens)
    return {
        type = ast.NodeTypes.LineReference,
        identifier = expr_tokens:next_token().literal
    }
end

local function parse_assignment(expr_tokens)
    local line_target = parse_identifier(expr_tokens)
    expr_tokens:next_token() -- assignment operator
    local expr = parse_expression(expr_tokens)
    return {
        type = ast.NodeTypes.Assignment,
        lvalue = line_target.identifier,
        expression = expr
    }
end

local function parse_line_operation(expr_tokens)
    local line_target = find_line_target(expr_tokens)
    local expression = parse_expression(expr_tokens)
    --dbg.logobj(expression)
    return ast.line_op(line_target, expression)
end

local function parse_keyword_cmd(expr_tokens)
    local keyword = expr_tokens:next_token()
    return ast.keyword_cmd(keyword.type)
end

local function parse_assignment_or_self_assignment(expr_tokens)
    local line_target = parse_identifier(expr_tokens)
    local next_token = expr_tokens:next_token()
    if next_token.type == CmdTokens.Assignment then
        expr_tokens:rewind()
        return parse_assignment(expr_tokens)
    else
        expr_tokens:rewind()
        local expr = parse_expression(expr_tokens)
        return {
            type = ast.NodeTypes.Assignment,
            lvalue = line_target.identifier,
            expression = expr
        }
    end
end

local function parse_unary_negate(expr_tokens)
    local operation = expr_tokens:next_token()
    if operation.literal ~= '-' then
        local msg = string.format('the only unary operator supported is "-". "%s" was given instead.',
                operation.literal)
        return log.se(msg)
    end

    local identifier_tok = expr_tokens:next_token()
    if identifier_tok.type ~= CmdTokens.Identifier then
        return log.se('a line identifier was expected. found ' .. identifier_tok.literal)
    end

    return {
        type = ast.NodeTypes.Assignment,
        lvalue = identifier_tok.literal,
        expression = ast.operation(
                ast.value_node(lexer.produce_token(CmdTokens.Number, '-1')),
                '*',
                ast.line_ref_node(identifier_tok))
    }
end

local function promote_number_to_line_identifier(token)
    if token.type == CmdTokens.Number then
        return lexer.produce_token(CmdTokens.Identifier, 'l' .. token.literal)
    else
        return token
    end
end

local function parse_swap_lines_operation(expr_tokens)
    expr_tokens:next_token() -- swap token
    local line_a_identifier = expr_tokens:next_token()
    local line_b_identifier = expr_tokens:next_token()

    line_a_identifier = promote_number_to_line_identifier(line_a_identifier)
    line_b_identifier = promote_number_to_line_identifier(line_b_identifier)

    if line_a_identifier.type ~= CmdTokens.Identifier then
        return log.se('a line identifier was expected. found' .. line_a_identifier.type)
    end
    if line_b_identifier.type ~= CmdTokens.Identifier then
        return log.se('a line identifier was expected. found' .. line_b_identifier.type)
    end

    return {
        type = ast.NodeTypes.Swap,
        a = line_a_identifier.literal,
        b = line_b_identifier.literal,
    }
end

local command_parsers = {
    [CmdTokens.Identifier] = parse_assignment_or_self_assignment,
    [CmdTokens.Operator] = parse_unary_negate,
    [CmdTokens.Number] = parse_line_operation,
    [CmdTokens.Quit] = parse_keyword_cmd,
    [CmdTokens.Undo] = parse_keyword_cmd,
    [CmdTokens.Swap] = parse_swap_lines_operation,
}

function cmd.parse(expr_tokens)
    --log.d('parse_command(..)')
    --dbg.logobj(expr_tokens)

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