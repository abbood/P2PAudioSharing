//
//  MyClass.m
//  Concurrent_NSOperation
//
//  Created by David Hoerl on 6/13/11.
//  Copyright 2011 David Hoerl. All rights reserved.
//


#import "ConcurrentOp.h"
#import "AudioPool.h"
#import "Packet.h"
#import "AudioFile.h"



#if ! __has_feature(objc_arc)
#error THIS CODE MUST BE COMPILED WITH ARC ENABLED!
#endif

@interface ConcurrentOp ()
@property (nonatomic, assign) BOOL executing, finished;
@property (nonatomic, assign) int loops;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, strong) NSURLConnection *connection;
@property (readwrite) UInt32 bytesFilled; 


//- (BOOL)setup;
- (void)timer:(NSTimer *)timer;

@end

@interface ConcurrentOp (NSURLConnectionDelegate)
@end

@implementation ConcurrentOp
@synthesize failInSetup;
@synthesize thread;
@synthesize executing, finished;
@synthesize loops;
@synthesize timer;
@synthesize connection;
@synthesize webData;
@synthesize bytesFilled;
@synthesize audioFile;

@synthesize audioFileURL;
@synthesize streamer;
@synthesize isSongChanged;


static const int maxBufferSize = 65536;   // limit maximum size to 64K
static const int minBufferSize = 16384;    // limit minimum size to 16K
// into the audio pool, just to save unnecessary 
// processing of breaking it into smaller chunks

- (BOOL)isConcurrent { return YES; }
- (BOOL)isExecuting { return executing; }
- (BOOL)isFinished { return finished; }

- (void)start
{
	if([self isCancelled]) {
		//NSLog(@"OP: cancelled before I even started!");
		[self willChangeValueForKey:@"isFinished"];
		finished = YES;
		[self didChangeValueForKey:@"isFinished"];
		return;
	}

	NSLog(@"OP: start");
	@autoreleasepool {

		loops = 1;	// testing
		self.thread	= [NSThread currentThread];	// do this first, to enable future messaging
        self.thread.name = @"runner";
		self.timer	= [NSTimer scheduledTimerWithTimeInterval:60*60 target:self selector:@selector(timer:) userInfo:nil repeats:NO];
			// makes runloop functional
		
    [self willChangeValueForKey:@"isExecuting"];
    executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
		
    BOOL allOK = [self setupClientStreamer];
        UInt32 offset = 0;
        NSURL * fileObj;

	//	if(allOK) {
			while(![self isFinished]) {
				assert([NSThread currentThread] == thread);
			//	NSLog(@"OP:main: sitting in loop (loops=%d)", loops);
				BOOL ret = [[NSRunLoop currentRunLoop] 
                            runMode:NSDefaultRunLoopMode 
                            beforeDate:[NSDate 
                                        dateWithTimeIntervalSinceNow:.25]];
				assert(ret && "first assert"); // could remove this - its here to convince myself all is well
                
                @synchronized(self) {
                   // NSLog(@"OP: request fresh audio item data");
                    //[self requestFreshAudioItemData];
                  //  NSLog(@"this is audio file url %@",audioFileURL);
                    if (audioFileURL == NULL) {
                        NSLog(@"OP: skipping loop");
                         continue;

                       
                    }
        
                 /*                  
                    //NSLog(@":::::: DATA THAT WILL BE SENT BY READER with bytesfiled %lu, data length %d, -> %@",bytesFilled, [audioItemLocalCopy length], audioItemLocalCopy);
                    //NSLog(@"\n\n\n");            
                    //NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::");
                    //NSLog(@"OP:runner while loop thread name BEFORE HANDING IT OVER TO STREAMER %@", [[NSThread currentThread] name]);*/
                    //[streamer handleContainerPackets:[audioItemData bytes]  numberBytes:[audioItemData length]];
                    
            

                    
                
                
                    
                 /*   id value;
                    NSError *error;
                    NSURL * fileObj = [NSURL fileURLWithPath:audioFileURL isDirectory:YES];
                    [fileObj getResourceValue:&value forKey:NSURLFileSizeKey error:&error];
                    
                    int size = [[[NSFileManager defaultManager] attributesOfItemAtPath:audioFileURL error:NULL] fileSize];
                    
                    NSLog(@"OP:::::::::this is the size of the file so far %d",size);
                    */
                    


                 /*   NSLog(@"this is what we got so far reading with length %lu and offset %lu %@", bufferByteSize, offset, buffer);
                    NSLog(@"\n\n\n\n");
                    NSLog(@":::::::::::::::::::::::::::::::::::::::::::::::::::::::");                    offset +=bufferByteSize;                    
                    void * theBuffer = malloc(bufferByteSize);
                  */

                    /*
                    NSLog(@"OP:reading audio packets in runloop with bufferByteSize is %lu, startint packet is %lu", bufferByteSize, offset);
                    AudioFileReadPackets (
                                          audioFile.fileID,
                                          NO,
                                          &bufferByteSize,
                                          0,            //not vbr
                                          offset,
                                          &numPacketsToRead,
                                          theBuffer
                                          );
                */

                    
                  
                                     
                    
                  

/*
                    numPacketsToRead = ([buffer length])/4;
                    NSLog(@"this is the data we are about to parse(starting packet: %lu, buffer byte size %lu with numPackets to read %lu) ",offset, bufferByteSize, numPacketsToRead);

                    streamer->err = AudioFileStreamParseBytes(streamer->audioFileStream, numPacketsToRead, [buffer bytes], 0);
                    if (streamer->err)
                    {
                        NSLog(@"we failed parsing the bytes!!");
                        NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:streamer->err userInfo:nil];
                        NSLog(@"error code: %ld", (long)error.code);
                        [streamer failWithErrorCode:AS_FILE_STREAM_PARSE_BYTES_FAILED];
                        return;
                    }*/
                    if (!fileObj) {
                        fileObj = [NSURL fileURLWithPath:audioFileURL isDirectory:YES];
                    }
                    
                    NSData * data = [NSData dataWithContentsOfURL:fileObj];
                    [streamer handleContainerPackets:(void *)([data bytes] + offset) numberBytes:bufferByteSize];                                        
                    offset += bufferByteSize;                    
                }
                
			}
			//NSLog(@"OP: finished - %@", [self isCancelled] ? @"was canceled" : @"normal completion");
	//	} else {
	//		[self finish];

	//		//NSLog(@"OP: finished - setup failed");
	//	}
		// Objects retaining us
		[timer invalidate], self.timer = nil;
		[connection cancel], self.connection = nil;
	}
}

