package main
import "core:mem"

Animation::struct{
    is_active:b8,
    dest:v2_f32 ,
    source:v2_f32 ,
    ddp:v2_f32,
    forced:b8,
    completed:i32,
}

EntityType::enum{
  entity_type_null,
  entity_type_player,
  entity_type_npc,
  entity_type_wall,
  entity_type_temple,
  entity_type_grass,
  entity_type_fire_torch,
  entity_type_tile, //NOTE: based
  entity_type_number,
  entity_type_letter,
}


EntityFlags::enum {
  entity_flag_simming = (1 << 1),
  entity_undo = (1<<2),
  entity_flag_dead = (1<<8),
}

//TODO: put this in math.odin
v2_f32::[2]f32
v2_i32::[2]i32
v4::struct{r,g,b,a:f32}
rec2:: distinct matrix[2,2]f32

value::union { i64, f64, }

SimEntity::struct{
  type:EntityType,
  pos:v2_f32, //This is in meters
  //dP:v2_f32, 

  color:v4,
  
  width:f32,
  height:f32,

  collides:b8,

  storage_index:u32,
  flags:u32,
  face_direction:i8,

  val:value,

  texture:^LoadedBitmap,
  animation:^Animation, //Curently used for player
};

SimRegion::struct{
  entity_count:u32,
  bounds:rec2,
  center:WorldPosition,
  world:^World,
  entities:[1024]SimEntity,
  sim_arena:^MemoryArena,
};

//Header finish

//These parameters are so that we can add it to the new simentity
add_entity_to_sim::proc(game_state:^GameState, region:^SimRegion, low_index:u32, low:^LowEntity, entity_rel_pos:v2_f32)->^SimEntity{

  assert(low_index != 0)

  entity:= &region.entities[region.entity_count]
  region.entity_count += 1

  assert(low != nil)//?

  entity^ = low.sim 
  add_flag(&low.sim.flags, u32(EntityFlags.entity_flag_simming))

  entity.storage_index = low_index
  entity.pos = entity_rel_pos

  return entity
}

begin_sim::proc(sim_arena:^MemoryArena, game_state:^GameState, center:WorldPosition, bounds:rec2 )->^SimRegion{

  world := game_state.world
  sim_region:= push_struct(sim_arena, SimRegion)
  sim_region.world     = world
  sim_region.sim_arena = sim_arena
  sim_region.center    = center
  sim_region.bounds    = bounds
  sim_region.entity_count = 0

  min_chunk_pos := map_into_world_pos(world, sim_region.center, bounds[0]).chunk_pos

  max_chunk_pos := map_into_world_pos(world, sim_region.center, bounds[1]).chunk_pos

  for x in min_chunk_pos.x..=max_chunk_pos.x{
    for y in min_chunk_pos.y..=max_chunk_pos.y{
      chunk := get_world_chunk(world, v2_i32{x, y})

      for chunk != nil{
        node:= chunk.node
        for node != nil && node.entity_index != 0{
          entity := &game_state.low_entities[node.entity_index]
          entity_sim_space := subtract(world, entity.pos, sim_region.center)

          if (entity_sim_space.x >= sim_region.bounds[0].x) &&
          (entity_sim_space.y >= sim_region.bounds[0].y) && (entity_sim_space.x < sim_region.bounds[1].x && entity_sim_space.y < sim_region.bounds[1].y) {

            add_entity_to_sim(game_state, sim_region, node.entity_index, entity, entity_sim_space)
          }
          node = node.next
        }
        chunk = chunk.next
      }
    }
  }
  return sim_region
}

end_sim::proc(region:^SimRegion, game_state:^GameState){

  for entity in &region.entities{

    low:= &game_state.low_entities[entity.storage_index]

    entity.flags = low.sim.flags
    low.sim = entity

    new_world_p := map_into_world_pos(region.world, region.center, entity.pos)

    old_pos := low.pos

    if !(old_pos.offset == new_world_p.offset) || !(old_pos.chunk_pos == new_world_p.chunk_pos){

      change_entity_location(&platform.arena, region.world, entity.storage_index, low, new_world_p)
    }
  }
}

is_in_rectangle::proc(rect:rec2, test:v2_f32)->bool{

  result := ((test.x < rect[1].x && test.y < rect[1].y) &&
                (test.x >= rect[0].x && test.y >= rect[0].y));
  return result;
}
















