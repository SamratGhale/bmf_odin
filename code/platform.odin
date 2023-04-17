package main

import "core:mem"

MemoryArena::struct{
	size      :i64,
	base      :^u8,
	used      :i64,
	temp_count:i32,
}

TransientState::struct{
	is_initilized :b8,
	trans_arena   :MemoryArena,
}

get_alignment_offset::proc(arena:^MemoryArena, alignment:i64)->(align_offset:i64){
	align_offset = 0;
	result_ptr := mem.ptr_offset(arena.base , arena.used);

	align_mask := alignment - 1;
	if b32(i64(cast(uintptr)result_ptr) & align_mask) {
		align_offset = alignment - (i64(cast(uintptr)result_ptr) & align_mask);
	}
	return;
}

initilize_arena::proc(arena:^MemoryArena, size:i64, base:^u8){
	arena.size = size;
	arena.base = base;
	arena.used = 0;
}

push_struct::proc(arena:^MemoryArena, $T:typeid)->(ret:^T){
	return cast(^T)push_size_(arena, size_of(T))
}

push_array::proc(arena:^MemoryArena, $T:typeid, length:u32)->(ret:^T){
	return cast(^T)push_size_(arena, i64(size_of(T)* i32(length)))
}

push_size_::proc(arena:^MemoryArena, size_init:i64, align:i64=4)->(ret:rawptr){
	size:=size_init
	align_offset := get_alignment_offset(arena, align)
	size += align_offset

	assert((arena.used + size) <= arena.size)
	ret = mem.ptr_offset(arena.base , arena.used + align_offset)
	arena.used += size
	assert(size >= size_init)
	return
}

TempMemory::struct{
	arena:^MemoryArena,
	used:i64 
}

begin_temp_memory::proc(arena:^MemoryArena)->TempMemory{
	result:TempMemory={arena = arena, used = arena.used};
	arena.temp_count+=1
	return result
}

end_temp_memory::proc(temp_arena:TempMemory){
	arena:= temp_arena.arena
	arena.used = temp_arena.used
	arena.temp_count+=1
}

OffscreenBuffer::struct{
	memory           :^u8,
	pitch            :i32,
	width            :i32,
	height           :i32,
	bytes_per_pixel  :i32,
}


ButtonState::struct{
	half_trans_count :i32,		
	ended_down       :b8,
}

ButtonEnum::enum{
	move_up,
	move_down,
	move_left,
	move_right,
	action_up,
	action_down,
	action_left,
	action_right,
	left_shoulder,
	right_shoulder,
	back,
	start,
	Key_u,
	Key_l,  
	Key_t,  
	enter,
	escape,
}

ControllerInput::struct {
  is_connected  :b8,
  is_analog     :b8,
  stick_x		  	:f32,
  stick_y				:f32,
  buttons       :[17]ButtonState,
};

GameInput::struct{
	mouse_buttons             :[5]ButtonState,
	dt_for_frame              :f32,
	mouse_x, mouse_y, mouse_z :i32,
	controllers               :[5]ControllerInput
}

GameMode::enum{
	game_mode_play,
	game_mode_menu,
}

PlatformState::struct{
	total_size        :i64,
	permanent_size    :i64,
	temp_size         :i64,
	permanent_storage :^u8,
	temp_storage			:^u8,
	arena 						:MemoryArena,
	bmp_asset         :BmpAsset
}

Kilobytes::1024
Megabytes::Kilobytes*1024
Gigabytes::Megabytes*1024
