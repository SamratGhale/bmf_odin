package main

import        "core:os"
import win32  "core:sys/windows"
import        "core:intrinsics"
import        "core:mem"
import gl     "vendor:OpenGL"
const_utf16 :: intrinsics.constant_utf16_cstring

//global variables
null_val:uintptr 
running:bool=true
back_buffer:OffscreenBuffer
opengl_config:OpenglConfig
platform:PlatformState
global_perf_count_freq:i64
secondary_buff: ^IDirectSoundBuffer

win32_get_wall_clock::proc()->(result:win32.LARGE_INTEGER){
	using win32
	QueryPerformanceCounter(&result)
	return 
}

win32_get_seconds_elapsed::proc(start:win32.LARGE_INTEGER , end:win32.LARGE_INTEGER )->(result:f32){
	using win32
	result = (f32(end))/(f32(global_perf_count_freq))
	return
}

resize_buffer::proc(buffer:^OffscreenBuffer, width:i32, height:i32) {
	buffer.width = width;
	buffer.height = height;
	buffer.bytes_per_pixel = 4;
	buffer.pitch = width * buffer.bytes_per_pixel;
}

window_callback:: proc(window: win32.HWND , message: win32.UINT , WParam:win32.WPARAM , LParam:win32.LPARAM )->win32.LRESULT {
	using win32

	result:LRESULT = 0;

	switch message{
		case WM_PAINT:{

			width, height := get_window_dimention(window)
			resize_buffer(&back_buffer, width, height)
			paint: PAINTSTRUCT
			BeginPaint(window, &paint)
			EndPaint(window, &paint)

		}
		case WM_QUIT, WM_DESTROY: {
			running = false;
		}
		case WM_COMMAND: {
			if LOWORD(cast(u32)WParam) == 2 {
				running = false;
			}
		}
		case:{
			return DefWindowProcW(window, message, WParam, LParam);
		}
	}
	return result
}

process_xinput_button::proc(button_state:u16, old_state:^ButtonState, button_bit:u16, new_state:^ButtonState){
	new_state:=new_state
	new_state.ended_down = ((button_state & button_bit) == button_bit)
	new_state.half_trans_count = (old_state.ended_down != new_state.ended_down)?1:0
}

process_stick_value::proc(value:win32.SHORT, dead_zone:win32.SHORT)->(result:f32){
	if value < -dead_zone{
		result = f32(value + dead_zone)/f32(23768.0 - dead_zone)
	}else if value > dead_zone{
		result = f32(value - dead_zone)/f32(23768.0 - dead_zone)
	}
	return
}

process_keyboard_message::proc(new_state:^ButtonState, is_down:b32){
	if new_state.ended_down != is_down{
		new_state.ended_down = is_down
		new_state.half_trans_count+=1
	}
}

process_pending_messages::proc(keyboard:^ControllerInput){

	keyboard:= keyboard
	using win32	
	message:MSG 
	raw:rawptr

	using ButtonEnum
	for PeekMessageA(&message, cast(HWND)raw, 0, 0, PM_REMOVE){
		switch(message.message){

			case WM_SYSKEYDOWN, WM_SYSKEYUP, WM_KEYDOWN, WM_KEYUP:
			{
				was_down:b32= ((message.lParam &(1<<30))!=0)
				is_down:b32= ((message.lParam &(1<<31))==0)
				vk_code:u32= cast(u32)message.wParam;

				if is_down != was_down{
					switch vk_code{
						case 'W':      process_keyboard_message(&keyboard.buttons[move_up], is_down)
						case 'A':      process_keyboard_message(&keyboard.buttons[move_left], is_down)
						case 'S':      process_keyboard_message(&keyboard.buttons[move_down], is_down)
						case 'D':      process_keyboard_message(&keyboard.buttons[move_right], is_down)
						case 'Q':      process_keyboard_message(&keyboard.buttons[left_shoulder], is_down)
						case 'E':      process_keyboard_message(&keyboard.buttons[right_shoulder], is_down)
						case VK_UP:    process_keyboard_message(&keyboard.buttons[action_up], is_down)
						case VK_DOWN:  process_keyboard_message(&keyboard.buttons[action_down], is_down)
						case VK_LEFT:  process_keyboard_message(&keyboard.buttons[action_left], is_down)
						case VK_RIGHT: process_keyboard_message(&keyboard.buttons[action_right], is_down)
						case VK_ESCAPE: process_keyboard_message(&keyboard.buttons[escape], is_down)
						case VK_SPACE:  process_keyboard_message(&keyboard.buttons[start], is_down)
						case VK_BACK:   process_keyboard_message(&keyboard.buttons[back], is_down)
						case VK_RETURN: process_keyboard_message(&keyboard.buttons[enter], is_down)
						case 'L':       process_keyboard_message(&keyboard.buttons[Key_l], is_down)
						case 'T':       process_keyboard_message(&keyboard.buttons[Key_t], is_down)
						case 'U':       process_keyboard_message(&keyboard.buttons[Key_u], is_down)
					}
				}

				if is_down{
					alt_key_was_down:b8 = b8((int(message.lParam) &(1<<29)))

					if (vk_code == VK_F4) && alt_key_was_down{
						running = false
					}
				}
			}
			case WM_QUIT:
			case WM_DESTROY: {
				running = false;
			}

			case:{
				TranslateMessage(&message)
				DispatchMessageW(&message)
			}
		}
	}
}