- (BOOL)setupClientStreamer
{
    //NSLog(@"OP: setting up streamer");
    // TODO: no need to include this streamingplayer business.. just cut the createstreamer code part out and include it here.
    if (streamer)
	{
		return;
	}
    
	//[streamer destroyStreamer];
    streamer = [[AudioStreamer alloc] initStreamer];
    
    
    //
    // We're now ready to receive data
    //
    streamer.state = AS_WAITING_FOR_DATA;
    
    
    //
    // Set the audio session category so that we continue to play if the
    // iPhone/iPod auto-locks.
    //
    AudioSessionInitialize (
                            NULL,                          // 'NULL' to use the default (main) run loop
                            NULL,                          // 'NULL' to use the default run loop mode
                            NULL,  //ASAudioSessionInterruptionListenera reference to your interruption callback
                            (__bridge void*)streamer                       // data to pass to your interruption listener callback
                            );
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty (
                             kAudioSessionProperty_AudioCategory,
                             sizeof (sessionCategory),
                             &sessionCategory
                             );
    AudioSessionSetActive(true);
    
    
    
    
    // we know that it is PCM..  
    AudioStreamBasicDescription dataFormat;
    dataFormat.mSampleRate = 44100.0;
    dataFormat.mFormatID = kAudioFormatLinearPCM;
    dataFormat.mFormatFlags = kAudioFormatFlagsCanonical;
    dataFormat.mBytesPerPacket = 4;
    dataFormat.mFramesPerPacket = 1;
    dataFormat.mBytesPerFrame = 4;
    dataFormat.mChannelsPerFrame = 2;
    dataFormat.mBitsPerChannel = 16;
    
    // create the audio queue
    streamer->err = AudioQueueNewOutput(&dataFormat, MyAudioQueueOutputCallback, (__bridge void *)streamer, NULL, NULL, 0, &streamer->audioQueue);
    if (streamer->err)
    {
        [streamer failWithErrorCode:AS_AUDIO_QUEUE_CREATION_FAILED];
        return;
    }
    
    // allocate audio queue buffers
    for (unsigned int i = 0; i < kNumAQBufs; ++i)
    {
        streamer->err = AudioQueueAllocateBuffer(streamer->audioQueue, kAQBufSize, &streamer->audioQueueBuffer[i]);
        if (streamer->err)
        {
            [streamer failWithErrorCode:AS_AUDIO_QUEUE_BUFFER_ALLOCATION_FAILED];
            return;
        }
    }
    
     
/*
    // create an audio file stream parser (taken from streamer handleReadFromStream)
    if (!(streamer->audioFileStream))
    {
        streamer->err = AudioFileStreamOpen((__bridge void*)streamer, ASPropertyListenerProc, ASPacketsProc, 
                                            kAudioFileCAFType, &(streamer->audioFileStream));
        if (streamer->err)
        {
            [streamer failWithErrorCode:AS_FILE_STREAM_OPEN_FAILED];
        } 
    }
*/
     
    pthread_mutex_init(&streamer->queueBuffersMutex, NULL);
    pthread_cond_init(&streamer->queueBufferReadyCondition, NULL);
    
     

}



