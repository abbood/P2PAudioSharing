//
//  Game.m
//  Snap
//
//  Created by Ray Wenderlich on 5/25/12.
//  Copyright (c) 2012 Hollance. All rights reserved.
//

#import "Game.h"
#import "Packet.h"
#import "AudioFile.h"
#import "PacketSignInResponse.h"
#import "PacketMusic.h"
#import "PacketAudioBuffer.h"
#import "NSData+SnapAdditions.h"
#import "AudioStreamer.h"
#import "PacketServerReady.h"


typedef enum
{
	GameStateWaitingForSignIn,
	GameStateWaitingForReady,
	GameStateDealing,
	GameStatePlaying,
	GameStateGameOver,
	GameStateQuitting,
}
GameState;




@implementation Game
{
	GameState _state;

    
	GKSession *_session;
	NSString *_serverPeerID;
	NSString *_localPlayerName;
    
    NSMutableDictionary *_players;
}

@synthesize delegate = _delegate;
@synthesize isServer = _isServer;
@synthesize streamingPlayer;
@synthesize streamer;
@synthesize hostViewController;
@synthesize audioConverterSettings = _audioConverterSettings;

@synthesize queue;
@synthesize operations;
@synthesize operationsQueue;

@synthesize currentSong;





//@synthesize player;


- (id)init
{
	if ((self = [super init]))
	{
		_players = [NSMutableDictionary dictionaryWithCapacity:4];
	}
	return self;
}

- (void)dealloc
{
    NSLog(@"dealloc %@", self);
}

#pragma mark - Game Logic

- (void)startClientGameWithSession:(GKSession *)session playerName:(NSString *)name server:(NSString *)peerID
{
	self.isServer = NO;
    
	_session = session;
	_session.available = NO;
	_session.delegate = self;
	[_session setDataReceiveHandler:self withContext:nil];
    
	_serverPeerID = peerID;
	_localPlayerName = name;
    
	_state = GameStateWaitingForSignIn;
    
	[self.delegate gameWaitingForServerReady:self];
}

- (void)startServerGameWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients
{
	self.isServer = YES;
    
	_session = session;
	_session.available = NO;
	_session.delegate = self;
	[_session setDataReceiveHandler:self withContext:nil];
    
	_state = GameStateWaitingForSignIn;
    
	[self.delegate gameWaitingForClientsReady:self];
    
    // Create the Player object for the server.
	Player *player = [[Player alloc] init];
	player.name = name;
	player.peerID = _session.peerID;
	player.position = PlayerPositionBottom;
	[_players setObject:player forKey:player.peerID];
    
	// Add a Player object for each client.
	int index = 0;
	for (NSString *peerID in clients)
	{
		Player *player = [[Player alloc] init];
		player.peerID = peerID;
		[_players setObject:player forKey:player.peerID];
        
		if (index == 0)
			player.position = ([clients count] == 1) ? PlayerPositionTop : PlayerPositionLeft;
		else if (index == 1)
			player.position = PlayerPositionTop;
		else
			player.position = PlayerPositionRight;
        
		index++;
	}
    
    Packet *packet = [Packet packetWithType:PacketTypeSignInRequest];
	[self sendPacketToAllClients:packet];
    
}
- (void)broadcastServerMusicWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients
{
    self.isServer = YES;
    
	_session = session;
	_session.available = NO;
	_session.delegate = self;
	[_session setDataReceiveHandler:self withContext:nil];
    
    
    _state = GameStateWaitingForSignIn;
    
	[self.delegate gameWaitingForClientsReady:self];
    
    // Create the Player object for the server.
	Player *player = [[Player alloc] init];
	player.name = name;
	player.peerID = _session.peerID;
	player.position = PlayerPositionBottom;
	[_players setObject:player forKey:player.peerID];
    
	// Add a Player object for each client.
	int index = 0;
	for (NSString *peerID in clients)
	{
		Player *player = [[Player alloc] init];
		player.peerID = peerID;
		[_players setObject:player forKey:player.peerID];
        
		if (index == 0)
			player.position = ([clients count] == 1) ? PlayerPositionTop : PlayerPositionLeft;
		else if (index == 1)
			player.position = PlayerPositionTop;
		else
			player.position = PlayerPositionRight;
        
		index++;
	}

    
    
    
   
    CFURLRef     fileURL = (__bridge CFURLRef)[[NSBundle mainBundle] URLForResource:@"mozart" 
                                                                      withExtension:@"mp3"]; // file URL    
    AudioFile *audioFile = [[AudioFile alloc] initWithURL:fileURL];
    
   
    //no we start sending the data over    
    static const int maxBufferSize = 0x10000;   // limit maximum size to 64K
    static const int minBufferSize = 0x4000;    // limit minimum size to 16K
    NSUInteger bufferByteSize = maxBufferSize;
    UInt32 numPacketsToRead = 0;
    NSUInteger headerByteSize = 10;             // header takes 10 bytes
    
    
    if (maxBufferSize < audioFile.maxPacketSize) bufferByteSize = audioFile.maxPacketSize; 
    if (bufferByteSize < minBufferSize) bufferByteSize = minBufferSize;
    
    numPacketsToRead = bufferByteSize/audioFile.maxPacketSize;
    
    
  //  BOOL isVBR = ([audioFile audioFormatRef]->mBytesPerPacket == 0) ? YES : NO;
    BOOL isVBR = YES;
       
    
    AudioStreamPacketDescription    packetDescriptions[numPacketsToRead];    
    SInt64 inStartingPacket = 0;
    
    UInt32 counter = 10000;
    do {          
        counter--;
        
        void *myBuffer = [[[NSMutableData alloc] initWithCapacity:bufferByteSize] mutableBytes];
        

        NSMutableData *packetData = [[NSMutableData alloc] initWithCapacity:bufferByteSize + headerByteSize];
        UInt32 outNumBytes = 0;
        
        
        AudioFileReadPackets (
                                  audioFile.fileID,
                                  NO,
                                  &outNumBytes,
                                  isVBR ? packetDescriptions : 0,
                                  inStartingPacket,
                                  &numPacketsToRead,
                                  myBuffer
                              );
        

   /*   
        [packetData rw_appendInt32:'SNAP'];   // 0x534E4150
        [packetData rw_appendInt32:0];
        [packetData rw_appendInt16:PacketTypeMusic];*/
        
        NSData *NSpacketData = packetData;
        
       [packetData appendBytes:myBuffer length:outNumBytes];

        NSError *error;
        
       // NSLog(@"about to send out bytes");
        if (![session sendDataToAllPeers:NSpacketData withDataMode:GKSendDataReliable error:&error]) 
        {
            NSLog(@"Error sending data to clients: %@", error);
        }        
    } while (counter > 0);
    //while (numPacketsToRead < audioFile.packetsCount);    
}


