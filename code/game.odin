package main

import "core:fmt"
import "core:mem"
import gl "vendor:OpenGL"
import libc "core:c/libc"

LowEntity::struct{
    pos          :WorldPosition,
    sim          :SimEntity,
}

RenderEntity::struct{
    min_p       : v2_f32, 
    max_p       : v2_f32, 
    type        : EntityType,
    texture     : ^LoadedBitmap,
    next        : ^RenderEntity,
}

GameState::struct{
    world                    :^World,
    camera_p                 :WorldPosition,
    camera_bounds            :rec2,
    low_entity_count         :u32,
    low_entities             :[10000]LowEntity,
    is_initilized            :b8,
    show_tiles               :b8,
    chunk_animation          :Animation,
    curr_chunk               :v2_i32,
    first_playing_sound      :^PlayingSound,
    first_free_playing_sound :^PlayingSound,
}
//End definations 

//Head shouldn't be null (it's first entity should be a entity_type_null entity)

push_render_entities::proc(head:^^RenderEntity, min_p, max_p: v2_f32, type: EntityType, texture :^LoadedBitmap, arena:^TempMemory){
    curr := head^;

    new_entity := push_struct(arena.arena, RenderEntity)
    new_entity.min_p  = min_p
    new_entity.max_p  = max_p
    new_entity.type   = type
    new_entity.texture = texture

    if curr.type < new_entity.type{
	new_entity.next = head^
	    head^           = new_entity 
    } else {
	for curr.next != nil && curr.type > new_entity.type{
	    curr = curr.next
	}
	new_entity.next = curr.next
	curr.next = new_entity
    }
}


add_low_entity::proc(game_state:^GameState, type:EntityType, pos:WorldPosition, color:v4={0,0,0,0})->(low_entity:^LowEntity, entity_index:u32){

    entity_index = game_state.low_entity_count
    game_state.low_entity_count+=1
    low_entity   = &game_state.low_entities[entity_index]
    low_entity.pos = {}

    low_entity.pos.chunk_pos.x = TILE_CHUNK_UNINITILIZED

    if(type != EntityType.entity_type_null){
	change_entity_location(&platform.arena, game_state.world, entity_index, low_entity, pos)
    }

    low_entity.sim.color = color
    low_entity.sim.storage_index = entity_index
    low_entity.sim.type = type

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
    low.sim.animation = push_struct(&platform.arena, Animation)

    _, tile := get_chunk_and_tile(game_state.world, pos)
    append_tile(chunk, tile, &platform.arena)
    return 
}

add_wall::proc(game_state:^GameState, chunk_pos:v2_i32 ,offset:v2_f32)->(low :^LowEntity, entity_index:u32) {

    texture := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_wall);
    pos := WorldPosition{chunk_pos, offset};

    low, entity_index = add_low_entity(game_state, EntityType.entity_type_wall, pos, v4{1,1,1,1});

    low.sim.width          = 1.0;
    low.sim.height         = 1.0;
    low.sim.face_direction = -1;
    low.sim.texture        = texture;
    low.sim.collides       = true;

    _, tile := get_chunk_and_tile(game_state.world, pos);
    add_flag(&tile.flags, u32(TileFlags.tile_occoupied));
    return ;
}

add_walls_around_chunk_pos::proc(game_state:^GameState , chunk_pos:v2_i32) {
    using BmpAsset_Enum

    for x in -7..=7 {
	add_wall(game_state, chunk_pos,v2_f32{f32(x), -4});
	add_wall(game_state, chunk_pos,v2_f32{f32(x), 4});
    }
    for y in -3..=3 {
	add_wall(game_state, chunk_pos,v2_f32{-7, f32(y)});
	add_wall(game_state, chunk_pos,v2_f32{7, f32(y)});
    }
}

