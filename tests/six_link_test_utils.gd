class_name SixLinkTestUtils
extends RefCounted


static func compile(component_ids: Array[StringName], configs: Dictionary = {}) -> SkillCompileResult:
    var build := SixLinkBuild.new()
    for slot_index: int in mini(component_ids.size(), SixLinkBuild.MAX_SLOTS):
        var component_id := component_ids[slot_index]
        var component := SkillCatalog.get_component(component_id)
        var config := configs.get(slot_index) as TriggerConfig
        if component != null and component.is_trigger() and config == null:
            config = TriggerConfig.new()
        build.set_slot(SkillSlot.new().configure(slot_index, component_id, config))
    return SkillCompiler.compile_build(build)


static func reset_dummies(dummies: Array[Node]) -> void:
    for dummy: Node in dummies:
        if dummy.has_method("reset_dummy"):
            dummy.call("reset_dummy")


static func isolate_target(dummies: Array[Node], target_position: Vector3) -> TrainingDummy:
    var primary: TrainingDummy
    for index: int in dummies.size():
        var dummy := dummies[index] as TrainingDummy
        dummy.reset_dummy()
        dummy.global_position = Vector3(45.0 + float(index) * 2.5, 0.0, 45.0)
        if index == 0:
            primary = dummy
    if primary != null:
        primary.global_position = target_position
    return primary


static func place_player(player: PlayerController, position: Vector3 = Vector3.ZERO) -> void:
    player.global_position = position
    player.velocity = Vector3.ZERO
    player.set_view_camera(null)
    player.set("_facing_direction", Vector3(0.0, 0.0, -1.0))
    player.set("_cooldown_remaining", 0.0)


static func message_count(messages: Array[String], fragment: String) -> int:
    var count := 0
    for message: String in messages:
        if message.contains(fragment):
            count += 1
    return count