- (void)quitGameWithReason:(QuitReason)reason
{
	_state = GameStateQuitting;
    
	[_session disconnectFromAllPeers];
	_session.delegate = nil;
	_session = nil;
    
	[self.delegate game:self didQuitWithReason:reason];
}

- (void)clientReceivedPacket:(Packet *)packet
{
    //we know the packet type will be music so we skip the chekcing part
    
    Packet * recievedPacket = packet;
    
	switch (recievedPacket.packetType)
	{
		case PacketTypeSignInRequest:
        {
			if (_state == GameStateWaitingForSignIn)
			{   
				_state = GameStateWaitingForReady;
                
				Packet *packet = [PacketSignInResponse packetWithPlayerName:_localPlayerName];
				[self sendPacketToServer:packet];
			}			
        }
        break;
            
        case PacketTypeMusic:
        {
            NSLog(@"we just recieved a music packet!!");
            NSData *packetBody = ((PacketMusic *)packet).musicData;
            UInt32 inDataByteSize = [packetBody length];
            const void *inData = [packetBody bytes];
            NSData * data = [NSData dataWithBytes:inData length:inDataByteSize];
            NSLog(@"thisis packet data %@",data);
            
            
            streamer->err = AudioFileStreamParseBytes(streamer->audioFileStream, inDataByteSize, inData, 0);
			if (streamer->err)
			{
                NSLog(@"we failed parsing the bytes!!");
                NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:streamer->err userInfo:nil];
                NSLog(@"error code: %ld", (long)error.code);
				[streamer failWithErrorCode:AS_FILE_STREAM_PARSE_BYTES_FAILED];
				return;
			}       
        }
        break;
            
            
        case PacketTypeAudioBuffer:
        {     
            NSData *packetBody = ((PacketAudioBuffer *)packet).audioBufferData;     
            NSData *packetDescriptionsData = ((PacketAudioBuffer *)packet).packetDescriptionsData;     
            
            NSString *packetID = ((PacketAudioBuffer *)packet).packetID;
            UInt32 packetNum= ((PacketAudioBuffer *)packet).packetNumber;
            UInt32 packetsBytesFill = ((PacketAudioBuffer *)packet).packetBytesFilled;
            UInt32 packetDescriptionsBytesFill = ((PacketAudioBuffer *)packet).packetDescriptionsBytesFilled;
            
            
            [self appendToPool:(NSString *)packetID
                    packetBody:[packetBody bytes]
        packetDescriptionsData:[packetDescriptionsData bytes]
                  packetNumber:packetNum
             packetBytesFilled:packetsBytesFill
 packetDescriptionsBytesFilled:packetDescriptionsBytesFill
             ];                        

        }
        break;    
            
        case PacketTypeServerReady:
        {
			if (_state == GameStateWaitingForReady)
			{
				_players = ((PacketServerReady *)packet).players;
                
                [self changeRelativePositionsOfPlayers];
                
                [self beginClientReception];
                
				Packet *packet = [Packet packetWithType:PacketTypeClientReady];
				[self sendPacketToServer:packet];
                
				
                
                
				NSLog(@"the players are: %@", _players);
			}
        }
		break;
            
		
        default:
			NSLog(@"Client received unexpected packet: %@", packet);
			break;
	}
       
    /*
    OSStatus result = player->StartQueue(false);
    if (result == noErr)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"playbackQueueResumed" object:self];    */
    
    
}

