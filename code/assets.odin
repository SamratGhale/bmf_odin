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
	pixels 			   :[dynamic]u8
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

parse_png_to_bmp::proc(filename:string, bitmap:^LoadedBitmap){

	image, err := img.load_from_file(filename)

	if err == nil{
		bitmap.width      = i32(image.width)
		bitmap.height     = i32(image.height)
		bitmap.pitch      = i32(image.depth * image.width)
		bitmap.total_size = i64(bitmap.width * bitmap.height)
		bitmap.pixels     = image.pixels.buf

		/*
		bitmap.pixels      = cast(^u8)push_size_(&platform.arena, bitmap.total_size)

		mem.copy(rawptr(bitmap.pixels), cast(rawptr)&image.pixels.buf[0], int(bitmap.total_size))
		*/
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


AssetSound_Enum::enum{
	asset_sound_background,
	asset_sound_jump,
}


