//
//  PacketAudioBuffer.m
//  Snap
//
//  Created by Abdullah Bakhach on 8/28/12.
//  Copyright (c) 2012 Hollance. All rights reserved.
//
#import "PacketAudioBuffer.h"
#import "NSData+SnapAdditions.h"

@implementation PacketAudioBuffer

@synthesize audioBufferData = _audioBufferData;
@synthesize packetID = _packetID;
@synthesize packetNumber = _packetNumber;
@synthesize packetBytesFilled = _packetBytesFilled;
@synthesize packetDescriptionsBytesFilled =_packetDescriptionsBytesFilled;
@synthesize packetDescriptionsData = _packetDescriptionsData;


+ (id)packetWithData:(NSData *)data
{
    size_t count;
    int packetNumber = [data rw_int32AtOffset:4];
    int packetBytesFilled = [data rw_int32AtOffset:12];
    int packetDescriptionsBytesFilled = [data rw_int32AtOffset:16];    
    NSString *packetID = [data rw_stringAtOffset:20 bytesRead:&count];         

   
    /*
    NSLog(@"------------\n-------------");
    
    NSLog(@"PACKETAUDIOBUFFER.M");
    NSLog(@"this is packetWholeBody %@", data);
    NSLog(@"---\n---");
    
    NSLog(@"this is packetNumber %d",packetNumber);
    NSLog(@"this is packetBytesFilled %d",packetBytesFilled);
    NSLog(@"this is packetDescriptionbytesfilled %d",packetDescriptionsBytesFilled);
    
    NSLog(@"this is packetID %@",packetID);
    */
    
    
    int offset = AUDIO_BUFFER_PACKET_HEADER_SIZE;
    
    NSData* audioBufferData = [NSData dataWithBytes:(char *)([data bytes] + offset) 
                                             length:packetBytesFilled];
   // NSLog(@"this is audio buffer data (reading from offset %d) %@", offset, audioBufferData);
    offset += packetBytesFilled;
    NSData *packetDescriptionsData = [NSData dataWithBytes:(char *)([data bytes] + offset) length:packetDescriptionsBytesFilled];
    
    

    /*
    
    NSLog(@"this is packetDescriptionsData (reading from offset %d) %@", offset, packetDescriptionsData);

    
    
    NSLog(@"------------\n-------------");
    */
    
    
    
    
	return [[self class] packetWithAudioBuffer:audioBufferData
     packetDescriptionsData:(NSData *)packetDescriptionsData
                                      packetID:packetID
                                  packetNumber:packetNumber
                             packetBytesFilled:packetBytesFilled
                 packetDescriptionsBytesFilled:packetDescriptionsBytesFilled
            ];
}

+ (id)packetWithAudioBuffer:(NSData *)audioBufferData 
     packetDescriptionsData:(NSData *)packetDescriptionsData
                   packetID:(NSString *)packetID                               
               packetNumber:(UInt32)packetNumber
          packetBytesFilled:(UInt32)packetBytesFilled
packetDescriptionsBytesFilled:(UInt32)packetDescriptionsBytesFilled
{
	return [[[self class] alloc] initWithAudioBufferData:audioBufferData
                                  packetDescriptionsData:(NSData *)packetDescriptionsData
                                                packetID:packetID
                                            packetNumber:packetNumber
                                       packetBytesFilled:packetBytesFilled
                           packetDescriptionsBytesFilled:packetDescriptionsBytesFilled
            ];
}

- (id)initWithAudioBufferData:(NSData *)audioBufferData 
     packetDescriptionsData:(NSData *)packetDescriptionsData
                     packetID:(NSString *)packetID
                 packetNumber:(UInt32)packetNumber
            packetBytesFilled:(UInt32)packetBytesFilled
packetDescriptionsBytesFilled:(UInt32)packetDescriptionsBytesFilled
{
	if ((self = [super initWithType:PacketTypeAudioBuffer]))
	{
		self.audioBufferData = audioBufferData;
        self.packetID = packetID;
        self.packetNumber = packetNumber;
        self.packetBytesFilled = packetBytesFilled;
        self.packetDescriptionsBytesFilled = packetDescriptionsBytesFilled;
        self.packetDescriptionsData = packetDescriptionsData;
	}
	return self;
}

- (void)addPayloadToData:(NSMutableData *)data
{
	[data rw_appendString:self.audioBufferData];
}



@end
