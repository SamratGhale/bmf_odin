package main

import img "core:image/png"
import mem "core:mem"

LoadedBitmap::struct #packed{
	width              :i32,
	height             :i32,
	pitch              :i32,
	total_size         :i64,
	align_percent      :v2_f32,
	width_over_height  :f32,
	gl_context         :OpenglContext,
	pixels 			       :^u8
}

BmpAsset_Enum::enum{
	asset_background,
	asset_player_left,
	asset_player_right,
	asset_player_back,
	asset_wall,
	asset_grass,
	asset_banner_tile,
	asset_fire_torch,
	asset_floor,
}

BmpAsset::struct{
	bitmaps		:[len(BmpAsset_Enum)]LoadedBitmap	
}


swap_rb::proc(c :u32)->u32{

	result := ((c & 0xFF00FF00) | ((c >> 16) & 0xFF) | ((c & 0xFF) << 16));
	return result;
}

write_image_top_down_rgba::proc(bitmap:^LoadedBitmap){
	height := bitmap.height
	width  := bitmap.width
	mid_point_y         := ((height + 1)/2)
	row_0 := cast(^u32)rawptr(bitmap.pixels)
	row_1 := cast(^u32)mem.ptr_offset(row_0, (height - 1) * width)
	for y in 0..<mid_point_y{
		pix_0:=row_0
		pix_1:=row_1

		for x in 0..<width{
			c0:u32 = (pix_0^)
			c1:u32 = (pix_1^)

			pix_0^ = c1
			pix_1^ = c0

			pix_0 = mem.ptr_offset(pix_0, 1)
			pix_1 = mem.ptr_offset(pix_1, 1)
		}
		row_0 = mem.ptr_offset(row_0, width)
		row_1 =mem.ptr_offset(row_1, -width)
	}
}

parse_png_to_bmp::proc(filename:string, bitmap:^LoadedBitmap){

	image, err := img.load_from_file(filename)
	if err == nil{
		bitmap.width      = i32(image.width)
		bitmap.height     = i32(image.height)
		bitmap.pitch      = i32(image.depth * image.width)
		bitmap.total_size = i64(bitmap.width * bitmap.height)
		bitmap.pixels     = cast(^u8)rawptr(&image.pixels.buf[0])
		write_image_top_down_rgba(bitmap)
	}
}

get_bmp_asset::proc(asset:^BmpAsset, id:BmpAsset_Enum)->^LoadedBitmap{
	bitmap := &asset.bitmaps[id]

	if bitmap.pixels == nil{
		switch id{
			case .asset_background:
			parse_png_to_bmp("../data/green_background.png", bitmap)
			case .asset_player_left:
			parse_png_to_bmp("../data/player/left.png", bitmap)
			case .asset_player_right:
			parse_png_to_bmp("../data/player/right.png", bitmap)
			case .asset_player_back:
			parse_png_to_bmp("../data/player/back.png", bitmap)
			case .asset_wall:
			parse_png_to_bmp("../data/tex_wall_smool.png", bitmap)
			case .asset_grass:
			parse_png_to_bmp("../data/grass.png", bitmap)
			case .asset_banner_tile:
			parse_png_to_bmp("../data/border.png", bitmap)
			case .asset_fire_torch:
			parse_png_to_bmp("../data/torch.png", bitmap)
			case .asset_floor:
			parse_png_to_bmp("../data/tex_floor.png", bitmap)
		}
	}
	return bitmap
}

get_font::proc(font_asset:^Font, c:rune )->^Glyph{
	for glyph in &font_asset.glyphs{
		if glyph.code_point == c{
			return &glyph
		}
	}
	return nil
}



get_sound_asset::proc(asset: ^SoundAsset, id:AssetSound_Enum)-> ^LoadedSound{
	assert(asset != nil)
	sound := &asset.sounds[id]

	if sound.sample_count == 0{
		using AssetSound_Enum
		switch(id){
			case asset_sound_background:{
				sound^ = load_wav("../data/sounds/music_test.wav")
			}

			case asset_sound_jump:{
				sound^ = load_wav("../data/sounds/bloop_00.wav")
			}
		}
	}
	return sound
}












