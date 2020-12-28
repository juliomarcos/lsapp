local Tape = {}
Tape.__index = Tape

function Tape.new(sequence)
    local self = {
        data = sequence,
        i = 1
    }
    setmetatable(self, Tape)
    return self
end

function Tape.has_data(self)
    return self.i <= #(self.data)
end

function Tape.rotate(self, offset)
    self.i = self.i + offset
end

function Tape.get_next_char(self)
    local ret = self.data:sub(self.i, self.i)
    self.i = self.i + 1
    return ret
end

function Tape.next_token(self)
    local t = self.data[self.i]
    self.i = self.i + 1
    return t
end

function Tape.peek_token(self)
    return self.data[self.i]
end

function Tape.prev_token(self)
    self.i = self.i - 1
    return self.data[self.i]
end

function Tape.rewind(self)
    self.i = 1
end

return {
    Tape = Tape
}