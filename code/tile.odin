package main


append_tile::proc(chunk:^WorldChunk, new_tile:^Tile, arena:^MemoryArena){
  add_flag(&new_tile.flags, u32(TileFlags.tile_path))

  if chunk.tile_path == nil{
    chunk.tile_path = push_struct(arena, TileNode)
    chunk.tile_path.tile = new_tile
  }else{
    curr := chunk.tile_path 
    for curr.next != nil{
      curr = curr.next
    }
    curr.next = push_struct(arena, TileNode)
    curr.next.tile = new_tile
    curr.next.next = nil
  }
}


get_last_tile::proc(head:^TileNode)->^Tile{

  curr := head; 
  for curr.next != nil{
    curr = curr.next;
  }
  return curr.tile;
}

remove_last_tile::proc(head:^TileNode){

	using TileFlags
	curr := head; 
	if head.next != nil{

		if head.next.next == nil{
			clear_flag(&head.next.tile.flags, u32(tile_path));
			head.next = nil;
		}else{
			for curr.next.next != nil{ curr = curr.next; }
			clear_flag(&curr.next.tile.flags, u32(tile_path));
			curr.next = nil;
		}
	}
}

get_path_length::proc(head:^TileNode)->i32{
  count:i32 = 1
  curr := head
  if(head.next == nil){
    return 1
  }else{
    for (curr.next != nil){
      count += 1
      curr = curr.next
    }
  }
  return count;
}

get_index_path::proc(head:^TileNode , index:i32)->^Tile{
  if(get_path_length(head) < index){
    return nil; 
  }
  curr := head;
  for i in 1..<index{
    curr = curr.next;
  }
  return curr.tile;
}