display_buffer_in_window::proc(buffer:^OffscreenBuffer, dc:win32.HDC , width:i32, height:i32) {
	win32.SwapBuffers(dc);
}

get_window_dimention::proc(window:win32.HWND)->(width:i32, height:i32){
	using win32
	client_rect:RECT 
	GetClientRect(window, &client_rect)
	height = client_rect.bottom - client_rect.top
	width  = client_rect.right - client_rect.left
	return
}

gl_set_proc_address :: proc(p: rawptr, name: cstring) {
	using win32
	func := wglGetProcAddress(name)
	switch uintptr(func) {
		case 0, 1, 2, 3, ~uintptr(0):
		module := LoadLibraryW(const_utf16("opengl32.dll"))
		func = GetProcAddress(module, name)
	}
	(^rawptr)(p)^ = func
}

win32_init_opengl::proc(window:win32.HWND ){
	using win32
	window_dc :HDC= win32.GetDC(window);

	desired_pixel_format:PIXELFORMATDESCRIPTOR = {};
	desired_pixel_format.nSize = size_of(desired_pixel_format);
	desired_pixel_format.nVersion = 1;
	desired_pixel_format.dwFlags =
	PFD_SUPPORT_OPENGL | PFD_DRAW_TO_WINDOW | PFD_DOUBLEBUFFER;
	desired_pixel_format.iPixelType = PFD_TYPE_RGBA;
	desired_pixel_format.cColorBits = 32;
	desired_pixel_format.cAlphaBits = 8;
	desired_pixel_format.iLayerType = PFD_MAIN_PLANE;

	suggested_pixel_format_index:i32= ChoosePixelFormat(window_dc, &desired_pixel_format);

	suggested_pixel_format:PIXELFORMATDESCRIPTOR ;
	DescribePixelFormat(window_dc, suggested_pixel_format_index, size_of(suggested_pixel_format), &suggested_pixel_format);
	SetPixelFormat(window_dc, suggested_pixel_format_index, &suggested_pixel_format);
	opengl_rc:HGLRC  = wglCreateContext(window_dc);

	if bool(wglMakeCurrent(window_dc, opengl_rc)){


		modern_context:b8  = false;
		attribs:=[?]i32{
			WGL_CONTEXT_MAJOR_VERSION_ARB, 3,
			WGL_CONTEXT_MINOR_VERSION_ARB, 2,
			WGL_CONTEXT_FLAGS_ARB, WGL_CONTEXT_FORWARD_COMPATIBLE_BIT_ARB |WGL_CONTEXT_DEBUG_BIT_ARB ,
			WGL_CONTEXT_PROFILE_MASK_ARB, WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
			0,
		}
		share_context:HGLRC = cast(HGLRC)null_val;
		wglCreateContextAttribsARB = CreateContextAttribsARBType(wglGetProcAddress("wglCreateContextAttribsARB"))

		wglSwapIntervalEXT = SwapIntervalEXTType(wglGetProcAddress("wglSwapIntervalEXT"))
		modern_glrc:HGLRC = wglCreateContextAttribsARB(window_dc, share_context, &attribs[0])

		gl.load_up_to(3, 2, gl_set_proc_address);
		if modern_glrc != nil{
			if bool(wglMakeCurrent(window_dc, modern_glrc)){
				modern_context = true
				wglDeleteContext(opengl_rc)
				opengl_rc = modern_glrc
			}
		}
		opengl_init(modern_context)
		wglSwapIntervalEXT(1)
	}
	ReleaseDC(window, window_dc)
}