add_enemy::proc(game_state:^GameState, chunk_pos:v2_i32 ,offset:v2_f32)->(low :^LowEntity, entity_index:u32){
    texture := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_enemy);
    pos := WorldPosition{chunk_pos, offset};

    low, entity_index = add_low_entity(game_state, EntityType.entity_type_enemy, pos, v4{1,1,1,1});

    low.sim.width          = 1.0;
    low.sim.height         = 1.0;
    low.sim.face_direction = -1;
    low.sim.texture        = texture;
    low.sim.collides       = false;
    low.sim.animation = push_struct(&platform.arena, Animation)

    //_, tile := get_chunk_and_tile(game_state.world, pos);
    //add_flag(&tile.flags, u32(TileFlags.tile_occoupied));
    return
}

add_tree::proc(game_state:^GameState, chunk_pos:v2_i32 ,offset:v2_f32)->(low :^LowEntity, entity_index:u32){
    texture := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_tree);
    pos := WorldPosition{chunk_pos, offset};

    low, entity_index = add_low_entity(game_state, EntityType.entity_type_tree, pos, v4{1,1,1,1});

    low.sim.width          = 2.0
    low.sim.height         = 2.0
    low.sim.face_direction = -1
    low.sim.texture        = texture
    low.sim.collides       = false
    low.sim.animation      = nil

    //_, tile := get_chunk_and_tile(game_state.world, pos);
    //add_flag(&tile.flags, u32(TileFlags.tile_occoupied));
    return
}

was_down::proc(type:ButtonEnum, controller:ControllerInput)->b32{
    button:= controller.buttons[type]
    return button.ended_down && (button.half_trans_count >0)
}

ended_down::proc(type:ButtonEnum, controller:ControllerInput)->b32{
    return controller.buttons[type].ended_down
}

sort_entities_for_render::proc(game_state:^GameState, cam_bounds:rec2, camera_pos:WorldPosition,render_memory:^TempMemory)->^RenderEntity{

    render_memory:=render_memory
    world := game_state.world

    render_head       := push_struct(render_memory.arena, RenderEntity)
    render_head.type   = EntityType.entity_type_null
    render_head.next   = nil

    min_chunk_pos := map_into_world_pos(world, camera_pos, cam_bounds[0]).chunk_pos
    max_chunk_pos := map_into_world_pos(world, camera_pos, cam_bounds[1]).chunk_pos

    chunk := get_world_chunk(world, game_state.curr_chunk)
    player_low := game_state.low_entities[chunk.player_index]

    mtop := v2_f32{f32(world.meters_to_pixels), f32(world.meters_to_pixels)}
    center := world.chunk_size_in_meters * mtop * 0.5 

    using BmpAsset_Enum

    if(player_low.sim.type != EntityType.entity_type_null){
	using gl
	//render path

	size_in_meters := v2_f32 {1, 1}
	size_in_pixels := size_in_meters * mtop 

	path_tile := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_floor)

	for x in  -7.0..< f32(TILE_COUNT_PER_WIDTH/2){
	    for  y in -3.0..< f32(TILE_COUNT_PER_HEIGHT/2) {
		tile := get_tile_from_chunk(chunk, v2_f32{x, y})
		if (is_flag_set(u32(tile.flags), u32(TileFlags.tile_path))) {
		    //min_p    := (center + v2_f32{x, y}* mtop) - (size_in_pixels * 0.5)
		    //push_render_entities(&render_head, min_p, size_in_pixels, EntityType.entity_type_floor, path_tile,  render_memory)
		}
	    }
	}

    }

    for x in min_chunk_pos.x..=max_chunk_pos.x{
	for y in min_chunk_pos.y..=max_chunk_pos.y{
	    chunk := get_world_chunk(world, v2_i32{x, y})

	    for chunk != nil{
		node:= chunk.node
		for node != nil && node.entity_index != 0{
		    low_entity := &game_state.low_entities[node.entity_index]
		    entity_cam_space := subtract(world, low_entity.pos, camera_pos)

		    entity := low_entity.sim

		    size_in_meters := v2_f32 {entity.height, entity.width}
		    size_in_pixels := size_in_meters * mtop 

		    if(entity.type != EntityType.entity_type_null){
			if is_in_rectangle(cam_bounds, entity_cam_space) {
			    if !is_flag_set(entity.flags, u32(EntityFlags.entity_flag_dead)){

				#partial switch entity.type{
				    case .entity_type_player :{


					player_bitmap:^LoadedBitmap

					if (entity.face_direction == 0) {
					    player_bitmap = get_bmp_asset(&platform.bmp_asset, asset_player_left)
					} else if (entity.face_direction == 1) {
					    player_bitmap = get_bmp_asset(&platform.bmp_asset, asset_player_back)
					} else {
					    player_bitmap = get_bmp_asset(&platform.bmp_asset, asset_player_right)
					}
					min_pos:= (center + entity.pos * mtop) - (size_in_pixels * 0.5)

					push_render_entities(&render_head, min_pos, size_in_pixels, entity.type,player_bitmap,  render_memory)

					
					gl.Uniform2f(opengl_config.light_pos_id, min_pos.x, min_pos.y);
				    }
				    case .entity_type_enemy,
					.entity_type_wall,
					.entity_type_tree:{
					    min_pos:= (center + entity.pos * mtop) - (size_in_pixels * 0.5)
					    push_render_entities(&render_head, min_pos, size_in_pixels, entity.type, entity.texture,  render_memory)
				    }
				}
			    }
			}
		    }
		    node = node.next
		}
		chunk = chunk.next
	    }
	}
    }
    return render_head
}