- (void)  appendToPool:(NSString *)packetID
            packetBody:(const void*)packetBody 
packetDescriptionsData:(const void *)packetDescriptionsData 
          packetNumber:(UInt32)packetNum
     packetBytesFilled:(UInt32)packetBytesFill
packetDescriptionsBytesFilled:(UInt32)packetDescriptionsBytesFill
{
    
   /* NSLog(@"APPENDTOPOOL.M");
    NSLog(@"this is packetID %@",packetID);
    NSLog(@"this is packetNumber %lu",packetNum);
    NSLog(@"this is packetBytesFilled %lu",packetBytesFill);
    NSLog(@"this is packetDescriptionbytesfilled %lu",packetDescriptionsBytesFill);
    NSLog(@"------------\n-------------");
    NSLog(@"this is packetBody %@", [NSData dataWithBytes:packetBody length:packetBytesFill]);
    NSLog(@"this is packetDescriptionsData %@", [NSData dataWithBytes:packetDescriptionsData length:packetDescriptionsBytesFill]);*/


    if (!currentSong || ![currentSong isEqual:packetID]) {        
        item = [audioPool.pool objectForKey:packetID];
        if (!item)
        {
            item = [audioPool createItemAndAddToPool:packetID];  
            NSLog(@"MAIN: we are creating a new item, not fetching it with url %@",item->cfURL);
            [self startReading]; 
        }         
    }
    currentSong = packetID;    

    UInt32 packetDescNumber = packetDescriptionsBytesFill/AUDIO_STREAM_PACK_DESC_SIZE;
    UInt32 ioNumPackets = packetDescNumber;
    
    
    
   // NSLog(@"before calling generatePacketDescriptionArrayPtr");
    
    [self generatePacketDescriptionArrayPtr:
           [NSData dataWithBytes:packetDescriptionsData 
                          length:packetDescriptionsBytesFill]
                          packetDescriptionNumber:packetDescNumber];
    
    //[self printPacketDescriptionContents:packetDescNumber];
    
    //NSLog(@"we are supposed to write %lu packets",ioNumPackets);
   // NSLog(@"this is packtBody data %@",[NSData dataWithBytes:packetBody length:packetBytesFill]);
    
   // NSLog(@"Main: we are writing %lu bytes to file with total %lld",bytesToWrite, item.startingByte);
   // NSLog(@"writing to file with string %@",item->cfURL);
    CheckError(AudioFileWritePackets(item.audioFileID,
                                     false,
                                     packetBytesFill,
                                     &packetDescriptionArray, 
                                     item.inStartingPacket,
                                     &ioNumPackets,
                                     packetBody),
               "could not write packets to file");
    
    item.inStartingPacket += ioNumPackets;
    totalBytesReceived += packetBytesFill;

    //NSLog(@"MAIN: we have written %lu bytes unto %lu packets, with a total of %lld packets and %lu bytes so far",packetBytesFill, ioNumPackets, item.inStartingPacket, totalBytesReceived);
    

}

-(void)generatePacketDescriptionArrayPtr:(NSData *)packetDescData
                                           packetDescriptionNumber:(UInt32)packetDescNumber
{
    //const AudioStreamPacketDescription * PacketDescriptionArrayPtr;

    //NSLog(@"this is packet description data inside generatePacketDescriptionArrayPtr %@", packetDescData);
          
    UInt32 offset = 0;
    
    for (int i=0; i < packetDescNumber; i++) {        
        packetDescriptionArray[i].mStartOffset = [packetDescData rw_int32AtOffset:offset];
        offset += sizeof(UInt32);
        packetDescriptionArray[i].mVariableFramesInPacket = [packetDescData rw_int32AtOffset:offset];
        offset += sizeof(UInt32);
        packetDescriptionArray[i].mDataByteSize = [packetDescData rw_int32AtOffset:offset];                
        offset += sizeof(UInt32);
    }                
            
    //[self printPacketDescriptionContents:packetDescNumber];
    
}

