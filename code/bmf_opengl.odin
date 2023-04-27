package main
import gl "vendor:OpenGL"
import os "core:os"
import mem "core:mem"

foreign import opengl32 "system:Opengl32.lib"

foreign opengl32{
	//glTexEnvi::proc(target:u32 , pname:u32, param:i32)---
	glTexImage2D::proc(target:u32, level:i32, internalformat:i32, width:i32, height:i32, border:i32, format:i32, type:u32, pixels:rawptr)---
}


OpenglContext::struct{
	tex_handle:u32,
	vbo        :u32,
	vao        :u32,
	ebo        :u32,
}

OpenglInfo::struct{
	modern_context:b8,
	vendor:string,
	renderer: string,
	version: string,
	shading_version: string,
	extensions: string,

	GL_EXT_texture_sRGB:b8,
	GL_EXT_framebuffer_sRGB:b8,
	GL_ARB_framebuffer_object:b8,
}

OpenglConfig::struct{
	basic_light_program:u32,
	default_internal_text_format:u32,
	texture_sampler_id:u32,
	transform_id:i32,
	light_pos_id:i32,
	use_light:i32,
	tile_uniform:i32,
	use_light_local:b8,
}

opengl_get_info::proc()->OpenglInfo{
	using gl
	result:OpenglInfo  = {};
	result.modern_context = true;
	result.vendor   = cast(string)GetString(VENDOR);
	result.renderer = cast(string)GetString(RENDERER);
	result.version  = cast(string)GetString(VERSION);
	result.shading_version = cast(string)GetString(SHADING_LANGUAGE_VERSION);

	if(result.modern_context){
	}else{
		result.shading_version = "(none)";
	}
	result.extensions = cast(string)GetString(EXTENSIONS);
	return result
}

opengl_create_program::proc(vertex_shader_code:cstring , fragment_shader_code:cstring)->u32{
	vertex_shader_code := vertex_shader_code
	fragment_shader_code:= fragment_shader_code
	using gl
	vertex_shader_id:u32 = CreateShader(VERTEX_SHADER);
	ShaderSource(vertex_shader_id,1, &vertex_shader_code, nil);
	CompileShader(vertex_shader_id);


	fragment_shader_id:u32 = CreateShader(FRAGMENT_SHADER);
	ShaderSource(fragment_shader_id,1,  &fragment_shader_code,nil);
	CompileShader(fragment_shader_id);

	program_id:u32 = CreateProgram();
	AttachShader(program_id, vertex_shader_id);
	AttachShader(program_id, fragment_shader_id);
	LinkProgram(program_id);
	ValidateProgram(program_id);

	linked:i32 = 0;
	GetProgramiv(program_id, LINK_STATUS, &linked);

	if !bool(linked){
		ignored:i32;
		vertex_errors:[255]rune;
		fragment_errors:[255]rune;
		program_errors:[255]rune;

		GetShaderInfoLog(vertex_shader_id, 255, &ignored, cast([^]u8)&vertex_errors[0]);
		GetShaderInfoLog(fragment_shader_id, 255, &ignored, cast([^]u8)&fragment_errors[0]);
		GetProgramInfoLog(program_id, 255, &ignored, cast([^]u8)&program_errors[0]);
		assert(1==0)
	}
	return program_id;
}

opengl_init::proc(modern_context:b8){
	using gl
	info:=opengl_get_info()
	opengl_config.default_internal_text_format = SRGB8_ALPHA8
	Enable(FRAMEBUFFER_SRGB)
	//glTexEnvi(TEXTURE_ENV, TEXTURE_ENV_MODE, MODULATE)

	frag,_ := os.read_entire_file_from_filename("frag.glsl")
	vert,_ := os.read_entire_file_from_filename("vert.glsl")

	opengl_config.basic_light_program = opengl_create_program(cstring(&vert[0]), cstring(&frag[0]))
	opengl_config.transform_id = GetUniformLocation(opengl_config.basic_light_program, "mat");
	opengl_config.tile_uniform = GetUniformLocation(opengl_config.basic_light_program, "tiles");

	opengl_config.light_pos_id = GetUniformLocation(opengl_config.basic_light_program, "light_pos");
	opengl_config.use_light = GetUniformLocation(opengl_config.basic_light_program, "use_light");

	Enable(BLEND);
	BlendFunc(ONE, ONE_MINUS_SRC_ALPHA);
	BlendFunc(SRC_ALPHA, ONE_MINUS_SRC_ALPHA);
	//LineWidth(1);
	UseProgram(opengl_config.basic_light_program)


	//TODO: Put this in game_render proc
	/*
	*/
}


