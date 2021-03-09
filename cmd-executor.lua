local log = require('log')
local ast = require('ast')
local fn = require('functional')

local history = {}
local exe = {}
local CmdExecutor = {}
CmdExecutor.__index = CmdExecutor

function CmdExecutor.new(equations)
    local self = {
        system = equations
    }
    setmetatable(self, CmdExecutor)
    return self
end

local function graceful_quit()
    os.exit(0)
end

local function no_op_exe()
    log.d('no op')
end

local function process_add(system, lhs, rhs)
    if lhs.type ~= rhs.type then
        return log.se('undefined operation, both operands must be line references.')
    end

    local result = {}
    for i=1, #lhs.line do
        result[i] = lhs.line[i] + rhs.line[i]
    end
    return result
end

local function process_sub(system, lhs, rhs)
    if lhs.type ~= rhs.type then
        return log.se('undefined operation, both operands must be line references.')
    end

    local result = {}
    for i=1, #lhs.line do
        result[i] = lhs.line[i] - rhs.line[i]
    end
    return result
end

local function process_mul(system, lhs, rhs)
    local value_node, ref_node
    if lhs.type == rhs.type then
        return log.se('undefined operation, one of the two operands must be a line ref and the other a value.')
    end

    if lhs.type == ast.NodeTypes.Value then
        value_node = lhs
        ref_node = rhs
    else
        value_node = rhs
        ref_node = lhs
    end

    local virtual_line = ref_node.line
    local value = value_node.value
    for k, v in pairs(virtual_line) do
        virtual_line[k] = v*value
    end
end

local function process_div(system, lhs, rhs)
    local value_node, ref_node
    if lhs.type == rhs.type then
        return log.se('undefined operation, one of the two operands must be a line ref and the other a value.')
    end

    if lhs.type == ast.NodeTypes.Value then
        value_node = lhs
        ref_node = rhs
    else
        value_node = rhs
        ref_node = lhs
    end

    local virtual_line = ref_node.line
    local value = value_node.value
    for k, v in pairs(virtual_line) do
        local new_value = v/value
        if math.abs(new_value - math.tointeger(new_value)) < 0.0001 then
            new_value = math.tointeger(new_value)
        end
        virtual_line[k] = new_value
    end
end

local Operations = {
    ["+"] = process_add,
    ["-"] = process_sub,
    ["*"] = process_mul,
    ["/"] = process_div,
}

local function amplify_line_refs(system, node)
    local function amplify_line_refs_dfs(node)
        if node.type == ast.NodeTypes.LineReference then
            node.type = ast.NodeTypes.VirtualLine
            local line_number = tonumber(node.ref:sub(2))
            node.ref = nil
            node.line = fn.dup(system[line_number])
        end
        if node.lhs then
            amplify_line_refs_dfs(node.lhs)
        end
        if node.rhs then
            amplify_line_refs_dfs(node.rhs)
        end
    end

    amplify_line_refs_dfs(node)
end

local function reduce_node(node, operation_result)
    if operation_result ~= nil then
        return {
            type = ast.NodeTypes.VirtualLine,
            line = operation_result
        }
    end

    local virtual_line_node = node.lhs
    if virtual_line_node.type ~= ast.NodeTypes.VirtualLine then
        virtual_line_node = node.rhs
    end
    return virtual_line_node
end

local function process_expression(system, node)
    amplify_line_refs(system, node)

    local op_fn = Operations[node.op]

    -- recursively reduce operations
    if node.lhs.type == ast.NodeTypes.Operation then
        node.lhs = process_expression(system, node.lhs)
    end
    if node.rhs.type == ast.NodeTypes.Operation then
        node.rhs = process_expression(system, node.rhs)
    end

    local result = op_fn(system, node.lhs, node.rhs)

    return reduce_node(node, result)
end

local function self_assignment_exe(system, node)
    --log.d('[exe] will operate on line: ', node.target)
    local resulting_node = process_expression(system, node.expression)
    local target_line_number = tonumber(node.target:sub(2))
    system[target_line_number] = resulting_node.line
end

local function assignment_exe(system, node)
    local resulting_node = process_expression(system, node.expression)
    local target_line_number = tonumber(node.lvalue:sub(2))
    system[target_line_number] = resulting_node.line
end

local function swap_exe(system, node)
    local line_a = tonumber(node.a:sub(2))
    local line_b = tonumber(node.b:sub(2))
    system[line_a], system[line_b] = system[line_b], system[line_a]
end

local function undo_exe(system, node)
    local old_system = table.remove(history, #history)
    for i, row in ipairs(system) do
        for j, _ in ipairs(row) do
            row[j] = old_system[i][j]
        end
    end
end

local node_executors = {
    [ast.NodeTypes.NoOp] = no_op_exe,
    [ast.NodeTypes.Assignment] = assignment_exe,
    [ast.NodeTypes.Swap] = swap_exe,
    [ast.NodeTypes.Undo] = undo_exe,
    [ast.NodeTypes.Quit] = graceful_quit,
}

local function dup_system(original_system)
    local copy = {}
    for i, _ in ipairs(original_system) do
        local row = {}
        for j, v in ipairs(original_system[i]) do
            row[j] = v
        end
        copy[i] = row
    end
    return copy
end

function CmdExecutor.interpret_node(self, node)
    local executor_fn = node_executors[node.type]
    local system_copy = dup_system(self.system)
    local st, err = pcall(executor_fn, self.system, node)
    if not st then
        log.exr("command was parsed but couldn't be executed.")
        log.exr(err)
        self.system = system_copy
    else
        -- commit to history
        history[#history + 1] = system_copy
    end

    -- to see errors
    --executor_fn(self.system, node)
end

exe.CmdExecutor = CmdExecutor
return exe