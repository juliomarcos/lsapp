local log = require('log')
local vl = require('validation')

local ast = {}

ast.NodeTypes = {
    Value = 'value',
    LineReference = 'line_ref',
    VirtualLine = 'virtual_line',
    Assignment = 'assignment',
    Swap = 'swap',
    Operation = 'operation',
    NoOp = 'nop',
    Quit = 'quit',
    Undo = 'undo',
}

function ast.line_op(line_target, expression)
    if not vl.valid_line_name(line_target.identifier) then
        return log.se(string.format('"%s" is an invalid line name.', line_target.identifier))
    end
    return {
        type = ast.NodeTypes.Assignment,
        lvalue = line_target.identifier,
        expression = expression
    }
end

function ast.operation(lhs_node, operation, rhs_node)
    return {
        type = ast.NodeTypes.Operation,
        lhs = lhs_node,
        op = operation,
        rhs = rhs_node
    }
end

function ast.no_op()
    return {
        type = ast.NodeTypes.NoOp
    }
end

function ast.keyword_cmd(keyword)
    return {
        type = keyword
    }
end

function ast.value_node(tok)
    return {
        type = ast.NodeTypes.Value,
        value = tok.literal
    }
end

function ast.line_ref_node(tok)
    return {
        type = ast.NodeTypes.LineReference,
        ref = tok.literal
    }
end

ast.no_op_node = ast.no_op()

return ast