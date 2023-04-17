package main

Animation::struct{
    is_active:b8,
    dest:v2_f32 ,
    source:v2_f32 ,
    ddp:v2_i32,
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
v2_f32::struct{x, y:f32}
v2_i32::struct{x, y:i32}
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
  max_count:u32,
  entity_count:u32,
  bounds:rec2,
  center:WorldPosition,
  world:^World,
  entities:^SimEntity,
  sim_arena:^MemoryArena,
};
