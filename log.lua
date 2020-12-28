local dbg = require('dbg')

local log = {}

function log.se(msg)
    dbg.print_src_name(debug.getinfo(2), ' -- ')
    print('[syntax error] ' .. msg)
    return false
end

function log.d(...)
    dbg.print_src_name(debug.getinfo(2), ' -- ')
    local msg = table.concat({...})
    print('[debug] ' .. msg)
end

return log