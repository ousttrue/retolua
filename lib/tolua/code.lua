module(..., package.seeall)

-- mark up comments and strings
local STR1 = "\001"
local STR2 = "\002"
local STR3 = "\003"
local STR4 = "\004"
local REM  = "\005"
local ANY  = "([\001-\005])"
local ESC1 = "\006"
local ESC2 = "\007"

local MASK = { -- the substitution order is important
 {ESC1, "\\'"},
 {ESC2, '\\"'},
 {STR1, "'"},
 {STR2, '"'},
 {STR3, "%[%["},
 {STR4, "%]%]"},
 {REM , "%-%-"},
}

local function mask (s)
 for i = 1,#MASK  do
     s = s:gsub(MASK[i][2],MASK[i][1])
 end
 return s
end

local function unmask (s)
    for i = 1,#MASK  do
        s = s:gsub(MASK[i][1],MASK[i][2])
    end
    return s
end

function clean (s)
    -- check for compilation error
    local code = "return function ()\n" .. s .. "\n end"
    assert(loadstring(code))()

    local S = "" -- saved string

    s = mask(s)

    -- remove blanks and comments
    while 1 do
        local b,e,d = string.find(s,ANY)
        if b then
            S = S..string.sub(s,1,b-1)
            s = string.sub(s,b+1)
            if d==STR1 or d==STR2 then
                e = string.find(s,d)
                S = S ..d..string.sub(s,1,e)
                s = string.sub(s,e+1)
            elseif d==STR3 then
                e = string.find(s,STR4)
                S = S..d..string.sub(s,1,e)
                s = string.sub(s,e+1)
            elseif d==REM then
                s = string.gsub(s,"[^\n]*(\n?)","%1",1)
            end
        else
            S = S..s
            break
        end
    end
    -- eliminate unecessary spaces
    S = string.gsub(S,"[ \t]+"," ")
    S = string.gsub(S,"[ \t]*\n[ \t]*","\n")
    S = string.gsub(S,"\n+","\n")
    S = unmask(S)
    return S
end

Code = define_class('Code')
Code:extend(classFeature)

Code.matcher=Matcher("^(%b\1\2)",
function(context, code)
    context:create(Code, code:sub(2, -2))
end, 'Code')

function Code:__init(parent, code)
    self.parent=parent
    self.text=code
end

------------------------------------------------------------------------------
-- Print method
------------------------------------------------------------------------------
function Code:print_enter(context)
    print(context:indent().."Code{")
    print(context:indent().." text = [["..self.text.."]],")
    print(context:indent().."}")
end

