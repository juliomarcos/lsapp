local cmd_parser = require('cmd-parser')
local exe = require('cmd-executor')
local linfmt = require('lin-format')

--require("mobdebug").start()

-- local filename = 'data/system-2-infer-0s.lin'
-- local filename = 'data/brl-3u.lin'
local filename = 'data/thaisinha-destruidora.lin'

local equations = linfmt.read_file(filename)
linfmt.pretty_print_equations(equations)

while 1 do
    --local user_input = 'l3 * 2 + l1' -- io.read()
    local user_input = 'l1 * 2' -- io.read()
    print(user_input)
    local cmd_tokens = cmd_parser.lex(user_input)
    local node = cmd_parser.parse(cmd_tokens) or exe.no_op_node
    exe.interpret_node(node)
    os.exit()
end
