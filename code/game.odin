package main

LowEntity::struct{
    pos:^WorldPosition,
    sim:SimEntity,
}

GameState::struct{
    world:^World,
    camera_p:^WorldPosition,
    camera_bounds: rec2,
    low_entity_count:u32,
    low_entities:[10000]LowEntity,
    is_initilized:b8,
    show_tiles:b8,
    chunk_animation:Animation,
    curr_chunk:v2_i32,
}

add_low_entity::proc(game_state:^GameState, type:EntityType, pos:WorldPosition, color:v4={0,0,0,0})->(low_entity:^LowEntity, entity_index:u32){
    entity_index = game_state.low_entity_count
    game_state.low_entity_count+=1
    low_entity = &game_state.low_entities[entity_index]
    using low_entity

    pos = {}
    pos.chunk_pos.x = TILE_CHUNK_UNINITILIZED
    return
}

render_game::proc(buffer:^OffscreenBuffer, input:^GameInput){
    game_state:=cast(^GameState)(platform.permanent_storage)

    if !game_state.is_initilized{

        game_state.world = push_struct(&platform.arena, World)
        game_state.is_initilized = true
    }
}