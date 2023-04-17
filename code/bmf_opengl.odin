package main
import gl "vendor:OpenGL"
import os "core:os"

OpenglContext::struct{
	text_handle:u32,
	vbo        :u32,
	vao        :u32,
}

OpenglInfo::struct{
	modern_context:b8,
	vendor:string,
	renderer: string,
	version: string,
	shading_version: string,
	extentions: string,

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

opengl_get_info::proc(){
	using gl
	result:OpenglInfo  = {};
	result.modern_context = true;
	result.vendor   = cast(string)GetString(VENDOR);
	result.renderer = cast(string)GetString(RENDERER);
	result.version  = cast(string)GetString(VERSION);
	result.shading_version = cast(string)GetString(SHADING_LANGUAGE_VERSION);

  /*
	if(result.modern_context){
	}else{
		result.shading_version = "(none)";
	}
	result.extensions = cast(string)GetString(GL_EXTENSIONS);
  char* at = result.extensions;
  while(*at){
    while(is_whitespace(*at)) {++at;}
    char* end = at;
    //NOTE(samrat) Chopping up the string
    while(*end && !is_whitespace(*end)){++end;}
    U32 count = end - at;

    if(0){}
    else if(strings_are_equal(count, at, "GL_EXT_texture_sRGB")){
      result.GL_EXT_texture_sRGB=true;
    }else if(strings_are_equal(count, at, "GL_EXT_framebuffer_sRGB")){
      result.GL_EXT_framebuffer_sRGB=true;
    }
    at = end;
  }
  */
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
		/*
		ignored:u32;
		vertex_errors:cstring ;
		fragment_errors:cstring ;
		program_errors:cstring ;
		GetShaderInfoLog(vertex_shader_id, 255, &ignored, vertex_errors);
		GetShaderInfoLog(fragment_shader_id, 255, &ignored, fragment_errors);
		GetProgramInfoLog(program_id, 255, &ignored, program_errors);
		*/
	}
	return program_id;
}

opengl_init::proc(modern_context:b8){
	using gl
	opengl_get_info()
	opengl_config.default_internal_text_format = SRGB8_ALPHA8
	Enable(FRAMEBUFFER_SRGB)
	//TexEnvi(TEXTURE_ENV, TEXTURE_ENV_MODE_GL_MODULATE)

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
	LineWidth(1);
	UseProgram(opengl_config.basic_light_program)


	//TODO: Put this in game_render proc
	/*
    a:f32 = 2.0f / cast(f32)buffer->width;
    b:f32 = 2.0f / cast(f32)buffer->height;

	proj:[]f32 = {
		a, 0, 0, 0,
		0, b, 0, 0,
		0, 0, 1, 0,
		-1, -1, 0, 1,
	};
	UniformMatrix4fv(opengl_config.transform_id, 1, GL_FALSE, &proj[0]);
	*/
}