render_entities::proc(game_state:^GameState, head:^RenderEntity) {

    node := head
    for node!= nil{
	if node.type != EntityType.entity_type_null{
	    opengl_bitmap(node.texture, node.min_p, node.max_p)
	}
	node = node.next
    }
}


undo_player::proc(game_state:^GameState , low_entity:^LowEntity, ddp:^v2_f32) {

    sim       := &low_entity.sim;
    animation := low_entity.sim.animation;

    chunk := get_world_chunk(game_state.world, game_state.curr_chunk);
    len   := get_path_length(chunk.tile_path);

    if (len > 1) && !animation.is_active{
	curr_tile := get_last_tile(chunk.tile_path);
	remove_last_tile(chunk.tile_path);
	prev_tile := get_last_tile(chunk.tile_path);
	assert(prev_tile != nil);  // because we are checking this on the if block
	diff := prev_tile.tile_pos - curr_tile.tile_pos;

	ddp.x = f32(diff.x)
	ddp.y = f32(diff.y)
    }
}

update_enemy::proc(game_state:^GameState, entity:^SimEntity, low:^LowEntity){
    using TileFlags
    using EntityFlags
    animation:= entity.animation
    start_pos:= &entity.pos

    //TODO: make this according to the enemy position

    if !animation.is_active{
	ddp := animation.ddp

	if(ddp.x == 0 && ddp.y == 0){
	    ddp = v2_f32{1,0} //for starting
	}else if(start_pos.x >= 6){
	    ddp = v2_f32{-1,0} //for starting
	}else if(start_pos.x <= -6){
	    ddp = v2_f32{1,0} //for starting
	}



	animation.is_active = true
	animation.source = start_pos^
	animation.dest = start_pos^
	animation.completed = 0 
	animation.dest += {1,0}
	animation.ddp = ddp
	animation.forced = true;
    }
    else{
	if animation.completed >= 100{
	    animation.is_active = false

	    start_pos.x = libc.roundf(start_pos.x)
	    start_pos.y = libc.roundf(start_pos.y)

	    //chunk, tile := get_chunk_and_tile(world, low.pos)

	}else {
	    chunk_diff  := animation.ddp
	    diff_to_add := chunk_diff / 10.0
	    start_pos^  += diff_to_add
	    animation.completed += 10
	}
    }
}

