package main

import gl "vendor:OpenGL"

MenuItem::struct{
    title    :string,
}

MenuState::struct{
    initilized  : b8,
    click       : b8,
    selected    : u8,
    items       : [4]MenuItem,
    gl_context  : OpenglContext,
}

show_menu::proc(state:^MenuState){
    mtop :i32= 1;
    min_x, min_y:f32;

    center_x := f32(platform.window_dim.x)  * 0.3;
    center_y := f32(platform.window_dim.y) * 0.7;

    font:=platform.font_asset

    for i :u8= 0; i < len(state.items); i+=1{
	item := &state.items[i];

	if(i == state.selected){
	    min_x = center_x;
	    min_y = (center_y) - f32(i) * font.line_advance - 10

	    width  := min_x + f32(len(item.title)) * f32(font.size)/2.0
	    height := min_y + f32(100);
	    opengl_draw_rect(min_x, min_y, width, height, &state.gl_context);
	} 

	offset :i32= 0
	for j := 0; j < len(item.title); j+=1 {

	    c := item.title[j];

	    bmp := get_font(&platform.font_asset, rune(c));

	    if bmp != nil{
		tex_width  := bmp.image.width  * mtop;
		tex_height := bmp.image.height * mtop;
		min_x = (center_x + f32(offset))
		min_y = (center_y) -f32(bmp.image.height) - bmp.y_offset - f32(i) * font.line_advance
		opengl_bitmap(&bmp.image, v2_f32{min_x, min_y}, v2_f32{f32(tex_width), f32(tex_height)});
	    }

	    if(c == ' '){
		offset += 10 //Space lol
	    }else{
		offset += i32(bmp.image.width) + i32(bmp.x_offset)
	    }
	}
	//offset += i32(buffer.width) * i32(font.line_gap)
    }
}

render_menu::proc(input:^GameInput){

    state:= (^MenuState)(rawptr(uintptr(platform.permanent_storage) + uintptr(size_of(GameState))))

    if !state.initilized{
	state.items[0].title = "Settings" 
	state.items[1].title = "New Game" 
	state.items[2].title = "Quit" 
	state.items[3].title = "Resume" 

	state.selected = 0

	a:= 2.0 / f32(platform.window_dim.x);
	b:= 2.0 / f32(platform.window_dim.y);

	proj:[]f32 = {
	    a, 0, 0, 0,
	    0, b, 0, 0,
	    0, 0, 1, 0,
	    -1, -1, 0, 1,
	};

	gl.UniformMatrix4fv(opengl_config.transform_id, 1, gl.FALSE, &proj[0]);
	state.initilized = true
    }


    background_png := get_bmp_asset(&platform.bmp_asset, BmpAsset_Enum.asset_background)
    opengl_bitmap(background_png, v2_f32{0, 0}, v2_f32{f32(background_png.width), f32(background_png.height)})

    show_menu(state)

    for controller in input.controllers{
	using ButtonEnum;

	if was_down(action_down, controller){
	    if state.selected < 3 {
		state.selected +=1
	    }
	    state.click = true
	}

	if was_down(action_up, controller){
	    if state.selected > 0 {
		state.selected -=1
	    }
	    state.click = true
	}
    }
}









