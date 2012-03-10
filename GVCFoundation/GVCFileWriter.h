/*
 * GVCFileWriter.h
 * 
 * Created by David Aspinall on 11-11-25. 
 * Copyright (c) 2011 Global Village Consulting. All rights reserved.
 *
 */

#import <Foundation/Foundation.h>

#import "GVCReaderWriter.h"

@interface GVCFileWriter : NSObject <GVCWriter, NSStreamDelegate>
{
	GVCWriterStatus writerStatus;
	NSStringEncoding stringEncoding;
	
	NSOutputStream *fileStream;
	NSString *filename;
}

+ (GVCFileWriter *)writerForFilename:(NSString *)file;
+ (GVCFileWriter *)writerForFilename:(NSString *)file encoding:(NSStringEncoding)encoding;

- (id)init;
- (id)initForFilename:(NSString *)file;
- (id)initForFilename:(NSString *)file encoding:(NSStringEncoding)encoding;

@property (retain, nonatomic) NSString *filename;
@property (retain, nonatomic) NSOutputStream *fileStream;

@end