- (void)requestFreshAudioItemData
{
    // note: this method is used differently in the github concurrency example (it uses GDC dispatch instead)
   // [self performSelectorOnMainThread:@selector(sendFreshAudioItemDataToReader:) withObject:NULL waitUntilDone:NO];
    
   /* [[self class] performSelectorOnMainThread:@selector(postNotification:) 
                           withObject:[NSNotification
                                       notificationWithName:@"refreshData" 
                                       object:NULL]
                        waitUntilDone:NO];*/
    dispatch_async(dispatch_get_main_queue(), ^{ [[self class] postNotification:[NSNotification
                                                                         notificationWithName:@"refreshData" 
                                                                         object:NULL]]; } );
    
}

+ (void)postNotification:(NSNotification *)aNotification
{ 
    NSAssert([[NSThread currentThread] isEqual:[NSThread mainThread]],
             @"we want to use the main thread default center.");

    
    // http://stackoverflow.com/questions/9561604/is-dispatch-asyncdispatch-get-main-queue-necessary-in-this-case
    // ie we don't want to block the process until the recepients received notificaitons
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:aNotification];
    });
}



-(void)updateAudioFileURL:(NSString*)URL
{
    NSLog(@"OP: just got file url and it is %@",URL);
    [self setReadPropertiesFromAudioFile:URL];
}

-(void)setReadPropertiesFromAudioFile:(NSString *)URL
{
    const char *buffer;        
    buffer = [URL UTF8String];    
    CFURLRef fileURL = CFURLCreateFromFileSystemRepresentation(NULL, (UInt8*)buffer, strlen(buffer), false);        
    audioFile = [[AudioFile alloc] initWithURL:fileURL];
    
    bufferByteSize = maxBufferSize;
    numPacketsToRead = 0;
    
    
    
    if (maxBufferSize < audioFile.maxPacketSize) bufferByteSize = audioFile.maxPacketSize; 
    if (bufferByteSize < minBufferSize) bufferByteSize = minBufferSize;
    
    // bufferByteSize = 20;
    
    numPacketsToRead = bufferByteSize/audioFile.maxPacketSize;   
    audioFileURL = URL;
    
    bufferByteSize = 5000;
    
    
}











- (void)runConnection
{
	[connection performSelector:@selector(start) onThread:thread withObject:nil waitUntilDone:NO];
}

- (void)cancel
{
	[super cancel];
	
	if([self isExecuting]) {
		[self performSelector:@selector(finish) onThread:thread withObject:nil waitUntilDone:NO];
	}
}

- (void)finish
{
	// This order per the Concurrency Guide - some authors switch the didChangeValueForKey order.
	[self willChangeValueForKey:@"isFinished"];
	[self willChangeValueForKey:@"isExecuting"];

	executing = NO;
	finished = YES;

	[self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (void)timer:(NSTimer *)timer
{
}

- (void)dealloc
{
	//NSLog(@"OP: dealloc"); // didn't always see this message :-)

	[timer invalidate], timer = nil;
	[connection cancel], connection = nil;

}

@end

@implementation ConcurrentOp (NSURLConnectionDelegate)

- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response
{
	if([super isCancelled]) {
		[connection cancel];
		return;
	}

	NSUInteger responseLength = response.expectedContentLength == NSURLResponseUnknownLength ? 1024 : response.expectedContentLength;
#ifndef NDEBUG
	////NSLog(@"ConcurrentOp: response=%@ len=%lu", response, (unsigned long)responseLength);
#endif
	self.webData = [NSMutableData dataWithCapacity:responseLength]; 
}

- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data
{
#ifndef NDEBUG
	////NSLog(@"WEB SERVICE: got Data len=%lu", [data length]);
#endif
	if([super isCancelled]) {
		[connection cancel];
		return;
	}
	[webData appendData:data];
}

- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error
{
#ifndef NDEBUG
	//NSLog(@"ConcurrentOp: error: %@", [error description]);
#endif
	self.webData = nil;
    [connection cancel];

	[self finish];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)conn
{
	if([super isCancelled]) {
		[connection cancel];
		return;
	}
#ifndef NDEBUG
	////NSLog(@"ConcurrentOp FINISHED LOADING WITH Received Bytes: %u", [webData length]);
#endif
	// could use a NSXMLParser here too.
	[self finish];
}

@end
