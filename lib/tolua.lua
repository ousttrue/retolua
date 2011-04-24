local function require_with_env(name, env)
    local chunk, msg
    local replace=name:gsub("%.", "/")
    for m in package.path:gmatch("[^;]+") do
        local path=m:gsub("%?", replace)
        chunk, msg=loadfile(path)
        if chunk then
            break
        else
            print(msg)
        end
    end
    if not chunk then
        assert(false, "not found: "..name.." in "..package.path)
        return
    end
    package.loaded[name]=env
    chunk(name)
end

module(..., package.seeall)
TOLUA_VERSION="tolua++-1.0.93(lua)"

require_with_env("tolua.classsystem", _M)
require_with_env("tolua.utility", _M)

require_with_env("tolua.match", _M)
require_with_env("tolua.tree", _M)
require_with_env("tolua.feature", _M)
require_with_env("tolua.verbatim", _M)
require_with_env("tolua.code", _M)
require_with_env("tolua.module", _M)
require_with_env("tolua.namespace", _M)
require_with_env("tolua.class", _M)
require_with_env("tolua.define", _M)
require_with_env("tolua.enumerate", _M)
require_with_env("tolua.variable", _M)
require_with_env("tolua.function", _M)

require_with_env("tolua.preprocess", _M)
require_with_env("tolua.variable_matcher", _M)
require_with_env("tolua.function_matcher", _M)
require_with_env("tolua.module_matcher", _M)
require_with_env("tolua.parser", _M)

