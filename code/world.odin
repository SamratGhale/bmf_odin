package main

import "core:c"

TILE_CHUNK_UNINITILIZED::c.INT32_MAX


WorldPosition::struct{
    chunk_pos:v2_i32,
    offset:v2_f32,
}

EntityNode::struct{
    entity_index:u32,
    next:^EntityNode,
}

WorldChunk::struct{
    chunk_pos:v2_i32,
    player_offset:v2_f32,
    entity_count:u32,
    player_index:u32,
    node:^EntityNode,
    next:^WorldChunk,
}

World::struct{
    chunk_size_in_meters: v2_f32,
    chunk_hash:[128]WorldChunk,
    meters_to_pixels:u32,
}

Tile::struct{
    tile_pos:v2_i32,
    color:v4,
    initilized:b8,
    gl_Context:OpenglContext,
    entity_count:u32,
    entities:EntityNode,
    flags:u32,
}

TileNode::struct{
    tile:^Tile,
    next:^TileNode,
}

add_flag::#force_inline proc(val:^u32, flag:u32){
    val:=val
    val^ |= flag
}

is_flag_set::#force_inline proc(val:^u32, flag:u32)->b32{
    return b32(val^ & flag)
}

clear_flag::#force_inline proc(val:^u32, flag:u32){
    val:=val
    val^ &= ~flag
}

//HEADER END

add_new_chunk::proc(arena:^MemoryArena, world:^World, head:^WorldChunk, chunk_pos:v2_i32)->(new_chunk:^WorldChunk){
    new_chunk = push_struct(arena, WorldChunk)
    new_chunk.chunk_pos = chunk_pos
    new_chunk.next = nil
    new_chunk.node = nil
    new_chunk.entity_count = 0;

    curr:=head
    for curr.next != nil{
        curr = curr.next
    }
    curr.next = new_chunk
    return
}

get_world_chunk::proc(world:^World, chunk_pos:v2_i32 ,arena:^MemoryArena = nil){
    hash := 19 * chunk_pos.x + 7 + chunk_pos.y;
    hash_slot := hash % (len(world.chunk_hash) -1)

    head:= &world.chunk_hash[hash_slot]
    chunk:= head

    for chunk != nil{
        if chunk_pos == chunk.chunk_pos{
            break
        }
        if chunk.chunk_pos.x == TILE_CHUNK_UNINITILIZED{
            chunk.chunk_pos = chunk_pos;
            chunk.entity_count = 0
            //initilize tile_chunk
            break
        }
        chunk = chunk.next
    }
    if (chunk == nil) && (arena!= nil){
        chunk = add_new_chunk(arena, world, head, chunk_pos)

    }
}

change_entity_location_raw::proc(arena:^MemoryArena, world:^World, entity_index:u32, new_p:WorldPosition, old_p:WorldPosition){

}