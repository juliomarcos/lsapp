local fn = require('functional')
local lexer = require('lin-lexer')

local lin = {}

-- the lin format uses the equation with the most variables as the
-- definition of the number of variables, that is, on lines with
-- less variables assume that the first ones correspond do the first
-- variables and the last number as the right side of the equation
--
-- System 1. Trivial
-- 2a + 3b = 2
-- 1a - 4b = 7
--
-- Sytem 1 in lin
-- 2 3 2
-- 1 -4 7
--
-- System 1 was a trivial example. Now, let's take a look at an
-- system in which we need to infer zeroes
--
-- System 2. Assume zeros
-- -9a + 13b = 1
-- 5a + 2b + 3c + 7d -4e = 88
--
-- System 2 in lin
-- -9 13 1
-- 5 2 3 7 -4 88

local function read_equation(i, all_tokens)
    local numbers = {}
    repeat
        local token = all_tokens[i]
        numbers[#numbers + 1] = tonumber(token.literal)
        i = i + 1
    until token.type == lexer.LinTokens.EndEquation

    return i, numbers
end

function lin.read_file(filename)
    local all_tokens = lexer.read_file(filename)
    local input_equations = {}

    local i = 1
    repeat
        local ni, eq = read_equation(i, all_tokens)
        input_equations[#input_equations + 1] = eq
        i = ni
    until i > #all_tokens

    local num_equations = #input_equations

    -- find the equation with the most number of variables
    local num_numbers = fn.max_element(input_equations, function(e)
        return #e
    end)

    -- dbg.logarr(input_equations[1])

    -- now create a table to hold the equations in which
    -- calculations will be performed on
    local equations = {}

    for i = 1, num_equations do
        local equation = {}
        local input_eq = input_equations[i]

        local j = 1
        while j < #input_eq do
            local number = input_eq[j] or 0
            equation[j] = number
            j = j + 1
        end

        -- right side of the equation
        equation[num_numbers] = input_eq[#input_eq]

        -- fill the rest with zeroes
        for k = j, num_numbers - 1 do
            equation[k] = 0
        end

        equations[#equations + 1] = equation
    end

    return equations
end

local function pretty_print_equations_showing_variables(all_equations)
    local num_vars = #all_equations[1] - 1

    local first_letter = 'x'
    if num_vars >= 4 then
        first_letter = 'a'
    end

    for _, eq in pairs(all_equations) do
        local letter = first_letter

        -- print variables
        for j = 1, #eq - 1 do
            local num = eq[j]
            local fmt = '%3d'
            if math.type(num) == 'float' then
                fmt = '%3.2f'
            end
            io.write(string.format(fmt .. '%s\t', num, letter))
            letter = string.char(letter:byte() + 1)
        end

        -- print right side
        io.write('  =\t', eq[#eq])
        print()
    end
end

local function pretty_print_equations_matrix_form(all_equations)
    for _, eq in pairs(all_equations) do
        for j = 1, #eq do
            local num = eq[j]
            local fmt = math.type(num) == 'float' and '%3.2f ' or '%3d '
            io.write(string.format(fmt, num))
        end
        print""
    end
end

function lin.pretty_print_equations(all_equations, show_variables)
    if show_variables then
        pretty_print_equations_showing_variables(all_equations)
    else
        pretty_print_equations_matrix_form(all_equations)
    end
end

return lin