-(void)printPacketDescriptionContents:(UInt32)inNumberPackets
{
    
    for (int i = 0; i < inNumberPackets; ++i)
    {
        NSLog(@"\n----------------\n");
        NSLog(@"this is packetDescriptionArray[%d].mStartOffset: %lld", i,packetDescriptionArray[i].mStartOffset);
        NSLog(@"this is packetDescriptionArray[%d].mVariableFramesInPacket: %lu", i,packetDescriptionArray[i].mVariableFramesInPacket);
        NSLog(@"this is packetDescriptionArray[%d].mDataByteSize: %lu", i,packetDescriptionArray[i].mDataByteSize);
        NSLog(@"\n----------------\n");
    }
    
}

-(void)startReading
{
    NSLog(@"we are about to start reading");
    streamer = [[AudioStreamer alloc] initWithCFURL:item->cfURL];    
    
    [NSTimer scheduledTimerWithTimeInterval:5
                                     target:streamer
                                   selector:@selector(start)
                                   userInfo:NULL 
                                    repeats:NO];

}

- (void)serverReceivedPacket:(Packet *)packet fromPlayer:(Player *)player
{
	switch (packet.packetType)
	{
		case PacketTypeSignInResponse:
			if (_state == GameStateWaitingForSignIn)
			{
				player.name = ((PacketSignInResponse *)packet).playerName;
                                
				NSLog(@"server received sign in from client '%@'", player.name);
                
                if ([self receivedResponsesFromAllPlayers])
				{
					_state = GameStateWaitingForReady;
                    
					NSLog(@"all clients have signed in");
                    Packet *packet = [PacketServerReady packetWithPlayers:_players];
					[self sendPacketToAllClients:packet];
				}
                
			}
			break;
            
        case PacketTypeClientReady:
			if (_state == GameStateWaitingForReady && [self receivedResponsesFromAllPlayers])
			{
                NSLog(@"the clients are all ready!");
				[self beginServerBroadcast];
			}
			break;
            
		default:
			NSLog(@"Server received unexpected packet: %@", packet);
			break;
	}
}

- (Player *)playerWithPeerID:(NSString *)peerID
{
	return [_players objectForKey:peerID];
}

#pragma mark - GKSessionDelegate

- (void)session:(GKSession *)session peer:(NSString *)peerID didChangeState:(GKPeerConnectionState)state
{
#ifdef DEBUG
	NSLog(@"Game: peer %@ changed state %d", peerID, state);
#endif
}

- (void)session:(GKSession *)session didReceiveConnectionRequestFromPeer:(NSString *)peerID
{
#ifdef DEBUG
	NSLog(@"Game: connection request from peer %@", peerID);
#endif
    
	[session denyConnectionFromPeer:peerID];
}

- (void)session:(GKSession *)session connectionWithPeerFailed:(NSString *)peerID withError:(NSError *)error
{
#ifdef DEBUG
	NSLog(@"Game: connection with peer %@ failed %@", peerID, error);
#endif
    
	// Not used.
}

- (void)session:(GKSession *)session didFailWithError:(NSError *)error
{
#ifdef DEBUG
	NSLog(@"Game: session failed %@", error);
#endif
}

#pragma mark - GKSession Data Receive Handler

- (void)receiveData:(NSData *)data fromPeer:(NSString *)peerID inSession:(GKSession *)session context:(void *)context
{

#ifdef DEBUG
    //totalBytesReceived += [data length];
/*	NSLog(@"Game: receive data from peer: %@ length: %d with total %lu", data,  [data length],totalBytesReceived);
    NSLog(@"\n\n\n");            
    NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::");*/
#endif
    
	Packet *packet = [Packet packetWithData:data];
	if (packet == nil)
	{
		NSLog(@"Invalid packet: %@", data);
		return;
	}
    
	Player *player = [self playerWithPeerID:peerID];
    
    if (player != nil)
	{
		player.receivedResponse = YES;  // this is the new bit
	}    
    
	if (self.isServer)
		[self serverReceivedPacket:packet fromPlayer:player];
	else
		[self clientReceivedPacket:packet];
}

#pragma mark - Networking

- (void)sendPacketToAllClients:(Packet *)packet
{
    [_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop)
     {
         obj.receivedResponse = [_session.peerID isEqualToString:obj.peerID];
     }];
    
	GKSendDataMode dataMode = GKSendDataReliable;
	NSData *data = [packet data];
	NSError *error;
	if (![_session sendDataToAllPeers:data withDataMode:dataMode error:&error])
	{
		NSLog(@"Error sending data to clients: %@", error);
	}
}