opengl_init_texture::proc(gl_context: ^OpenglContext, min_p:v2_f32 , max_p:v2_f32 , color:v4,  width:i32, height:i32, image:^LoadedBitmap = nil){

	using gl

  vertices:[]f32 = {
    max_p.x,  max_p.y, 0.0,   0.0, 0.0, color.r, color.g, color.b, color.a, // top right
    max_p.x,  min_p.y, 0.0,   0.0, 1.0, color.r, color.g, color.b, color.a, // bottom right
    min_p.x,  min_p.y, 0.0,   1.0, 1.0, color.r, color.g, color.b, color.a, // bottom left
    min_p.x,  max_p.y, 0.0,   1.0, 0.0, color.r, color.g, color.b, color.a, // top left 
  };

  GenVertexArrays(1, &gl_context.vao);
  GenBuffers(1, &gl_context.vbo);
  GenBuffers(1, &gl_context.ebo);

  if(image != nil){
    GenTextures(1, &gl_context.tex_handle);
    BindTexture(TEXTURE_2D, gl_context.tex_handle);
    TexImage2D(TEXTURE_2D, 0, RGBA, width, height, 0, RGBA, UNSIGNED_BYTE, image.pixels);

    TexParameteri(TEXTURE_2D, TEXTURE_MIN_FILTER, LINEAR);
    TexParameteri(TEXTURE_2D, TEXTURE_MAG_FILTER, LINEAR);    
    TexParameteri(TEXTURE_2D, TEXTURE_WRAP_S, CLAMP);
    TexParameteri(TEXTURE_2D, TEXTURE_WRAP_T, CLAMP);    
    //glTexEnvi(TEXTURE_ENV, TEXTURE_ENV_MODE, MODULATE);

  }

  indices:[]i32={
    0, 1, 3, //First triangle
    1, 2, 3  //Second triangle
  };
  BindVertexArray(gl_context.vao);
  BindBuffer(ARRAY_BUFFER, gl_context.vbo);
  BufferData(ARRAY_BUFFER, len(vertices) * size_of(f32), raw_data(vertices), STATIC_DRAW);
  BindBuffer(ELEMENT_ARRAY_BUFFER, gl_context.ebo);
  BufferData(ELEMENT_ARRAY_BUFFER, len(indices) * size_of(i32), raw_data(indices), STATIC_DRAW);

  EnableVertexAttribArray(0);
  EnableVertexAttribArray(1);
  EnableVertexAttribArray(2);
  VertexAttribPointer(1, 2, FLOAT, TRUE, 9 * size_of(f32), (3 * size_of(f32)));
  VertexAttribPointer(0, 3, FLOAT, TRUE, 9 * size_of(f32), uintptr(rawptr((nil))));
  VertexAttribPointer(2, 4, FLOAT, TRUE, 9 * size_of(f32), (5 * size_of(f32))); 
}


opengl_update_vertex_data::proc(gl_context:^OpenglContext , min_p:v2_f32 , max_p:v2_f32 , color:v4 = v4{-1,-1,-1,-1}){

	using gl
  BindVertexArray(gl_context.vao);
  BindBuffer(ARRAY_BUFFER, gl_context.vbo);

   top_right    :v2_f32= v2_f32{max_p.x, max_p.y};
   bottom_right :v2_f32= v2_f32{max_p.x, min_p.y};
   bottom_left  :v2_f32= v2_f32{min_p.x, min_p.y};
   top_left     :v2_f32= v2_f32{min_p.x, max_p.y};

  BufferSubData(ARRAY_BUFFER, 0, 2 * size_of(f32), rawptr(&top_right[0]));
  BufferSubData(ARRAY_BUFFER, 1 * 9 * size_of(f32), 2 * size_of(f32), rawptr(&bottom_right[0]));
  BufferSubData(ARRAY_BUFFER, 2 * 9 * size_of(f32), 2 * size_of(f32), rawptr(&bottom_left[0]));
  BufferSubData(ARRAY_BUFFER, 3 * 9 * size_of(f32), 2 * size_of(f32), rawptr(&top_left[0]));

  color_mat:[4]f32= {color.r, color.g, color.b, color.a}

    BindTexture(TEXTURE_2D, gl_context.tex_handle);
  if(color.r == -1){
  }else{
    BufferSubData(ARRAY_BUFFER, 0 * 9 * size_of(f32) + 5*size_of(f32), 4 * size_of(f32), &color_mat[0]);
    BufferSubData(ARRAY_BUFFER, 1 * 9 * size_of(f32) + 5*size_of(f32), 4 * size_of(f32), &color_mat[0]);
    BufferSubData(ARRAY_BUFFER, 2 * 9 * size_of(f32) + 5*size_of(f32), 4 * size_of(f32), &color_mat[0]);
    BufferSubData(ARRAY_BUFFER, 3 * 9 * size_of(f32) + 5*size_of(f32), 4 * size_of(f32), &color_mat[0]);
  }
}

//All of the int arguements is in pixels
opengl_bitmap::proc(image:^LoadedBitmap, min_x:f32, min_y:f32 , width:f32 , height:f32){
	using gl
  max_x  := min_x + width;
  max_y  := min_y + height;

  //The coordinates are always the same just change the position
  if(image.gl_context.tex_handle == 0){

    //If it is a font that i processed using asset_builder.cpp
    //TODO: find different way to process and render font
    opengl_init_texture(&image.gl_context, v2_f32{min_x, min_y}, v2_f32{max_x, max_y}, v4{1,1,1,1}, image.width, image.height, image);
  }else{
    opengl_update_vertex_data(&image.gl_context, v2_f32{min_x, min_y}, v2_f32{max_x, max_y});
  }
  DrawElements(TRIANGLES, 6, UNSIGNED_INT, rawptr((nil)));
  //DrawArrays(TRIANGLE_STRIP,0,4)
}




