class_name NodeCompatibility
extends RefCounted

var valid: bool = false
var reason: String = ""
var result: SkillCompileResult


static func accepted(compile_result: SkillCompileResult, message: String = "") -> NodeCompatibility:
    var state := NodeCompatibility.new()
    state.valid = true
    state.reason = message
    state.result = compile_result
    return state


static func rejected(message: String, compile_result: SkillCompileResult = null) -> NodeCompatibility:
    var state := NodeCompatibility.new()
    state.valid = false
    state.reason = message
    state.result = compile_result
    return state