- (void)sendPacketToServer:(Packet *)packet
{
	GKSendDataMode dataMode = GKSendDataReliable;
	NSData *data = [packet data];
	NSError *error;
	if (![_session sendData:data toPeers:[NSArray arrayWithObject:_serverPeerID] withDataMode:dataMode error:&error])
	{
		NSLog(@"Error sending data to server: %@", error);
	}
}

- (BOOL)receivedResponsesFromAllPlayers
{
	for (NSString *peerID in _players)
	{
		Player *player = [self playerWithPeerID:peerID];
		if (!player.receivedResponse)
			return NO;
	}
	return YES;
}

- (void)beginGame
{
	_state = GameStateDealing;
	[self.delegate gameDidBegin:self];
}

#pragma mark user data struct


static void CheckError (OSStatus error, const char *operation)
{
    if (error == noErr) return;
    
    char errorString [20];
    // see if it asppears to be a 4-char code
    *(UInt32 *) (errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint (errorString[2]) && 
        isprint(errorString[3]) && isprint (errorString[4])) {
        errorString[0] = errorString[5] = '\'';
        errorString[6] = '\0';
    } else 
        // no format ist as an integer
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "error: %s (%s)\n", operation, errorString);
    
    exit(1);
}



- (void)beginServerConversionAndBroadcast
{
    audioConverterSettings = [AudioConverterSettings initWithGame:self];
    //AVAssetReaderState readerState = {0};
    
    
    // the input setting is LPCM.. that's what we get from AVAssetReader    
    audioConverterSettings->inputFormat.mSampleRate = 44100.0;
    audioConverterSettings->inputFormat.mFormatID         = kAudioFormatLinearPCM;
    // kAudioFormatFlagIsFloat | kAudioFormatFlagsNativeIndian | kAudioFormatFlagIsPacked
    //audioConverterSettings->inputFormat.mFormatFlags      = kAudioFormatFlagsAudioUnitCanonical;       
    audioConverterSettings->inputFormat.mFormatFlags      = kLinearPCMFormatFlagIsBigEndian | 
                                                           kLinearPCMFormatFlagIsSignedInteger | 
                                                           kLinearPCMFormatFlagIsPacked; 
    
    audioConverterSettings->inputFormat.mBytesPerPacket   = 4;
    audioConverterSettings->inputFormat.mBytesPerFrame    = 4;    
    audioConverterSettings->inputFormat.mFramesPerPacket  = 1;
    audioConverterSettings->inputFormat.mBitsPerChannel   = 16;    
    audioConverterSettings->inputFormat.mChannelsPerFrame = 2;
    
    
    // initialize file selected by user
    MPMediaItemCollection	*userMediaItemCollection = hostViewController.userMediaItemCollection;
    NSArray *items = [userMediaItemCollection items];
    
    
    MPMediaItem *item = [items objectAtIndex:0];
    NSURL *assetURL = [item valueForProperty:MPMediaItemPropertyAssetURL];   
    NSNumber *playBackDuration = [item valueForProperty:MPMediaItemPropertyPlaybackDuration]; 
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    // get the total number of packets in file
    audioConverterSettings.inputFilePacketCount = 44100 * (int)playBackDuration;
    audioConverterSettings.inputFilePacketMaxSize = 32;
    
    
    // get the output format, we are interested in mp3, just for kicks
    
	// define the ouput format. AudioConverter requires that one of the data formats be LPCM
    audioConverterSettings->outputFormat.mSampleRate = 44100.0;
	audioConverterSettings->outputFormat.mFormatID = kAudioFormatLinearPCM;
    audioConverterSettings->outputFormat.mFormatFlags = kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	audioConverterSettings->outputFormat.mBytesPerPacket = 4;
	audioConverterSettings->outputFormat.mFramesPerPacket = 1;
	audioConverterSettings->outputFormat.mBytesPerFrame = 4;
	audioConverterSettings->outputFormat.mChannelsPerFrame = 2;
	audioConverterSettings->outputFormat.mBitsPerChannel = 16;

    //set up a file to receive conversion 
    CFURLRef outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,
                                                           CFSTR("output.aif"), 
                                                           kCFURLPOSIXPathStyle,
                                                           false);
    
    // FAILS HERE
    CheckError(AudioFileCreateWithURL(outputFileURL,
                                      kAudioFileAIFFType,
                                      &audioConverterSettings->outputFormat,
                                      kAudioFileFlags_EraseFile,
                                      &audioConverterSettings->outputFile),
               "AudioFilecreate with url failed");
    CFRelease(outputFileURL);
                                      
    
    NSLog(@" converting..");
    
    [self convert];
    
    AudioFileClose(audioConverterSettings.inputFile);
    AudioFileClose(audioConverterSettings->outputFile);
    return 0;
}
    


