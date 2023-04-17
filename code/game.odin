package main

import "core:fmt"
import gl "vendor:OpenGL"

LowEntity::struct{
  pos          :WorldPosition,
  sim          :SimEntity,
}

PriorityNode::struct{
 entity   :^LowEntity,
 next     :^PriorityNode, 
}

push_priority_node::proc(head:^^PriorityNode, entity:^LowEntity, arena:^TempMemory){
  curr := head^

  //if the head dosen't exist then we put it in the head
  if curr.entity == nil{
    curr.entity = entity
    curr.next = nil
    return
  }

  temp:= push_struct(arena.arena, PriorityNode)
  temp.entity = entity
  temp.next   = nil

  //If new entity is greator than head we put in place of head
  if curr.entity.sim.type < entity.sim.type{
    temp.next = head^
    head^ = temp
  }else{
    //else we find the place to insert

    for curr.next != nil && curr.entity.sim.type > entity.sim.type{
      curr = curr.next
    }
    temp.next = curr.next
    curr.next = temp
  }
}

GameState::struct{
  world           :^World,
  camera_p        :WorldPosition,
  camera_bounds   :rec2,
  low_entity_count:u32,
  low_entities    :[10000]LowEntity,
  is_initilized   :b8,
  show_tiles      :b8,
  chunk_animation :Animation,
  curr_chunk      :v2_i32,
}

add_low_entity::proc(game_state:^GameState, type:EntityType, pos:WorldPosition, color:v4={0,0,0,0})->(low_entity:^LowEntity, entity_index:u32){

  entity_index = game_state.low_entity_count
  game_state.low_entity_count+=1
  low_entity   = &game_state.low_entities[entity_index]

  using low_entity
  pos = {}
  pos.chunk_pos.x = TILE_CHUNK_UNINITILIZED
  return
}

add_player::proc(game_state:^GameState, offset:v2_f32)->(low :^LowEntity, entity_index:u32){

  pos:= WorldPosition{chunk_pos = game_state.curr_chunk, offset=offset}

  chunk:= get_world_chunk(game_state.world, pos.chunk_pos)

  low, entity_index = add_low_entity(game_state, EntityType.entity_type_player, pos)

  low.sim.width = 1.0
  low.sim.height = 1.0
  low.sim.face_direction = -1
  low.sim.texture = nil
  low.sim.collides = true


  tile := &chunk.tiles[pos.chunk_pos.x][pos.chunk_pos.y]
  append_tile(chunk, tile, &platform.arena)
  return 
}

was_down::proc(type:ButtonEnum, controller:ControllerInput)->b8{
  button:= controller.buttons[type]
  return button.ended_down && (button.half_trans_count >0)
}

ended_down::proc(type:ButtonEnum, controller:ControllerInput)->b8{
  return controller.buttons[type].ended_down
}

/*
  maybe just use the sim_region's entities?
  Will be simpler but might be obstacle for future features
*/
sort_entitites_for_render::proc(game_state:^GameState, cam_bounds:rec2, camera_pos:WorldPosition,render_memory:^TempMemory)->^PriorityNode{

  render_memory:=render_memory
  world := game_state.world

  head := push_struct(render_memory.arena, PriorityNode)
  head.entity = nil

  min_chunk_pos := map_into_world_pos(world, camera_pos, cam_bounds[0]).chunk_pos
  max_chunk_pos := map_into_world_pos(world, camera_pos, cam_bounds[1]).chunk_pos

  for x in min_chunk_pos.x..=max_chunk_pos.x{
    for y in min_chunk_pos.y..=max_chunk_pos.y{
      chunk := get_world_chunk(world, v2_i32{x, y})

      for chunk != nil{
        node:= chunk.node
        for node != nil && node.entity_index != 0{
          low_entity := &game_state.low_entities[node.entity_index]
          entity_cam_space := subtract(world, low_entity.pos, camera_pos)

          entity := low_entity.sim
          if is_in_rectangle(cam_bounds, entity_cam_space) {

            if is_flag_set(entity.flags, u32(EntityFlags.entity_flag_dead)){
              push_priority_node(&head, low_entity, render_memory)
            }
          }
          node = node.next
        }
        chunk = chunk.next
      }
    }
  }
  return head
}

