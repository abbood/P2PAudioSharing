//
//  Packet.h
//  Snap
//
//  Created by Ray Wenderlich on 5/25/12.
//  Copyright (c) 2012 Hollance. All rights reserved.
//

const size_t PACKET_HEADER_SIZE;
const size_t AUDIO_BUFFER_PACKET_HEADER_SIZE;
const size_t AUDIO_BUFFER_DATA_BYTE_SIZE_OFFSET;
const size_t AUDIO_BUFFER_NUMBER_OF_CHANNELS_OFFSET;
const size_t MAX_PACKET_SIZE;
const size_t PACKET_INFO_SIZE;
const size_t MAX_PACKET_DESCRIPTIONS_SIZE;
const size_t AUDIO_STREAM_PACK_DESC_SIZE;

typedef enum
{
	PacketTypeSignInRequest = 0x64,    // server to client
	PacketTypeSignInResponse,          // client to server
    
	PacketTypeServerReady,             // server to client
	PacketTypeClientReady,             // client to server
    
	PacketTypeDealCards,               // server to client
	PacketTypeClientDealtCards,        // client to server
    
	PacketTypeActivatePlayer,          // server to client
	PacketTypeClientTurnedCard,        // client to server
    
	PacketTypePlayerShouldSnap,        // client to server
	PacketTypePlayerCalledSnap,        // server to client
    
	PacketTypeOtherClientQuit,         // server to client
	PacketTypeServerQuit,              // server to client
	PacketTypeClientQuit,              // client to server
    
    PacketTypeMusic,                    // music file we are about to send
    PacketTypeAudioBuffer
}
PacketType;

@interface Packet : NSObject


@property (nonatomic, assign) PacketType packetType;
@property (nonatomic, copy) NSData * bodyData;

+ (id)packetWithType:(PacketType)packetType;
- (id)initWithType:(PacketType)packetType;
+ (id)packetWithData:(NSData *)data;

- (NSData *)getBodyData;
- (NSData *)data;

@end
