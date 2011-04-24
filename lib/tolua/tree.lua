module(..., package.seeall)
------------------------------------------------------------------------------
-- Tree traverse context
------------------------------------------------------------------------------
TraversalContext=define_class('TraversalContext')
function TraversalContext:__init()
    self._indent=1
end
function TraversalContext:push(node)
    table.insert(self, node)
end
function TraversalContext:pop()
    table.remove(self)
end
function TraversalContext:indent()
    local l={}
    for i=1, #self+self._indent do
        table.insert(l, ' ')
    end
    return table.concat(l)
end
function TraversalContext:rfind(f)
    for i=#self, 1, -1 do
        local n=self[i]
        if f(n) then
            return n
        end
    end
end

------------------------------------------------------------------------------
-- Tree node
------------------------------------------------------------------------------
Node=define_class('Node')
function Node:get_func(func, name)
    if type(func)=='function' then
        return func
    end

    if type(func)=='table' then
        if name=='__enter' then
            return func[1]
        elseif name=='__leave' then
            return func[2]
        else
            error('invalid name: '..name)
        end
    end

    if type(func)=='string' then
        local key=func..name
        return self[key]
    end
end

function Node:walk(func, context, ...)
    local args={...}
    context=context or TraversalContext()
    -- enter
    local enter=self:get_func(func, '_enter')
    if enter then
        context.current=self
        enter(self, context, unpack(args))
    end
    -- children
    context:push(self)
    table.foreachi(self, function(i, v)
        if type(v)=='table' and v:is(Node) then
            v:walk(func, context, unpack(args))
        end
    end)
    context:pop()
    -- leave
    local leave=self:get_func(func, '_leave')
    if leave then
        context.current=self
        leave(self, context, unpack(args))
    end
end

function Node:findparent(f)
    local ret={f(self)}
    if ret[1] then
        return self, unpack(ret)
    end
    if self.parent then
        return self.parent:findparent(f)
    end
end

function Node:foldparent(f, ...)
    local ret={f(self, ...)}
    if self.parent then
        return self.parent:foldparent(f, unpack(ret))
    else
        return unpack(ret)
    end
end