-(AudioStreamBasicDescription)extractTrackFormat:(AVAssetTrack *)track
{    
    CMFormatDescriptionRef formDesc = (__bridge CMFormatDescriptionRef)[[track formatDescriptions] objectAtIndex:0];
    const AudioStreamBasicDescription* asbdPointer = CMAudioFormatDescriptionGetStreamBasicDescription(formDesc);
    //because this is a pointer and not a struct we need to move the data into a struct so we can use it
    AudioStreamBasicDescription asbd = {0};
    memcpy(&asbd, asbdPointer, sizeof(asbd));
    //asbd now contains a basic description for the track
    return asbd;
}


- (void)beginServerBroadcast
{
    _state = GameStateDealing;   
      
    MPMediaItemCollection	*userMediaItemCollection = hostViewController.userMediaItemCollection;
    NSArray *items = [userMediaItemCollection items];

            
    MPMediaItem *item = [items objectAtIndex:0];
    //NSURL *assetURL = [item valueForProperty:MPMediaItemPropertyAssetURL];       
    NSString *assetID = [self generateID:item];
    
    NSURL *assetURL = [NSURL URLWithString:@"ipod-library://item/item.m4a?id=1053020204400037178"]; 
    AVURLAsset *songAsset = [AVURLAsset URLAssetWithURL:assetURL options:nil];
    
    
    
    // from AVAssetReader Class Reference: 
    // AVAssetReader is not intended for use with real-time sources,
    // and its performance is not guaranteed for real-time operations.
    NSError * error = nil;
    AVAssetReader* reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    
          
    // Set the read settings
    NSDictionary *audioReadSettings = [[NSMutableDictionary alloc] init];
    
    [audioReadSettings setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM]
                         forKey:AVFormatIDKey];
    [audioReadSettings setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    [audioReadSettings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsBigEndianKey];
    [audioReadSettings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsFloatKey];
    [audioReadSettings setValue:[NSNumber numberWithBool:NO] forKey:AVLinearPCMIsNonInterleaved];
    [audioReadSettings setValue:[NSNumber numberWithFloat:44100.0] forKey:AVSampleRateKey];
    
    AVAssetTrack* track = [songAsset.tracks objectAtIndex:0]; 
            
    AVAssetReaderTrackOutput* readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                                                        outputSettings:nil];
    
    
    [reader addOutput:readerOutput];
    [reader startReading];
    
    
    CMSampleBufferRef sample;
    packetNumber = 0;
    
  /*  AudioStreamPacketDescription packetDescriptionsOut;
    size_t packetDescriptionsSize = sizeof(packetDescriptionsOut);
    size_t packetDescriptionsSizeNeededOut;*/
    

    
        
    while ((sample = [readerOutput copyNextSampleBuffer])) 
    {                                          
                                                                                                                                       
        Boolean isBufferDataReady = CMSampleBufferDataIsReady(sample);
        
        if (!isBufferDataReady) {
            while (!isBufferDataReady) {
                NSLog(@"buffer is not ready!");
            }
        }
                                                                  
        CMBlockBufferRef CMBuffer = CMSampleBufferGetDataBuffer( sample );                                                         
        AudioBufferList audioBufferList;  
        
        CheckError(CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
                                                                                  sample,
                                                                                  NULL,
                                                                                  &audioBufferList,
                                                                                  sizeof(audioBufferList),
                                                                                  NULL,
                                                                                  NULL,
                                                                                  kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                                  &CMBuffer
                                                                                  ),
                   "could not read sample data");
        
        const AudioStreamPacketDescription   * inPacketDescriptions;
        size_t								 packetDescriptionsSizeOut;
        size_t inNumberPackets;
        
        CheckError(CMSampleBufferGetAudioStreamPacketDescriptionsPtr(sample, 
                                                                     &inPacketDescriptions,
                                                                     &packetDescriptionsSizeOut),
                   "could not read sample packet descriptions");
        
        inNumberPackets = packetDescriptionsSizeOut/sizeof(AudioStreamPacketDescription);
        
        AudioBuffer audioBuffer = audioBufferList.mBuffers[0];
        
        char * packet = (char*)malloc(MAX_PACKET_SIZE);
        char * packetDescriptions = (char*)malloc(MAX_PACKET_DESCRIPTIONS_SIZE);
        
        
        for (int i = 0; i < inNumberPackets; ++i)
        {
/*            
            NSLog(@"\n----------------\n");
            NSLog(@"this is packetDescriptionArray[%d].mStartOffset: %lld", i,inPacketDescriptions[i].mStartOffset);
            NSLog(@"this is packetDescriptionArray[%d].mVariableFramesInPacket: %lu", i,inPacketDescriptions[i].mVariableFramesInPacket);
            NSLog(@"this is packetDescriptionArray[%d].mDataByteSize: %lu", i,inPacketDescriptions[i].mDataByteSize);
            NSLog(@"\n----------------\n");
*/
            SInt64 dataOffset = inPacketDescriptions[i].mStartOffset;
			UInt32 dataSize   = inPacketDescriptions[i].mDataByteSize;            
            
            size_t packetSpaceRemaining;
            packetSpaceRemaining = MAX_PACKET_SIZE - packetBytesFilled - packetDescriptionsBytesFilled;
            
            // if the space remaining in the packet is not enough for the data contained in this packet
            // as specified by the packet description PLUS the corresponding packet descripton (that goes with it)
            // then just ship what we got
            if (packetSpaceRemaining < dataSize + AUDIO_STREAM_PACK_DESC_SIZE)
            {
                NSLog(@"oops! packetSpaceRemaining (%zu) is smaller than datasize (%lu) SO WE WILL SHIP PACKET [%d]: (abs number %lu)",
                      packetSpaceRemaining, dataSize, i, packetNumber);
                [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];                
            }

            NSLog(@"now we are about to copy data to packets");
            // copy data to the packet
            memcpy((char*)packet + packetBytesFilled, 
                   (const char*)(audioBuffer.mData + dataOffset), dataSize); 
            
            // we store packetDescription arrays unto a buffer, which will be 
            // appended to the end of the packet before we send it
            memcpy((char*)packetDescriptions + packetDescriptionsBytesFilled, 
                   [self encapsulatePacketDescription:inPacketDescriptions[i]
                                         mStartOffset:packetBytesFilled],
                                            AUDIO_STREAM_PACK_DESC_SIZE);  

            
            packetBytesFilled += dataSize;
            packetDescriptionsBytesFilled += AUDIO_STREAM_PACK_DESC_SIZE; 
            
          /*  NSData *packetData = [NSData dataWithBytes:packet length:packetBytesFilled];
            NSData *packetDescData = [NSData dataWithBytes:packetDescriptions length:packetDescriptionsBytesFilled];
            NSLog(@"this is packet data on packet [%d] (length: %lu) %@", i, dataSize, packetData);
            NSLog(@"this is packet Desc Data on packet [%d] (length: %lu) %@", i, packetDescriptionsBytesFilled, packetDescData);
            NSLog(@"-----------------\n-------------");    */
            
            // if this is the last packet, then ship it
            if (i == (inNumberPackets - 1)) {          
                NSLog(@"woooah! this is the last packet (%d).. so we will ship it!", i);
                [self encapsulateAndShipPacket:packet packetDescriptions:packetDescriptions packetID:assetID];                 
            }                  
        }                                                                                                     
    }     
}


