package main
import "core:os"
import "core:mem"

offset::mem.ptr_offset


WAVE_header :: struct #packed{
	RIFFID   : u32,
	size     : u32,
	WAVED    : u32,
};

RIFF_CODE::proc(val: string)-> u32{

	result : u32 = (u32(val[0]) << 0) | (u32(val[1]) << 8) | (u32(val[2]) << 16) | (u32(val[3]) << 24)
	return result
}

WAVE_ChunkID_fmt  := RIFF_CODE("fmt ")
WAVE_ChunkID_data := RIFF_CODE("data")
WAVE_ChunkID_RIFF := RIFF_CODE("RIFF")
WAVE_ChunkID_WAVE := RIFF_CODE("WAVE")

WAVE_chunk:: struct #packed{
	ID    : u32,
	size  : u32,
}

WAVE_fmt :: struct #packed {
	wFormatTag           : u16,
	nChannels            : u16,
	nSamplesPerSec       : u32,
	nAvgBytesPerSec      : u32,
	nBlockAlign          : u16,
	wBitsPerSample       : u16,
	cbSize               : u16,
	wValidBitsPerSample  : u16,
	dwChannelMask        : u32,
	SubFormat            : [16]u8,
}

RiffIterator:: struct{
	at    :^u8,
	stop  :^u8,
}

parse_chunk_at::proc(at: rawptr, stop: rawptr)->RiffIterator{
	iter: RiffIterator = {}
	iter.at   = cast(^u8)at;
	iter.stop = cast(^u8)stop;
	return iter;
}

next_chunk::proc(iter: RiffIterator)-> RiffIterator{
	iter := iter
	chunk := cast(^WAVE_chunk)iter.at;
	size : u32= (chunk.size + 1) & u32(~u32(1));
	iter.at = offset(iter.at , size_of(WAVE_chunk) + size)
	return iter;
}

is_valid::proc(iter: RiffIterator)-> (result: b32){
	result = b32(iter.at < iter.stop);
	return result;
}

get_chunk_data::proc(iter: RiffIterator)-> (result: rawptr){
	result =offset(iter.at, size_of(WAVE_chunk));
	return result;
}

get_type::proc(iter: RiffIterator)->(result: u32){
	chunk  := cast(^WAVE_chunk)iter.at;
	result = chunk.ID;
	return result;
}

get_chunk_data_size::proc(iter: RiffIterator)->u32{
	chunk:^WAVE_chunk = cast(^WAVE_chunk)iter.at;
	res: = u32(chunk.size);
	return res;
}


load_wav::proc(file_name: string)->LoadedSound{

	result:LoadedSound= {};

    //content = os.read_entire_file(file_name);
    content, _ := os.read_entire_file_from_filename(file_name)

    if(content != nil){

    	header := cast(^WAVE_header)rawptr(raw_data(content));

    	assert(header.RIFFID == WAVE_ChunkID_RIFF)
    	assert(header.WAVED  == WAVE_ChunkID_WAVE)

    	channel_count    : u32= 0
    	sample_data_size : u32= 0
    	sample_data      : ^i16

    	iter := parse_chunk_at(offset(header ,1), offset(cast(^u8)(header), size_of(WAVE_header) + header.size -4))

    	for(is_valid(iter)){

    		switch(get_type(iter)){

    			case WAVE_ChunkID_fmt:{
    				fmt:^WAVE_fmt = cast(^WAVE_fmt)get_chunk_data(iter)
    				assert(fmt.wFormatTag == 1)
    				assert(fmt.nSamplesPerSec == 48000)
    				assert(fmt.wBitsPerSample == 16)
    				assert(fmt.nBlockAlign == (size_of(i16) * fmt.nChannels))
    				channel_count = u32(fmt.nChannels)
    			}
    			case WAVE_ChunkID_data:{
    				sample_data = cast(^i16)get_chunk_data(iter)
    				sample_data_size = get_chunk_data_size(iter)
    			}
    		}
    		iter = next_chunk(iter)
    	}
    	assert(channel_count != 0 && sample_data != nil);

    	result.channel_count = channel_count;
    	result.sample_count = sample_data_size / (channel_count* size_of(i16));

    	if(channel_count == 1){
    		result.samples[0] = sample_data;
    		result.samples[1] = nil;
    	}else if(channel_count == 2){
    		result.samples[0] = sample_data;
    		result.samples[1] = offset(sample_data ,result.sample_count);

    		for sample_index :u32= 0; sample_index < result.sample_count; sample_index +=1{

    			source :i16 = offset(sample_data, 2*sample_index)^
    			offset(sample_data, 2*sample_index)^= offset(sample_data, sample_index)^;
    			offset(sample_data, sample_index)^  = source;

    		}
    	}else{
    		assert(1==0);
    	}
    	result.channel_count = 1;
    }
    return result;
}