render_entities::proc(game_state:^GameState, head:^PriorityNode){
  world := game_state.world 
  chunk := get_world_chunk(world, game_state.curr_chunk)

  node := head
  mtop := v2_f32{f32(world.meters_to_pixels), f32(world.meters_to_pixels)}

  for node.entity != nil{

    entity:= node.entity.sim

    if entity.type != EntityType.entity_type_null{
      size_in_meters := v2_f32 {entity.height, entity.width}
      size_in_pixels := size_in_meters * mtop 

      center := world.chunk_size_in_meters * mtop * 0.5 
      min    := center + entity.pos * mtop * 0.5

      using EntityType
      using BmpAsset_Enum
      #partial switch entity.type{
        case .entity_type_player:{
          player_left := get_bmp_asset(&platform.bmp_asset, asset_player_left)
          opengl_bitmap(player_left, min.x, min.y, size_in_pixels.x, size_in_pixels.y)
        }
      }
    }
    node = node.next
  }
}

render_game::proc(buffer:^OffscreenBuffer, input:^GameInput){
  game_state:=cast(^GameState)(platform.permanent_storage)

    //initilize the world
    if !game_state.is_initilized {

      game_state.world = push_struct(&platform.arena, World)
      initilize_world(game_state.world, buffer.width, buffer.height)

      world:=game_state.world
      dim_in_meters:= world.chunk_size_in_meters /2

      a:= 2.0 / f32(buffer.width);
      b:= 2.0 / f32(buffer.height);

      proj:[]f32 = {
        a, 0, 0, 0,
        0, b, 0, 0,
        0, 0, 1, 0,
        -1, -1, 0, 1,
      };

      gl.UniformMatrix4fv(opengl_config.transform_id, 1, gl.FALSE, &proj[0]);
      game_state.is_initilized = true
    }

    world:=game_state.world
    chunk:=get_world_chunk(world, game_state.curr_chunk)

    player_ddp :v2_i32
    camera_ddp :v2_f32

    undo:b8 = false

    for controller in input.controllers{
      using ButtonEnum;

        //was_down(Key_l, controller) ? toggle_light()

        //was_down(action_left)

        if chunk.player_index == 0{

          if ended_down(start, controller) {
            _,index := add_player(game_state, v2_f32{6.0, 0.0})
            chunk.player_index = index
          }

        }else{

          low := game_state.low_entities[chunk.player_index]
          entity:= &low.sim

          if controller.is_analog{

          }
          else{
            if ended_down(move_down, controller) {
              player_ddp.y =-1
            }
            if ended_down(move_up, controller) {
              player_ddp.y =1
            }
            if ended_down(move_right, controller) {
              player_ddp.x =1
            }
            if ended_down(move_left, controller) {
              player_ddp.x =-1
            }
            if ended_down(Key_u, controller) {
              undo = true
            }
          }
        }
    }
    update_camera(game_state, camera_ddp)

    trans_state:=cast(^TransientState)rawptr(platform.temp_storage)

    sim_memory := begin_temp_memory(&trans_state.trans_arena)

    sim_regon := begin_sim(sim_memory.arena, game_state, game_state.camera_p, game_state.camera_bounds)

    //We compute and update the entities here

    for entity, i in &sim_regon.entities{
      if u32(i)>=sim_regon.entity_count {break}

      #partial switch entity.type{
        case .entity_type_player:{
          low := &game_state.low_entities[entity.storage_index]
          if low.pos.chunk_pos == game_state.curr_chunk{
            chunk := get_world_chunk(world, game_state.curr_chunk)
            if !chunk.completed{
              //when undo undo_player(game_state, low, &player_ddp)
              //update_player(game_state, player_ddp, entity, low, undo)
            }
          }
        }
      }
    }

    end_sim(sim_regon, game_state)
    end_temp_memory(sim_memory)


    render_memory := begin_temp_memory(&trans_state.trans_arena)

    head:= sort_entitites_for_render(game_state, game_state.camera_bounds, game_state.camera_p, &render_memory)

    end_temp_memory(render_memory)

    background_png := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_background)
    opengl_bitmap(background_png, 0, 0, f32(background_png.width), f32(background_png.height))

    //render_entities(game_state, head);


  }















