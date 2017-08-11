local utils = require "kong.tools.utils"
local responses = require "kong.tools.responses"
local printable_mt = require "kong.tools.printable"

local ngx_get_headers = ngx.req.get_headers
local ngx_re_match = ngx.re.match
local ngx_re_gmatch = ngx.re.gmatch
local ngx_re_gsub = ngx.re.gsub
local base64_decode = ngx.base64_decode
local table_contact = utils.contact

-- There are two types of rules, ANY rules and ALL rules.
-- ANY rules allow for any of the rules in the set to pass.
-- ALL rules require all of the rules in the set to pass.
local ALL = 1
local ANY = 2

-- Small, and kinda useless now, table that maps the 4
-- types of requirements to their results and the rule
-- types. This could probably be cleaned up now that the
-- algorithm  is different.
local RULE_RESULTS = {
    must_have_any = { result = true, which = ANY },
    must_have_all = { result = true, which = ALL },
    must_not_have_any = { result = false, which = ANY },
    must_not_have_all = { result = false, which = ALL }
}

-- Define our operations as lambda functions so we can easily match
-- on the operation token.
local RULE_OPERATIONS = {
    ['='] = function(x,y) return x == y end,
    ['~'] = function(x,y) return string.find(x,y) end
}

local _M = {}

local parse_expressions = function(expressions)
    local results = {}

    -- We want to be sure to execute all of the same type of
    -- rule in the same run so that "any" rules work as expected.
    -- Here, we're going to preserve their separation.
    for exptype, expression in pairs(expressions) do
        local requirement = RULE_RESULTS[exptype]
        local type_results = {}

        -- Split out the expression by commas to get individual rules.
        for i = 1, #expression do
            -- We need to make absolutely sure we trim all whitespace or we may
            -- get very weird rules.
            piece = ngx_re_gsub(expression[i], [[^\s*(.*)\s*?$]], "$1", "jo")
            if #piece > 0 then
                -- Split the rule into it's component parts: the header key,
                -- the operation, and the header value.
                local rule = ngx_re_match(piece, "(.*)([~=])(.*)", "jo")
                table.insert(type_results, {
                    name = rule[1],
                    operation = RULE_OPERATIONS[rule[2]],
                    value = rule[3],
                    result = requirement.result,
                    which = requirement.which
                })
            end
        end

        if #type_results > 0 then
            results[exptype] = type_results
        end
    end

    return results
end

-- Determine in a given value matches
-- a rule.
local does_match = function(value, rule)
    local matches = false

    if value then
        -- The HTTP spec says that commas are only valid in a value if
        -- it denotes a _set_ of values. This is how we plop arrays into
        -- headers so, if we find a comma in the value, split it out
        -- into an array and check each value individually.
        if string.find(value, ",") then
            for value in ngx_re_gmatch(value, "([^,]+),?", "jo") do
                matches = rule.operation(string.lower(value[1]), string.lower(rule.value))
                if matches then break end
            end
        else
            matches = rule.operation(string.lower(value), string.lower(rule.value))
        end
    end

    return matches
end

-- Check whether or not the given rules allow access.
local check_access = function(headers, rules, which)
    if not rules then
        return true
    end

    local passed = nil

    -- For all "ANY" rules, if none of them match,
    -- it's a failure so set passed to true.
    -- For all "ALL" rules, the moment one of them fail,
    -- we'll be kicked out of this function. All of them
    -- must fall through to succeed so set passed to true here.
    if which == ANY then
        passed = false
    else
        passed = true
    end

    for i = 1, #rules do
        local rule = rules[i]
        local value = headers[rule.name]
        local matches = does_match(value, rule)

        -- If an "ANY" rule has matched, this is sufficient.
        -- If an "ALL" rule has _not_ matched, it's sufficient to deny.
        if matches and rule.which == ANY then
            return true
        elseif not matches and rule.which == ALL then
            return false
        end
    end

    return passed
end

-- The logic in checking for no access is ever so slightly
-- different and after agonizing for a while about how to
-- simplify this to one routine, I said fuck it and just
-- made a second one. Not DRY unfortunately but I gotta get
-- this done.
local check_no_access = function(headers, rules, which)
    if not rules then
        return true
    end

    -- This is the opposite of before. An "ANY"
    -- rule that fails to match here means it failed
    -- to deny access, so we return "true" here.
    -- An "ALL" rule must fail on every value so we
    -- set passed to "false" so it can fall through.
    if which == ANY then
        passed = true
    else
        passed = false
    end

    for i = 1, #rules do
        local rule = rules[i]

        local value = headers[rule.name]
        local matches = does_match(value, rule)

        -- "ANY" rules are sufficient to deny
        -- "ALL" rules that do not match are sufficient to allow
        if matches and rule.which == ANY then
            return false
        elseif not matches and rule.which == ALL then
            return true
        end
    end

    return passed
end

function _M.execute(conf)
    local headers = ngx_get_headers()
    local rules = parse_expressions(conf.rules)
    local passed = nil

    -- This really should be some sort of loop.
    passed = check_access(headers, rules.must_have_any, ANY)
    passed = passed and check_access(headers, rules.must_have_all, ALL)
    passed = passed and check_no_access(headers, rules.must_not_have_any, ANY)
    passed = passed and check_no_access(headers, rules.must_not_have_all, ALL)

    if not passed then
        return responses.send_HTTP_FORBIDDEN("Access denied.")
    end

    return true
end

return _M
