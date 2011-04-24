module(..., package.seeall)

Verbatim=tolua.define_class('Verbatim')
Verbatim:extend(Base)

function Verbatim:preamble_enter()
    if self.node.cond=='' then
        return self.node.line..'\n'
    else
        return ''
    end
end

function Verbatim:supcode_enter()
    if self.node.cond:find('s') then
        return self.node.line..'\n'
    else
        return ''
    end
end

function Verbatim:register_enter()
    if self.node.cond:find('r') then
        return self.node.line..'\n'
    else
        return ''
    end
end