win32_init_dsound::proc(window:win32.HWND, samples_per_second:u32, buffer_size: u32){
	direct_sound: ^IDirectSound = {}

	if(win32.SUCCEEDED(DirectSoundCreate(nil, &direct_sound, nil))){
		wave_format: WAVEFORMATEX= {}

		wave_format.wFormatTag      = WAVE_FORMAT_PCM
		wave_format.nChannels       = 2
		wave_format.nSamplesPerSec  = u32(samples_per_second) /* sample rate */
		wave_format.wBitsPerSample  =  16 /* number of bits per sample of mono data */
		wave_format.nBlockAlign     =	(wave_format.nChannels * wave_format.wBitsPerSample)/8 /* block size of data */
		wave_format.nAvgBytesPerSec = wave_format.nSamplesPerSec * u32(wave_format.nBlockAlign) /* for buffer estimation */

		if(win32.SUCCEEDED(direct_sound->SetCooperativeLevel(window, DSSCL_PRIORITY))){
			buffer_des: DSBUFFERDESC  = {}

			buffer_des.dwSize  = size_of(buffer_des)
			buffer_des.dwFlags = DSBCAPS_PRIMARYBUFFER 

			primary_buff:^IDirectSoundBuffer = {}

			if(win32.SUCCEEDED(direct_sound->CreateSoundBuffer(&buffer_des, &primary_buff, nil))){

				if(win32.SUCCEEDED(primary_buff->SetFormat(&wave_format))){
					win32.OutputDebugStringA("Primary buffer format was set")
				}
			}
		}

		buffer_des:DSBUFFERDESC = {}
		buffer_des.dwSize         = size_of(buffer_des)
		buffer_des.dwBufferBytes  = u32(buffer_size)
		buffer_des.lpwfxFormat    = &wave_format
		buffer_des.dwFlags        = DSBCAPS_GLOBALFOCUS

		if(win32.SUCCEEDED(direct_sound->CreateSoundBuffer(&buffer_des, &secondary_buff, nil))){
			win32.OutputDebugStringA("Secondary buffer format was set")
		}
	}
}

fill_sound_buffer::proc(sound_output:^SoundOutput, byte_to_lock:win32.DWORD, byte_to_write:win32.DWORD, source_buffer:^GameSoundOutputBuffer){

	using win32

	region_1, region_2:rawptr 
	region1_size, region2_size:DWORD


	if (SUCCEEDED(secondary_buff->Lock(byte_to_lock, byte_to_write, 
		&region_1, &region1_size, 
		&region_2, &region2_size, 0))) {

		region1_sample_count:DWORD= region1_size / sound_output.bytes_per_sample;
		dest_sample:^i16   = cast(^i16)region_1;
		source_sample:^i16 = source_buffer.samples;
		for i in 0..< region1_sample_count{

			dest_sample^ = source_sample^;

			source_sample = offset(source_sample, 1)
			dest_sample = offset(dest_sample ,1)

			dest_sample^ = source_sample^;

			source_sample = offset(source_sample, 1)
			dest_sample = offset(dest_sample ,1)

			sound_output.running_sample_index += 1;
		}

		region2_sample_count :DWORD= region2_size / sound_output.bytes_per_sample;
		dest_sample = cast(^i16)region_2;

		for i in 0..< region2_sample_count {

			dest_sample^ = source_sample^;

			source_sample = offset(source_sample, 1)
			dest_sample = offset(dest_sample ,1)

			dest_sample^ = source_sample^;

			source_sample = offset(source_sample, 1)
			dest_sample = offset(dest_sample ,1)


			sound_output.running_sample_index += 1;
		}
		secondary_buff->Unlock(region_1, region1_size, region_2, region2_size);
	}

}

