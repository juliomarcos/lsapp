local fn = {}

function fn.each_letter(s)
    return coroutine.wrap(function ()
        for i=1, #s do
            coroutine.yield(s:sub(i, i))
        end
    end)    
end

function fn.max_element(list, fn)
    local max = fn(list[1])
    for i = 2, #list do
        local e = list[i]
        local max_candidate = fn(e)
        if max_candidate > max then
            max = max_candidate
        end
    end
    return max
end

function fn.dup(list)
    local d = {}
    for i=1,#list do
        d[#d+1] = list[i]
    end
    return d
end

return fn