//TODO:: Make it simpler? or make it generic
update_player::proc(game_state:^GameState, ddp:v2_f32, entity:^SimEntity, low:^LowEntity, force:b8){

    using TileFlags
    using EntityFlags
    animation:= entity.animation
    start_pos:= &entity.pos

    world := game_state.world

    if ddp.x != 0 || ddp.y != 0{
	dest_pos := low.pos
	dest_pos.offset += ddp

	_,tile := get_chunk_and_tile(world, dest_pos)

	if !(is_flag_set(tile.flags, u32(tile_occoupied))|| is_flag_set(tile.flags, u32(tile_path))) || force{

	    if !animation.is_active{
		animation.is_active = true
		animation.source = start_pos^
		    animation.dest = start_pos^
		    animation.completed = 0 
		animation.dest += ddp
		animation.ddp = ddp

		if ddp.x == -1{ entity.face_direction = 2; }
		else if ddp.x == 1{ entity.face_direction = 0; }
		else if ddp.y == 1 { entity.face_direction = 1; }

		animation.forced = force;
		game_play_sound(game_state,  AssetSound_Enum.asset_sound_jump);
	    }
	}
    }

    if animation.is_active{
	if animation.completed >= 100{
	    animation.is_active = false

	    start_pos.x = libc.roundf(start_pos.x)
	    start_pos.y = libc.roundf(start_pos.y)

	    chunk, tile := get_chunk_and_tile(world, low.pos)

	    if !animation.forced{
		append_tile(chunk, tile, &platform.arena)

		if is_flag_set(tile.flags, u32(tile_end)){
		    //check_leve_complete(game_state, chunk, entity, low)
		}
		else if is_flag_set(tile.flags, u32(tile_entity)){
		    //go thru all the entities in the tile

		    node := &tile.entities

		    for i in 0..<tile.entity_count{
			tile_entity := &game_state.low_entities[node.entity_index] 

			add_flag(&tile_entity.sim.flags, u32(entity_flag_dead))

			//Do the banner stuffs
			node = node.next
		    }
		}
	    }else{
		old_pos:WorldPosition= {chunk_pos = low.pos.chunk_pos, offset= animation.source}

		_, source_tile := get_chunk_and_tile(world, old_pos)

		if is_flag_set(source_tile.flags, u32(tile_entity)){
		    //do the banner stuff
		}
	    }
	}else {
	    chunk_diff  := animation.ddp
	    diff_to_add := chunk_diff / 10.0
	    start_pos^  += diff_to_add
	    animation.completed += 10
	}
    }
}

add_entity_number::proc(game_state:^GameState, chunk_pos:v2_i32 , offset:v2_f32, val:i32){

}

level_one_init::proc(game_state:^GameState){
    add_walls_around_chunk_pos(game_state, v2_i32{0,0});
    add_enemy(game_state, v2_i32{0,0}, v2_f32{-4.0, 1.0})
    add_tree(game_state, v2_i32{0,0}, v2_f32{4.0, -2.0})
}

level_two_init::proc(game_state:^GameState){
    chunk_pos :v2_i32 = {1,0}
    add_walls_around_chunk_pos(game_state, chunk_pos);
    //add_enemy(game_state, chunk_pos, v2_f32{-4.0, 1.0})
}

all_level_init::proc(game_state:^GameState){
    add_low_entity(game_state, EntityType.entity_type_null, {})
    level_one_init(game_state)  
    level_two_init(game_state)  
}

screen_pos_to_game_pos::proc(game_state:^GameState, pos: v2_i32)->WorldPosition{
    res    :WorldPosition={} 
    world  := game_state.world
    mtop   := v2_f32{f32(world.meters_to_pixels), f32(world.meters_to_pixels)}
    cen100r := world.chunk_size_in_meters * 0.5 

    res.offset = v2_f32{f32(pos.x), f32(pos.y)} / mtop
    res.offset -= center

    return res
}