main:: proc(){
	using win32

	window_instance := cast(win32.HINSTANCE)(win32.GetModuleHandleW(nil))

	window_class := win32.WNDCLASSW {
		style = win32.CS_VREDRAW | win32.CS_HREDRAW | win32.CS_OWNDC,
		lpfnWndProc = cast(WNDPROC)window_callback,
		cbClsExtra = {},
		cbWndExtra = {},
		hInstance = window_instance,
		hIcon = {},
		hCursor = {},
		hbrBackground = {},
		lpszMenuName = nil,
		lpszClassName = const_utf16("my window class"),
	}

	RegisterClassW(&window_class)

	window:= win32.CreateWindowExW(
		dwExStyle = {},
		lpClassName = window_class.lpszClassName,
		lpWindowName = const_utf16("Playing around"),
		dwStyle = win32.WS_VISIBLE | win32.WS_OVERLAPPEDWINDOW,
		X = win32.CW_USEDEFAULT,
		Y = win32.CW_USEDEFAULT,
		nWidth  = 1744,
		nHeight = 1119,
		hWndParent = nil,
		hMenu = nil,
		lpParam = nil,
		hInstance = window_instance,
		)

	assert(window != nil)

	desired_schedular_ms:u32 = 1
	sleep_is_granular:b32 = (timeBeginPeriod(desired_schedular_ms) == TIMERR_NOERROR)

	perf_count_freq_res:LARGE_INTEGER;
	QueryPerformanceFrequency(&perf_count_freq_res)
	global_perf_count_freq = i64(perf_count_freq_res)

	monitor_refresh_rate := 60;
	monitor_seconds_per_frame:= (1.0/(f32(monitor_refresh_rate)))

    //testing 
    win32_init_opengl(window)

    //Input initilization
    input:[2]GameInput = {}
    old_input, new_input := &input[0] ,&input[1]


    //Platform initilization
    platform.permanent_size = Gigabytes*1
    platform.temp_size      = Gigabytes*1
    platform.game_mode      = GameMode.game_mode_play
    platform.total_size     = platform.permanent_size + platform.temp_size
    //Zero memory is false now but we might need to change it to true
    platform.permanent_storage = cast(^u8)os.heap_alloc(int(platform.total_size), false)
    platform.temp_storage = mem.ptr_offset(platform.permanent_storage,platform.permanent_size)
    //read_font_asset("../data/fonts.dat", &platform.font_asset)

    initilize_arena(&platform.arena, platform.total_size, mem.ptr_offset(platform.permanent_storage, size_of(GameState) + size_of(MenuState)))

    trans_state:= cast(^TransientState)rawptr(platform.temp_storage)

    initilize_arena(&trans_state.trans_arena, platform.temp_size - size_of(TransientState), mem.ptr_offset(platform.temp_storage, size_of(TransientState)))

    hdc :HDC = GetDC(window)

    //Timer code
    flip_wall_clock := win32_get_wall_clock()
    last_counter    := win32_get_wall_clock()


    //Sound stuffs

    sound_output:SoundOutput
    sound_output.samples_per_second     = 48000
    sound_output.bytes_per_sample       = size_of(i16) * 2
    sound_output.secondary_buffer_size  = sound_output.samples_per_second * sound_output.bytes_per_sample

    sound_bytes_per_frame :int= int(f32(sound_output.samples_per_second) * f32(sound_output.bytes_per_sample) / f32(monitor_refresh_rate))

    sound_output.safety_bytes           = u32(sound_bytes_per_frame/3.0)

    win32_init_dsound(window, sound_output.samples_per_second, sound_output.secondary_buffer_size)

    secondary_buff->Play(0,0, DSBPLAY_LOOPING)

    samples: ^i16 = cast(^i16)os.heap_alloc(int(sound_output.secondary_buffer_size), true)



    sound_is_valid:b8=false

    for running {
    	new_keyboard_controller := &new_input.controllers[0];
    	old_keyboard_controller := &old_input.controllers[0];

    	new_keyboard_controller^ = {};
    	new_keyboard_controller.is_connected = true;
    	new_input.dt_for_frame = monitor_seconds_per_frame;

    	for p, j in &new_keyboard_controller.buttons {
    		new_keyboard_controller.buttons[j].ended_down = old_keyboard_controller.buttons[j].ended_down
    	}

    	process_pending_messages(new_keyboard_controller)

    	one_mask:u8=1
    	process_keyboard_message(&new_input.mouse_buttons[0], b32( GetKeyState(VK_LBUTTON) &  i16(one_mask << 15)));
    	process_keyboard_message(&new_input.mouse_buttons[1], b32( GetKeyState(VK_MBUTTON) &  i16(one_mask << 15)));
    	process_keyboard_message(&new_input.mouse_buttons[2], b32( GetKeyState(VK_RBUTTON) &  i16(one_mask << 15)));
    	process_keyboard_message(&new_input.mouse_buttons[3], b32( GetKeyState(VK_XBUTTON1) & i16(one_mask << 15)));
    	process_keyboard_message(&new_input.mouse_buttons[4], b32( GetKeyState(VK_XBUTTON2) & i16(one_mask << 15)));

    	controller_state:XINPUT_STATE;	
    	for i in 0..<XUSER_MAX_COUNT {

		    //This is because out first controller is keyboard and we already read keyboard
		    our_controller_index:= u32(i+1) 
		    old_controller:= &old_input.controllers[our_controller_index]
		    new_controller:= &new_input.controllers[our_controller_index]

		    if XInputGetState(cast(u32)i, &controller_state)== ERROR_SUCCESS{

		    	using ButtonEnum

		    	new_controller.is_connected = true;
		    	new_controller.is_analog = old_controller.is_analog

		    	Pad := &controller_state.Gamepad;

		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[action_down],   XINPUT_GAMEPAD_A,              &new_controller.buttons[action_down]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[action_right],  XINPUT_GAMEPAD_B,              &new_controller.buttons[action_right]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[action_left],   XINPUT_GAMEPAD_X,              &new_controller.buttons[action_left]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[action_up],     XINPUT_GAMEPAD_Y,              &new_controller.buttons[action_up]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[left_shoulder], XINPUT_GAMEPAD_LEFT_SHOULDER,  &new_controller.buttons[left_shoulder]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[right_shoulder],XINPUT_GAMEPAD_RIGHT_SHOULDER, &new_controller.buttons[right_shoulder]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[start],         XINPUT_GAMEPAD_START,          &new_controller.buttons[start]);
		    	process_xinput_button(Pad.wButtons, &old_controller.buttons[back],          XINPUT_GAMEPAD_BACK,           &new_controller.buttons[back]);

		    	new_controller.stick_x = process_stick_value(Pad.sThumbLX, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE)
		    	new_controller.stick_y = process_stick_value(Pad.sThumbLY, XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE)

		    	if (new_controller.stick_x != 0.0) || (new_controller.stick_y != 0.0){
		    		new_controller.is_analog = true;
		    	}

		    	if b32(Pad.wButtons & XINPUT_GAMEPAD_DPAD_UP) {
		    		new_controller.stick_y = 1.0;
		    		new_controller.is_analog = false;
		    	} else if b32(Pad.wButtons & XINPUT_GAMEPAD_DPAD_DOWN) {
		    		new_controller.stick_y = -1.0;
		    		new_controller.is_analog = false;
		    	}
		    	if b32(Pad.wButtons & XINPUT_GAMEPAD_DPAD_LEFT) {
		    		new_controller.stick_x = -1.0;
		    		new_controller.is_analog = false;
		    	} else if b32(Pad.wButtons & XINPUT_GAMEPAD_DPAD_RIGHT) {
		    		new_controller.stick_x = 1.0;
		    		new_controller.is_analog = false;
		    	}

		    	Threshold:f32= 0.5;
		    	process_xinput_button((new_controller.stick_x > Threshold) ? 1 : 0, &new_controller.buttons[move_right], 1, &old_controller.buttons[move_right]);
		    	process_xinput_button((new_controller.stick_x < -Threshold) ? 1 : 0, &new_controller.buttons[move_left], 1, &old_controller.buttons[move_left]);
		    	process_xinput_button((new_controller.stick_y > Threshold) ? 1 : 0, &new_controller.buttons[move_up], 1, &old_controller.buttons[move_up]);
		    	process_xinput_button((new_controller.stick_y < -Threshold) ? 1 : 0, &new_controller.buttons[move_down], 1, &old_controller.buttons[move_down]);

		    }	
		}

		switch(platform.game_mode){
			case GameMode.game_mode_play:{
				render_game(&back_buffer, new_input);
			}	
			case GameMode.game_mode_menu:{
				render_menu(&back_buffer, new_input);
			}	
		}

		audio_wall_clock:=win32_get_wall_clock()

		//This means from the beggining of the frame to the time we calculate audio
		from_begin_to_audio_seconds := win32_get_seconds_elapsed(flip_wall_clock, audio_wall_clock)

		play_cursor, write_cursor : DWORD

		if SUCCEEDED(secondary_buff->GetCurrentPosition(&play_cursor, &write_cursor)) {

			if !sound_is_valid {
				sound_output.running_sample_index = write_cursor / sound_output.bytes_per_sample
				sound_is_valid = true
			}

			byte_to_lock:DWORD = (sound_output.running_sample_index * sound_output.bytes_per_sample) % sound_output.secondary_buffer_size

			seconds_left_until_flip :f32= monitor_seconds_per_frame - from_begin_to_audio_seconds

			bytes_until_flip := DWORD((seconds_left_until_flip / monitor_seconds_per_frame) * f32(sound_bytes_per_frame))

			frame_boundry_byte:= play_cursor + bytes_until_flip

			safe_write_cursor := write_cursor

			if safe_write_cursor < play_cursor {
				safe_write_cursor += sound_output.secondary_buffer_size
			}

			assert(safe_write_cursor >= play_cursor)
			safe_write_cursor += sound_output.safety_bytes


			target_cursor:DWORD=0

		    //Might not need this
		    audio_card_low_latency:= safe_write_cursor < frame_boundry_byte

		    if audio_card_low_latency {
		    	target_cursor = (frame_boundry_byte + u32(sound_bytes_per_frame))
		    }

		    target_cursor = write_cursor + u32(sound_bytes_per_frame) + sound_output.safety_bytes

		    target_cursor = target_cursor % sound_output.secondary_buffer_size

		    byte_to_write :DWORD= 0

		    if byte_to_lock > target_cursor{
				byte_to_write = (sound_output.secondary_buffer_size - byte_to_lock) //region 1
				byte_to_write += target_cursor //region 2
			}else{
				byte_to_write = target_cursor - byte_to_lock //region 1
			}

			platform.sound_buffer = {}
			platform.sound_buffer.samples_per_second = sound_output.samples_per_second
			platform.sound_buffer.sample_count = byte_to_write / sound_output.bytes_per_sample
			platform.sound_buffer.samples = samples

			game_get_sound_buffer(&platform.sound_buffer)

			fill_sound_buffer(&sound_output, byte_to_lock, byte_to_write, &platform.sound_buffer)
		}

		work_counter := win32_get_wall_clock()
		work_seconds_elapsed:= win32_get_seconds_elapsed(last_counter,work_counter); 

		seconds_elapsed_for_frame:f32 = work_seconds_elapsed;

		if seconds_elapsed_for_frame < monitor_seconds_per_frame {
			if sleep_is_granular {
				sleep_ms:= cast(DWORD)(1000.0 * (monitor_seconds_per_frame - seconds_elapsed_for_frame));
				if sleep_ms>0.0{
					Sleep(sleep_ms); 
				}
			} 

			test_seconds_elapsed_for_frame:= win32_get_seconds_elapsed(last_counter, win32_get_wall_clock());

			for seconds_elapsed_for_frame < monitor_seconds_per_frame{
				seconds_elapsed_for_frame = win32_get_seconds_elapsed(last_counter, win32_get_wall_clock());
			}
		}
		last_counter = win32_get_wall_clock();

		hdc = GetDC(window) 
		display_buffer_in_window(&back_buffer, hdc, 0, 0)
		ReleaseDC(window, hdc)

		flip_wall_clock = win32_get_wall_clock()

		new_input,
		old_input = old_input, new_input
	}
	return
}
