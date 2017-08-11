# Kong Header ACL Plugin

A small Kong plugin to provide further ACL ability by HTTP Header. Wait,
this isn't as crazy and worthless as it sounds.

Kong sets HTTP headers throughout it's plugins so it's often useful
to test access on, say, the `x-authenticated-userid`. This also goes
well with the [Kong Userinfo Plugin](https://github.com/ohioit/kong-userinfo-plugin)
as that plugin can add LDAP attributes to headers that this plugin can
then ACL against. Using the combination of these two plugins, it's possible
to authenticate API access by LDAP groups and other attributes.

## Security Notes

This plugin is configured to run _after_ the
[Request Transformer](https://getkong.org/plugins/request-transformer/) plugin so
that critical headers can be _removed_ from the request before ACL checking is
done. If this is _not_ done, clients can simply send arbitrary ACL headers and
break everything. The [Kong Userinfo Plugin](https://github.com/ohioit/kong-userinfo-plugin)
automatically removes all `x-userinfo*` headers but if you use the Request Transformer
to rename headers, the renamed headers will _also_ have to be removed. For example,
if you've configured Request Transformer to rename `x-authenticated-userid` to `x-remote-user`
and `x-userinfo-memberof` to `x-remote-groups`, you'll also  have to configure it to
*remove* those headers from the request. Don't worry, it'll rename after it removes.

## Usage

The plugin has 4 sets of rules that can be configured for a given API. Each rule is
a comma separated list of header names and values. The comparison operator can either
be an `=` for an exact match, or a `~` for a substring match.

### Must Have Any Rules

These check that _at least one_ of the specified rules will match. For example,
`must_have_any=x-remote-group=admins,x-remote-location=ohio` would mean that
anyone who is either an Admin _or_ in the state of Ohio would have access.

### Must Have All Rules

These check that _all_ of the specified rules match. For example,
`must_have_all=x-remote-group=admins,x-remote-location=ohio` would mean that
only Admins in the state of Ohio would have access.

### Must Not Have Any Rules

These check that _none_ of the specified rules match. For example,
`must_not_have_any=x-remote-group=admins,x-remote-location=ohio` would mean that
both Admins and anyone in the state of Ohio would not have access.

### Must Not Have All Rules

These check that _all_ of the specified rules do not match. For example,
`must_not_have_all=x-remote-group=admins,x-remote-location=ohio` would mean that
only Admins in the state of Ohio would not have access.

### Order of Rule Matching

Rules are matched in the above order but _all_ of them must pass to have access
independently. For example, given an API that has both of the following rules:

```
must_have_any=x-remote-location=ohio,x-remote-location=virginia
must_have_all=x-remote-group=admins,x-forwarded-proto=https
must_not_have_any=x-remote-user=susan,x-remote-user=petheô
must_not_have_all=x-remote-affiliation=student,x-remote-status=probation
```

In order to have access you can either be from Ohio or Virginia but you
must also be an admin and connecting over HTTPS (proxied, of course).
Additionally, Susan and Petheô are explicitly disallowed (either one of them)
and all students on probation are forbidden too.

## Installation

For now, you'll have to clone this repository and use `luarocks make`
to install it into Kong. See the
[custom plugin documentation](https://getkong.org/docs/0.10.x/plugin-development/distribution/)
for details.