render_game::proc(input:^GameInput){

    game_state:=cast(^GameState)(platform.permanent_storage)

    if !game_state.is_initilized {

	game_state.world = push_struct(&platform.arena, World)
	initilize_world(game_state.world, platform.window_dim.x, platform.window_dim.y)

	world:=game_state.world
	dim_in_meters:= world.chunk_size_in_meters /2

	game_state.camera_bounds[0] = -dim_in_meters
	game_state.camera_bounds[1] = dim_in_meters

	all_level_init(game_state)

	//TODO: if we always start on menu mode then don't put it on here
	//But that would make it always require to start on menu mode
	{
	    a:= 2.0 / f32(platform.window_dim.x);
	    b:= 2.0 / f32(platform.window_dim.y);

	    proj:[]f32 = {
		a, 0, 0, 0,
		0, b, 0, 0,
		0, 0, 1, 0,
		-1, -1, 0, 1,
	    };

	    gl.UniformMatrix4fv(opengl_config.transform_id, 1, gl.FALSE, &proj[0]);
	}

	game_play_sound(game_state, AssetSound_Enum.asset_sound_background)
	game_state.is_initilized = true
    }


    world:=game_state.world

    mtop := world.meters_to_pixels

    chunk:=get_world_chunk(world, game_state.curr_chunk)

    player_ddp, camera_ddp :v2_f32

    undo:b8 = false


    for controller in input.controllers{
	using ButtonEnum;

	if was_down(escape, controller) {
	    platform.game_mode = GameMode.game_mode_menu
	}

	if was_down(action_left, controller)   {camera_ddp.x = -1}
	if was_down(action_right, controller)  {camera_ddp.x =  1}
	if was_down(action_down, controller)   {camera_ddp.y = -1}
	if was_down(action_up, controller)     {camera_ddp.y =  1}

	if was_down(Key_l, controller)     {opengl_toggle_light()}

	if chunk.player_index == 0{

	    if ended_down(start, controller) {
		_,index := add_player(game_state, v2_f32{0.0, 0.0})
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


    when DEBUG_MODE{
	if platform.game_mode == GameMode.game_mode_debug{
	    if(input.mouse_buttons[0].ended_down && (input.mouse_buttons[0].half_trans_count >0)){
		//fmt.printf("pos = %d, %d\n", input.mouse_x, input.mouse_y)
		pos := screen_pos_to_game_pos(game_state, v2_i32{input.mouse_x, input.mouse_y})
		#partial switch(platform.debug_state.curr_entity){
		    case .entity_type_tree:
		    add_tree(game_state, game_state.curr_chunk, pos.offset)
		    case .entity_type_enemy:
		    add_enemy(game_state, game_state.curr_chunk, pos.offset)
		}
	    }
	}
    }

    update_camera(game_state, camera_ddp)

    trans_state:=cast(^TransientState)rawptr(platform.temp_storage)

    sim_memory := begin_temp_memory(&trans_state.trans_arena)

    sim_regon := begin_sim(sim_memory.arena, game_state, game_state.camera_p, game_state.camera_bounds)

    for entity, i in &sim_regon.entities{
	if u32(i)>=sim_regon.entity_count {break}

	#partial switch entity.type{
	    case .entity_type_player:{
		low := &game_state.low_entities[entity.storage_index]
		if low.pos.chunk_pos == game_state.curr_chunk{
		    chunk := get_world_chunk(world, game_state.curr_chunk)
		    if !chunk.completed{
			if undo {
			    undo_player(game_state, low, &player_ddp)
			}
			update_player(game_state, player_ddp, &entity, low, undo)
		    }
		}
	    }
	    case .entity_type_enemy:{
		low := &game_state.low_entities[entity.storage_index]
		update_enemy(game_state, &entity, low)
	    }
	}
    }

    end_sim(sim_regon, game_state)
    end_temp_memory(sim_memory)

    render_memory := begin_temp_memory(&trans_state.trans_arena)

    head:= sort_entities_for_render(game_state, game_state.camera_bounds, game_state.camera_p, &render_memory)

    background_png := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_background)

    push_render_entities(&head, v2_f32{0,0}, v2_f32{f32(background_png.width), f32(background_png.height)}, EntityType.entity_type_background, background_png, &render_memory)

    when DEBUG_MODE{
	if(input.mouse_z != 0){
	    #partial switch platform.debug_state.curr_entity{
		case .entity_type_tree:{
		    platform.debug_state.curr_entity = .entity_type_enemy
		}case .entity_type_enemy:{
		    platform.debug_state.curr_entity = .entity_type_tree
		}
	    }
	}

	bmp : ^LoadedBitmap = nil
	#partial switch(platform.debug_state.curr_entity){
	    case .entity_type_tree:{
		bmp = get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_tree)
	    }case .entity_type_enemy:{
		bmp = get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_enemy)
	    }
	}
	if(bmp != nil){
	    push_render_entities(&head, v2_f32{f32(input.mouse_x),f32(input.mouse_y)}, v2_f32{f32(mtop), f32(mtop)}, EntityType.entity_type_background, bmp , &render_memory)
	}

    }
    render_entities(game_state, head)
    end_temp_memory(render_memory)
}