-(NSString *)generateID:(MPMediaItem *)item
{
    // get the first 15 chars of the following properties
    NSString *artist = [[item valueForProperty:MPMediaItemPropertyArtist] substringWithRange:NSMakeRange(1,5)];
    NSString *album = [[item valueForProperty:MPMediaItemPropertyAlbumTitle] substringWithRange:NSMakeRange(1,5)];
    NSString *title = [[item valueForProperty:MPMediaItemPropertyTitle] substringWithRange:NSMakeRange(1,5)]; 
    
    //NSString *artist = [item valueForProperty:MPMediaItemPropertyArtist];
//    NSString *album = [item valueForProperty:MPMediaItemPropertyAlbumTitle];
  //  NSString *title = [item valueForProperty:MPMediaItemPropertyTitle]; 
    
    
    NSMutableString *ID = [[NSMutableString alloc] init];
    [ID appendString:artist]; [ID appendString:album]; [ID appendString:title];
    size_t strlen = [ID length];
    return ID;    
}


- (char *)encapsulatePacketDescription:(AudioStreamPacketDescription)inPacketDescription
                          mStartOffset:(SInt64)mStartOffset
{
    // take out 32bytes b/c for mStartOffset we are using a 32 bit integer, not 64
    char * packetDescription = (char *)malloc(AUDIO_STREAM_PACK_DESC_SIZE);
    
    appendInt32(packetDescription, (UInt32)mStartOffset, 0);
    appendInt32(packetDescription, inPacketDescription.mVariableFramesInPacket, 4);
    appendInt32(packetDescription, inPacketDescription.mDataByteSize,8);
    
    NSData *data = [NSData dataWithBytes:packetDescription length:AUDIO_STREAM_PACK_DESC_SIZE];
    
    return packetDescription;
}
                   
