module(..., package.seeall)

------------------------------------------------------------------------------
-- Match
------------------------------------------------------------------------------
Match=define_class('Match')
function Match:__init(s, e, ...)
    if s then
        assert(type(s)=='number', 'invalid s: '..type(s))
        self.s=s
    end
    if e then
        assert(type(e)=='number', 'invalid e')
        self.e=e
    end
    self.result=table.mapi({...}, function(i, v)
        -- remove white space
        return v:strip()
    end)
    self.name=''
end

function Match:__tostring()
    return string.format("<Match:%s:%d,%d>", self.name, self.s or -1, self.e or -1)
end

matchers={}

------------------------------------------------------------------------------
-- Matcher
------------------------------------------------------------------------------
Matcher=define_class('Matcher')
function Matcher:__init(match, process, name)
    self._match=match
    self._process=process
    self.name=name or ''
end

function Matcher:__tostring()
    return string.format("<Matcher:%s>", self.name)
end

function Matcher:match(s, pos)
    if type(self._match)=='string' then
        -- pattern matching
        local m=Match(s:find(self._match, pos))
        m.name=self.name
        return m
    elseif type(self._match)=='function' then
        -- matching function
        local m=Match(self._match(s, pos))
        m.name=self.name
        return m
    else
        assert(false, 'invalid pattern ctype: '..type(self._match))
    end
end

function Matcher:process(...)
    if self._process then
        self._process(...)
    end
end

-- alias
Skip=Matcher

------------------------------------------------------------------------------
-- MultiMatcher
------------------------------------------------------------------------------
MultiMatcher=define_class('MultiMatcher')
function MultiMatcher:__init(...)
    self.name=''
    self.patterns={...}
end

function MultiMatcher:__tostring()
    return string.format("<MultiMatcher:%s>", self.name)
end

function MultiMatcher:match(s, pos)
    self._process=nil
    local m, p=self:_match(s, pos)
    if m then
        m.name=self.name
        self._process=p
        return m
    end
end

function MultiMatcher:_match(s, pos)
    for i, v in ipairs(self.patterns) do
        if type(v[1])=='string' then
            -- pattern matching
            local m=Match(s:find(v[1], pos))
            if m.s then
                return m, v[2]
            end
        elseif type(v[1])=='function' then
            -- matching function
            local m=Match(v[1](s, pos))
            if m.s then
                return m, v[2]
            end
        else
            assert(false, 'invalid pattern ctype: '..type(v[1]))
        end
    end
end

function MultiMatcher:process(...)
    if self._process then
        self._process(...)
    end
end

