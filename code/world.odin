package main

import "core:fmt"
import "core:c"
import libc "core:c/libc"
import "core:math"

TILE_CHUNK_UNINITILIZED::c.INT32_MAX

TILE_COUNT_PER_WIDTH::16
TILE_COUNT_PER_HEIGHT::10

v2_f32::[2]f32
v2_i32::[2]i32
WorldPosition::struct{
    chunk_pos :v2_i32,
    offset    :v2_f32,
}

EntityNode::struct{
    entity_index :u32,
    next         :^EntityNode,
}

WorldChunk::struct{
    chunk_pos     :v2_i32,
    player_offset :v2_f32,
    entity_count  :u32,
    player_index  :u32,
    tiles         :[TILE_COUNT_PER_WIDTH][TILE_COUNT_PER_HEIGHT]Tile
    node          :^EntityNode,
    next          :^WorldChunk,
    tile_path     :^TileNode
    completed     :b8
}

World::struct{
    chunk_size_in_meters : v2_f32,
    chunk_hash           :[128]WorldChunk,
    meters_to_pixels     :u32,
}

TileFlags::enum{
  tile_occoupied = (1<<1),
  tile_path   = (1<<2),
  tile_empty  = (1<<3),
  tile_entity = (1<<4),
  tile_end    = (1<<5),
}

Tile::struct{
    tile_pos      :v2_i32,
    color         :v4,
    initilized    :b8,
    gl_Context    :OpenglContext,
    entity_count  :u32,
    entities      :EntityNode,
    flags         :u32,
}

TileNode::struct{
    tile:^Tile,
    next:^TileNode,
}

add_flag::#force_inline proc(val:^u32, flag:u32){
    val:=val
    val^ |= flag
}

is_flag_set::#force_inline proc(val:u32, flag:u32)->b32{
    return b32(val & flag)
}

clear_flag::#force_inline proc(val:^u32, flag:u32){
    val:=val
    val^ &= ~flag
}

//HEADER END

initilize_chunk_tiles::proc(world:^World, chunk:^WorldChunk){
 for row, x in &chunk.tiles{
   for tile, y in &row{
    tile.color = v4{1,1,1,1}
    tile.tile_pos  =  v2_i32{i32(x),i32(y)} 
   }
 }
}

//TODO: Check if the next, node and entity_count is zero by default
add_new_chunk::proc(arena:^MemoryArena, world:^World, head:^WorldChunk, chunk_pos:v2_i32 )->(new_chunk:^WorldChunk){
    new_chunk = push_struct(arena, WorldChunk)
    new_chunk.chunk_pos = chunk_pos
    new_chunk.next = nil
    new_chunk.node = push_struct(&platform.arena,EntityNode)
    new_chunk.entity_count = 0;

    curr:=head
    for curr.next != nil{
        curr = curr.next
    }
    curr.next = new_chunk
    initilize_chunk_tiles(world, new_chunk)
    return
}

/* 
  Basically a hashmap indexing,
  Additionally if there's no chunk then it adds one
*/
get_world_chunk::proc(world:^World, chunk_pos:v2_i32 ,arena:^MemoryArena = nil)->^WorldChunk{

    hash := 19 * abs(chunk_pos.x) + 7 + abs(chunk_pos.y);
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
            initilize_chunk_tiles(world, chunk)
            break
        }
        chunk = chunk.next
    }
    if (chunk == nil) && (arena!= nil){
        chunk = add_new_chunk(arena, world, head, chunk_pos)

    }
    return chunk
}

change_entity_location::proc(arena:^MemoryArena, world:^World, entity_index:u32, entity:^LowEntity, new_p:WorldPosition){

  //removing the old entity from the chunk

  old_p := entity.pos

  if new_p.chunk_pos.x != TILE_CHUNK_UNINITILIZED{
    if old_p.chunk_pos.x != TILE_CHUNK_UNINITILIZED{
      chunk := get_world_chunk(world, old_p.chunk_pos, arena)
      assert(chunk != nil)
          assert(chunk.node != nil)

      node := chunk.node
      if node.entity_index == entity_index{
        chunk.node = node.next
      }else{

        curr := node;
        for curr.next != nil && curr.entity_index != 0{
          if curr.next.entity_index == entity_index{
            node = curr.next
            curr.next = curr.next.next
            break
          }else{
            curr = curr.next
          }
        }
      }
    }

    //add to new pos's chunk, adds to the head
    chunk := get_world_chunk(world, new_p.chunk_pos, arena)
    node  := push_struct(arena, EntityNode)
    node.entity_index = entity_index
    node.next = chunk.node
    chunk.node = node
    entity.pos = new_p
  }
}

initilize_world::proc(world:^World, buffer_width:i32, buffer_height:i32){

 world.meters_to_pixels = u32(math.min(buffer_height/TILE_COUNT_PER_HEIGHT, buffer_width/TILE_COUNT_PER_WIDTH))

 world.chunk_size_in_meters = v2_f32{f32(TILE_COUNT_PER_WIDTH), f32(TILE_COUNT_PER_HEIGHT)}

 for chunk in &world.chunk_hash{
  chunk.chunk_pos.x = TILE_CHUNK_UNINITILIZED
 }
}

adjust_world_position::proc(world:^World, chunk_pos:^i32, offset:^f32, csim:f32){
  extra_offset := i32(libc.roundf(offset^/ f32(csim)))
  chunk_pos^   += extra_offset 
  offset^      -= f32(f32(extra_offset) * csim)
}


map_into_world_pos::proc(world:^World, origin:WorldPosition, offset:v2_f32)->WorldPosition{

  csim := world.chunk_size_in_meters
  result := origin
  result.offset += offset

  adjust_world_position(world, &result.chunk_pos.y, &result.offset.y, csim.y)
  adjust_world_position(world, &result.chunk_pos.x, &result.offset.x, csim.x)
  return result
}

update_camera::proc(game_state:^GameState, camera_ddp:v2_f32){
 animation := &game_state.chunk_animation; 

 camera_ddp := camera_ddp

 if !animation.is_active{
  if camera_ddp != {0,0}{
    csim := game_state.world.chunk_size_in_meters

    animation.is_active = true
    animation.source = game_state.camera_p.offset
    animation.dest  += camera_ddp * csim
    animation.ddp    = camera_ddp * csim 
    animation.completed = 0
  }
 }else{
  if animation.completed > 100{
    animation^ = Animation{}

    game_state.camera_p.offset = {}
    game_state.curr_chunk = game_state.camera_p.chunk_pos
  }else{
    chunk_diff:= animation.ddp 
    diff_to_add  := chunk_diff / v2_f32{20.0, 20.0}
    game_state.camera_p = map_into_world_pos(game_state.world, game_state.camera_p, diff_to_add)
    animation.completed += 5
  }
 }
}

subtract::proc(world:^World, a:WorldPosition, b:WorldPosition)->v2_f32{
 result:v2_f32 

 result.y = f32(a.chunk_pos.y) - f32(b.chunk_pos.y)
 result.x = f32(a.chunk_pos.x) - f32(b.chunk_pos.x)

 result = result * world.chunk_size_in_meters
 result = result + (a.offset - b.offset)
 return result
}


get_chunk_and_tile::proc(world:^World , pos:WorldPosition )->(chunk:^WorldChunk,tile:^Tile){

  chunk = get_world_chunk(world, pos.chunk_pos);
  x := cast(i32)libc.roundf(pos.offset.x);
  y := cast(i32)libc.roundf(pos.offset.y);
  tile = &chunk.tiles[x+ 8][y + 4];
  return; 
}