- (void)encapsulateAndShipPacket:(void *)source 
           packetDescriptions:(void *)packetDescriptions
                     packetID:(NSString *)packetID
{
    // package Packet
    char * headerPacket = (char *)malloc(MAX_PACKET_SIZE + AUDIO_BUFFER_PACKET_HEADER_SIZE + packetDescriptionsBytesFilled);
    
    appendInt32(headerPacket, 'SNAP', 0);    
    appendInt32(headerPacket,packetNumber, 4);    
    appendInt16(headerPacket,PacketTypeAudioBuffer, 8);   
    // we use this so that we can add int32s later
    UInt16 filler = 0x00;
    appendInt16(headerPacket,filler, 10);    
    appendInt32(headerPacket, packetBytesFilled, 12);
    appendInt32(headerPacket, packetDescriptionsBytesFilled, 16);    
    appendUTF8String(headerPacket, [packetID UTF8String], 20);
    
            
    int offset = AUDIO_BUFFER_PACKET_HEADER_SIZE;        
    memcpy((char *)(headerPacket + offset), (char *)source, packetBytesFilled);
    offset += packetBytesFilled;
    memcpy((char *)(headerPacket + offset), (char *)packetDescriptions, packetDescriptionsBytesFilled);    
    NSData *completePacket = [NSData dataWithBytes:headerPacket length: AUDIO_BUFFER_PACKET_HEADER_SIZE + packetBytesFilled + packetDescriptionsBytesFilled];        
    

    // ship packet
  /*  NSLog(@"HOST: this is the packet content after encapsulation of packet (abs number: %lu) %@",packetNumber, completePacket);
    NSLog(@"\n\n\n");            
    NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::");*/
    
    NSError *error;
    if (![_session sendDataToAllPeers:completePacket withDataMode:GKSendDataReliable error:&error])         {
        NSLog(@"Error sending data to clients: %@", error);
    }   
    
    NSLog(@"about to reset packees");
    // reset packet 
    packetBytesFilled = 0;
    packetDescriptionsBytesFilled = 0;
    
    packetNumber++;
    free(headerPacket);
    NSLog(@"just freed header packet");
    //  free(packet); free(packetDescriptions);

}


- (void)beginClientReception
{
    _state = GameStateDealing;
    [self setUpClientStreamer];
}

- (void)changeRelativePositionsOfPlayers
{
	NSAssert(!self.isServer, @"Must be client");
    
	Player *myPlayer = [self playerWithPeerID:_session.peerID];
	int diff = myPlayer.position;
	myPlayer.position = PlayerPositionBottom;
    
	[_players enumerateKeysAndObjectsUsingBlock:^(id key, Player *obj, BOOL *stop)
     {
         if (obj != myPlayer)
         {
             obj.position = (obj.position - diff) % 4;
         }
     }];
}

-(void)setUpClientStreamer
{
    if (!audioPool) {
        audioPool = [[AudioPool alloc] initPool];
    }    
}

//
// destroyStreamer
//
// Removes the streamer, the UI update timer and the change notification
//
- (void)destroyStreamer
{
	if (streamer)
	{
		[[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:ASStatusChangedNotification
         object:streamer];
	//	[progressUpdateTimer invalidate];
//		progressUpdateTimer = nil;
		
		[streamer stop];
//		[streamer release];
		streamer = nil;
	}
}


void appendInt32(void * source, int value, int offset )
{
    // ensure that data is transmitted in network byte order
    // which is big endian on 32 byte elements (ie long/int)

    
    value = htonl(value);
    memcpy((void *)(source + offset), &value, 4);            
}


// IMPORTANT NOTE: in order to read this later on, offset must be a mutliple of 4 = sizeof(Int32)
void appendVarInt32(void * source, int value, int offset, size_t * amount)
{
    *amount = numDigits(value);
    
    value = htons(value);
    memcpy((void *)(source + offset), &value, *amount* sizeof(int));   
}

void appendVarInt16(void * source, short value, int offset, size_t * amount)
{
    *amount = numDigits(value);
    
    value = htons(value);
    memcpy((void *)(source + offset), &value, *amount * sizeof(short));   
}

void appendInt16(void * source, short value, int offset)
{
    // ensure that data is transmitted in network byte order
    // which is big endian on 16 byte elements (ie short)
    value = htons(value);
    memcpy((void *)(source + offset), &value, 2);            
}

void appendUTF8String(void * source, const char *cString, int offset)
{
    memcpy((void *)(source + offset), cString, strlen(cString)+1);        
}

unsigned numDigits(const unsigned n) {
    if (n < 10) return 1;
    return 1 + numDigits(n / 10);
}



@end