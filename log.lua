local log = {}

function log.se(msg)
    print('[syntax error] ' .. msg)
    return false
end

function log.d(...)
    local msg = table.concat({...})
    print('[debug] ' .. msg)
end

return log