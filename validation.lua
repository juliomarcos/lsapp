local vl = {}

function vl.valid_line_name(name)
    return name and #name > 1 and name:sub(1,1) == 'l'
end

vl.Charsets = {
    Operations = '[%+%-%*/]'
}

return vl