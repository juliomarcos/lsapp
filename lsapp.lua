local cmd_parser = require('cmd-parser')
local CmdExecutor = require('cmd-executor').CmdExecutor
local linfmt = require('lin-format')
local log = require "log"

-- local filename = 'data/system-2-infer-0s.lin'
 local filename = 'data/brl-gauss-1.lin'
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
    --require('mobdebug').start()
    local cmd_tokens = cmd_parser.lex(user_input)
    local st, node = pcall(function() return cmd_parser.parse(cmd_tokens) end)
    if not st then
        log.se "unidentified syntax error"
    else
        cmd_exe:interpret_node(node)
    end
    linfmt.pretty_print_equations(equations)
end
