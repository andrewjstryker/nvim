m4_dnl ============================================================================
m4_dnl common.m4 — shared macros for rendering *.lua.m4 templates
m4_dnl
m4_dnl Usage: m4 -P -I build/m4 <template>.lua.m4 > <output>.lua
m4_dnl
m4_dnl This file switches to -<-< / >->- quotes so that Lua's single/double
m4_dnl quotes pass through without being interpreted as m4 quoting.
m4_dnl
m4_dnl IMPORTANT: Include this file AFTER constants.m4/paths.m4 (which use
m4_dnl default quoting), or include those files before this changequote takes
m4_dnl effect.  In practice, .lua.m4 templates include constants.m4 and
m4_dnl paths.m4 first, then common.m4 if needed.
m4_dnl ============================================================================

m4_changequote(-<-<, >->-)m4_dnl

m4_dnl --- Basic guards -----------------------------------------------------------
m4_dnl NV_IFDEF(NAME, IFSET, IFUNSET)   -> expand IFSET if NAME is defined, else IFUNSET
m4_define(-<-<NV_IFDEF>->-, -<-<m4_ifdef(-<-<$1>->-, -<-<$2>->-, -<-<$3>->-)>->-)m4_dnl

m4_dnl NV_DEF(NAME, DEFAULT)            -> expand to NAME if defined, else DEFAULT
m4_define(-<-<NV_DEF>->-, -<-<m4_ifdef(-<-<$1>->-, -<-<$1>->-, -<-<$2>->-)>->-)m4_dnl

m4_dnl NV_IFSET(NAME, IFSET)            -> expand IFSET only when NAME is defined
m4_define(-<-<NV_IFSET>->-, -<-<m4_ifdef(-<-<$1>->-, -<-<$2>->-, )>->-)m4_dnl

m4_dnl --- Lua helpers ------------------------------------------------------------
m4_dnl NV_LUA_STRING(S)  -> escape backslashes and double-quotes for Lua string
m4_define(-<-<NV_LUA_STRING>->-, -<-<m4_patsubst(m4_patsubst(-<-<$1>->-, -<-<\>->-, -<-<\\>->-), -<-<">->-, -<-<\">->-)>->-)m4_dnl

m4_dnl NV_LUA_ASSIGN(VAR, VALUE)  -> VAR = "VALUE" (with Lua-safe escaping)
m4_define(-<-<NV_LUA_ASSIGN>->-, -<-<-<-<$1>->- = "-<-<NV_LUA_STRING(-<-<$2>->-)>->-">->-)m4_dnl

m4_dnl NV_LUA_ASSIGN_IFDEF(MACRO, VAR)  -> if MACRO defined: VAR = "MACRO"
m4_define(-<-<NV_LUA_ASSIGN_IFDEF>->-, -<-<NV_IFDEF(-<-<$1>->-, -<-<-<-< $2 >->- = "-<-<NV_LUA_STRING(-<-<$1>->-)>->-">->-, )>->-)m4_dnl
