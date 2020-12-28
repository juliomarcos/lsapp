local dbg = {}

function dbg.print_src_name(info, last_char)
    last_char = last_char or '\n'
    io.write(info.source, ':', info.currentline, ':', info.name, '()', last_char)
end

function dbg.logarr(arr)
    dbg.print_src_name(debug.getinfo(2))

    io.write('[')
    for _, t in ipairs(arr) do
        io.write(tostring(t) .. ', ')
    end
    print(']')
end

local function pretty_print_obj(obj, level, print_start)
    level = level or 0
    local indentation = string.rep('   ', level)
    if print_start then
        print(indentation .. '{')
    end

    for k, v in pairs(obj) do
        local inner_indentation = indentation .. '   '
        if type(v) == 'table' then
            print(string.format(inner_indentation .. "'%s': {", k))
            pretty_print_obj(v, level + 1, false)
        else
            local next_comma = next(obj, k)~=nil and ',' or ''
            print(string.format("%s'%s': \"%s\"" .. next_comma, inner_indentation, k, tostring(v)))
        end
    end
    print(indentation .. '}')
end

function dbg.logobj(obj)
    dbg.print_src_name(debug.getinfo(2))
    pretty_print_obj(obj, 0, true)
end

return dbg

