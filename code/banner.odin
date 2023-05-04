package main

BannerTile::struct{
    low_index: u32,
    is_empty : bool,
}

Banner::struct{
    banners:[5]BannerTile,
}

render_banners::proc(game_state: ^GameState){
    if !game_state.chunk_animation.is_active{
        using BmpAsset_Enum

        world := game_state.world
        mtop := world.meters_to_pixels
        chunk := get_world_chunk(world, game_state.curr_chunk)

        center   := platform.center

        banner_tile := get_bmp_asset(&platform.bmp_asset, asset_banner_tile)

        size, min :v2_f32;

        for btile,i in chunk.top_banner.banners{
            min.x = center.x + ((-2.0 + f32(i)) * f32(mtop)) - f32(mtop) * 0.5
            min.y = center.y + 4.0 * f32(mtop) - f32(mtop) * 0.5

            //use push_bitmap here?
            opengl_bitmap(banner_tile, min, v2_f32{f32(mtop), f32(mtop)})

            if !btile.is_empty{
                low := game_state.low_entities[btile.low_index]
                bmp := get_font(&platform.font_asset, rune(low.sim.texture.(string)[0]))

                opengl_bitmap(&bmp.image, min, v2_f32{f32(mtop), f32(mtop)})

            }
        }
    }
}