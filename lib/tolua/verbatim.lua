module(..., package.seeall)

Verbatim = define_class('Verbatim')
Verbatim:extend(classFeature)

Verbatim.matcher=Matcher("^%s*%$%s*([^\n]+)",
function(context, code)
    context:create(Verbatim, code)
end, 'Verbatim')

function Verbatim:__init(parent, line, cond)
    self.parent=parent
    self.line=line
    self.cond=cond or ''
    if self.line:sub(1, 1) == "'" then
        self.line = self.line:sub(2)
    elseif self.line:sub(1, 1) == '$' then
        -- generates in both suport and register fragments
        self.cond = 'sr'
        self.line = self.line:sub(2)
    end
end

function Verbatim:print_enter(context)
    print(context:texttemplate([=[
<%indent%>Verbatim{
<%indent%> line = '<% self.line %>',
<%indent%>}
]=], {self=self}))
end

