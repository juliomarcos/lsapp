local log = require('log')
local dbg = require('dbg')
local ast = require('ast')

local exe = {}

local function graceful_quit()
    os.exit(0)
end

local function no_op_exe()
    log.d('no op')
end

local function process_add(expression)

end

local function process_sub(expression)

end

local function produce_virtual_line(ref_node)

end

local function process_mul(lhs, rhs)
    local value_node, ref_node
    if lhs.type == ast.NodeTypes.Value then
        value_node = lhs
        ref_node = rhs
    else
        value_node = rhs
        ref_node = lhs
    end

    local virtual_line = ref_node.line
    if ref_node.type == ast.NodeTypes.LineReference then

    end
end

local function process_div(expression)

end

local Operations = {
    ["+"] = process_add,
    ["-"] = process_sub,
    ["*"] = process_mul,
    ["/"] = process_div,
}


local function process_expression(node)
    dbg.logobj(node)

    local op_fn = Operations[node.op]
    op_fn(node.lhs, node.rhs)

    -- leaf node
    
end

local function self_assignment_exe(node)
    log.d('[exe] will operate on line: ', node.target)
    process_expression(node.expression)
end

local function operation_exe(node)

end

local node_executors = {
    [ast.NodeTypes.NoOp] = no_op_exe,
    [ast.NodeTypes.SelfAssignment] = self_assignment_exe,
    [ast.NodeTypes.Operation] = operation_exe,
    [ast.NodeTypes.Quit] = graceful_quit
}

function exe.interpret_node(node)
    local executor = node_executors[node.type]
    executor(node)
end


return exe