game_play_sound::proc(game_state : ^GameState, sound_id : AssetSound_Enum) ->^ PlayingSound {

    if game_state .first_free_playing_sound == nil{
	game_state.first_free_playing_sound = push_struct(&platform.arena, PlayingSound)

	game_state.first_free_playing_sound.next = nil
    }

    playing_sound : = game_state.first_free_playing_sound 
    game_state.first_free_playing_sound = playing_sound.next

    playing_sound.samples_played = 0 
    playing_sound.volume[0] = 0.5 
    playing_sound.volume[1] = 0.5 
    playing_sound.id = sound_id 
    playing_sound.next = game_state.first_playing_sound 
    game_state.first_playing_sound = playing_sound;
    return playing_sound
}

game_get_sound_buffer::proc(sound_buffer : ^GameSoundOutputBuffer) {
    game_state:= cast(^GameState)platform.permanent_storage
    trans_state  := cast(^TransientState)platform.temp_storage
    mixer_memory := begin_temp_memory(&trans_state.trans_arena)

    real_channel_0 := push_array(mixer_memory.arena,f32, sound_buffer.sample_count)
    real_channel_1 := push_array(mixer_memory.arena,f32, sound_buffer.sample_count)

    {
	dest_0 :=real_channel_0
	dest_1 :=real_channel_1

	for i : u32= 0; i < sound_buffer.sample_count; i+=1{
	    offset(dest_0, i)^ = 0.0
	    offset(dest_1, i)^ = 0.0
	}
    }

    playing_sound_ptr :^^PlayingSound= nil

    if game_state.first_playing_sound != nil{
	playing_sound_ptr = &game_state.first_playing_sound
    }

    for playing_sound_ptr != nil && playing_sound_ptr^ != nil{
	playing_sound  := playing_sound_ptr^
	    sound_finished := false

	loaded_sound := get_sound_asset(&platform.sound_asset, playing_sound.id)

	if loaded_sound != nil{
	    volume_0 := playing_sound.volume[0]
	    volume_1 := playing_sound.volume[1]

	    dest_0 := real_channel_0
	    dest_1 := real_channel_1

	    samples_to_mix :u32= sound_buffer.sample_count
	    samples_remaining_in_sound := loaded_sound.sample_count - playing_sound.samples_played

	    if samples_to_mix > samples_remaining_in_sound{
		samples_to_mix = samples_remaining_in_sound
	    }

	    for sample_index in  playing_sound.samples_played..< (playing_sound.samples_played + samples_to_mix){

		sample_value:f32 = f32(offset(loaded_sound.samples[0], sample_index)^)
		
		dest_0^ += volume_0 * sample_value
		dest_1^ += volume_1 * sample_value

		dest_0 = offset(dest_0, 1)
		dest_1 = offset(dest_1, 1)
	    }

	    sound_finished = playing_sound.samples_played >= loaded_sound.sample_count
	    playing_sound.samples_played += samples_to_mix
	}else{
	    assert(1 == 0)
	}

	if(sound_finished){
	    playing_sound_ptr^ = playing_sound.next
	    playing_sound.next = game_state.first_free_playing_sound
	    game_state.first_free_playing_sound = playing_sound
	}else{
	    playing_sound_ptr = &playing_sound.next
	}
    }

    {
	sound_0 := real_channel_0
	sound_1 := real_channel_1

	sample_out:^i16=sound_buffer.samples

	for sample_index in 0 ..< sound_buffer.sample_count{
	    sample_out^ = (i16)(sound_0^ + 0.5)
	    sample_out  = offset(sample_out, 1)     
	    sound_0     = offset(sound_0, 1)     

	    sample_out^ = (i16)(sound_1^ + 0.5)
	    sample_out  = offset(sample_out, 1)     
	    sound_1     = offset(sound_1, 1)     
	}
    }
    end_temp_memory(mixer_memory)
}
