local Errors = require "kong.dao.errors"

local ngx_re_find = ngx.re.find

local HEADER_NAME_REGEX="[a-zA-Z0-9-_]"
local HEADER_VALUE_REGEX="[A-Za-z0-9!#$%&'*\\+\\-\\.^_`|~]"
local OPERATOR_REGEX="[~=]"
local EXPRESSION_REGEX="^(" ..
    HEADER_NAME_REGEX .. "+" ..
    OPERATOR_REGEX .. HEADER_VALUE_REGEX .. "+)(," ..
    HEADER_NAME_REGEX .. "+" .. OPERATOR_REGEX ..
    HEADER_VALUE_REGEX .. "+)*$"

local check_expression = function(expressions)
    if expressions then
        for i = 1, #expressions do
            local expression = expressions[i]

            if expression ~= nil and #expression > 0 and not ngx_re_find(expression, EXPRESSION_REGEX) then
                return false, [[Expressions must be a valid HTTP header name and value. Header names 
                                must be alphanumeric with underscores *only*. Header values may also
                                contain the characters !#$%&'*+-.^`|~.']]
            end
        end
    end
end

return {
    no_consumer = true,
    fields = {
        rules = {
            type = "table",
            required = true,
            schema = {
                fields = {
                    must_have_all = {type = "array", func = check_expression},
                    must_have_any = {type = "array", func = check_expression},
                    must_not_have_all = {type = "array", func = check_expression},
                    must_not_have_any = {type = "array", func = check_expression}
                }
            }
        }
    },
    self_check = function(schema, plugin_t, dao, is_update)
        if (not plugin_t.rules.must_have_all or #plugin_t.rules.must_have_all == 0) and
            (not plugin_t.rules.must_have_any or #plugin_t.rules.must_have_any == 0) and
            (not plugin_t.rules.must_not_have_any or #plugin_t.rules.must_not_have_any == 0) and
            (not plugin_t.rules.must_not_have_all or #plugin_t.rules.must_not_have_all == 0) then
                return false, Errors.schema "There must be at least one requirement defined."
        end

        return true
    end
}
