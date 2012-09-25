//
//  Game.h
//  Snap
//
//  Created by Ray Wenderlich on 5/25/12.
//  Copyright (c) 2012 Hollance. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>


#import "Player.h"
//#import "AQPlayer.h"
#import "AudioStreamer.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "Packet.h"
#import "HostViewController.h"
#import "AudioConverterSettings.h"
#import "ConcurrentOp.h"


#define kBufferLength 1024
#define kAQMaxPacketDescs 50	// Number of packet descriptions in our array (formerly 512)


@class Game;




@protocol GameDelegate <NSObject>

- (void)game:(Game *)game didQuitWithReason:(QuitReason)reason;
- (void)gameWaitingForServerReady:(Game *)game;
- (void)gameWaitingForClientsReady:(Game *)game;
- (void)gameDidBegin:(Game *)game;

- (void)serverBroadcastDidBegin:(Game *)game;
- (void)clientReceptionDidBegin:(Game *)game;

@end

@interface Game : NSObject <GKSessionDelegate>
{
   	AudioStreamer *streamer;
    iPhoneStreamingPlayerViewController *streamingPlayer; 
    HostViewController *hostViewController;
    
    
    // we want the converter settings to be global for this class
    AudioConverterSettings *audioConverterSettings;
    UInt32 packetBytesFilled;
    UInt32 packetDescriptionsBytesFilled;
    UInt32 packetNumber;
    UInt32 packetsFilled;			// how many packets have been filled
    AudioItem * item; //the current item we are reading/writing from
    Boolean isAudioItemSet;
    
    AudioPool *audioPool;
    NSThread *fileReaderThread;
    NSURL * fileObj;
    
    TPCircularBuffer ringBuffer;
    
    UInt32 totalBytesReceived;
    UInt32 itemBeginningOffset;
    AudioStreamPacketDescription packetDescriptionArray[kAQMaxPacketDescs];	// packet descriptions for enqueuing audio
    
    

}

@property (nonatomic, weak) id <GameDelegate> delegate;
@property (nonatomic, assign) BOOL isServer;
@property (nonatomic) iPhoneStreamingPlayerViewController *streamingPlayer;
@property (nonatomic, strong) AudioStreamer *streamer;
@property (nonatomic) HostViewController *hostViewController;
@property (nonatomic,readwrite) AudioConverterSettings *audioConverterSettings;


// values for the run thread

@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSMutableSet *operations;
@property (nonatomic, assign) dispatch_queue_t operationsQueue;

@property (nonatomic, strong)  NSString * currentSong; 
@property (readwrite) AudioPool *audioPool;




//@property (readonly)			AQPlayer			*player;


- (void)startClientGameWithSession:(GKSession *)session playerName:(NSString *)name server:(NSString *)peerID;
- (void)startServerGameWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients;
- (void)broadcastServerMusicWithSession:(GKSession *)session playerName:(NSString *)name clients:(NSArray *)clients;

- (void)quitGameWithReason:(QuitReason)reason;
- (void)startFileReader:(id)key;
- (void)convert;
- (void)sendFreshAudioItemDataToReader;




void appendInt32(void * source, int value, int offset);
void appendInt16(void * source, short value, int offset);
unsigned numDigits(const unsigned n);
void appendUTF8String(void * source, const char *cString, int offset);

UInt32 getAudioFileSize(AudioFileID fileID);

OSStatus MyAudioConverterCallback(AudioConverterRef inAudioConverter,
                                  UInt32 *ioDataPacketCount,
                                  AudioBufferList *ioData,
                                  AudioStreamPacketDescription **outDataPacketDescription,
                                  void *inUserData);
OSStatus MyAudioConverterSECONDCallback(AudioConverterRef inAudioConverter,
                                        UInt32 *ioDataPacketCount,
                                        AudioBufferList *ioData,
                                        AudioStreamPacketDescription **outDataPacketDescription,
                                        void *inUserData);


@end
