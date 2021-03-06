local cmd_parser = require('cmd-parser')
local CmdExecutor = require('cmd-executor').CmdExecutor
local linfmt = require('lin-format')
local ast = require('ast')

-- local filename = 'data/system-2-infer-0s.lin'
 local filename = 'data/brl-3u.lin'
--local filename = 'data/thaisinha-destruidora.lin'

local equations = linfmt.read_file(filename)
linfmt.pretty_print_equations(equations)

local cmd_exe = CmdExecutor.new(equations)

while 1 do
    --local user_input = 'l3 * 2 + l1'
    --local user_input = '2 * l1'
    --local user_input = 'l3 + 2*l1'
    --local user_input = '-l3'
    --print(user_input)
    local user_input = io.read()
    local cmd_tokens = cmd_parser.lex(user_input)
    local node = cmd_parser.parse(cmd_tokens) or ast.no_op_node
    cmd_exe:interpret_node(node)
    linfmt.pretty_print_equations(equations)
end
