//
//  GVCXMLDigester.h
//
//  Created by David Aspinall on 11-02-04.
//  Copyright 2011 Global Village Consulting Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "GVCXMLParserDelegate.h"

@class GVCXMLDigesterRule;
@class GVCXMLDigesterRuleManager;
@class GVCXMLDigesterRuleset;
@class GVCXMLGenerator;

/* 
	GVCXMLDigester is designed as a cocoa version of the Apache Commons Digester.  It is not designed to be a method for method transcription, but rather a version in Cocoa that follows Obj-c conventions.
	* it can now be reset and reused on multiple documents.  This saves having to reload the digest spec documents.
 */
@interface GVCXMLDigester : GVCXMLParserDelegate

@property (strong, nonatomic) NSMutableDictionary *digest;
@property (strong, nonatomic) GVCXMLDigesterRuleManager *digestRules;
@property (strong, nonatomic) GVCStack *currentNodeStack;

+ (GVCXMLDigester *)digesterWithConfiguration:(NSString *)path;

- (id)digestValueForPath:(NSString *)key;

- (void)addRule:(GVCXMLDigesterRule *)rule forPattern:(NSString *)pattern;
- (void)addRuleset:(GVCXMLDigesterRuleset *)set;

- (void)pushNodeObject:(id)anObject;
- (id)popNodeObject;

- (id)peekNodeObject;
- (id)peekNodeObjectAtIndex:(NSUInteger)idx;

- (NSString *)elementPath;

- (void)writeConfiguration:(GVCXMLGenerator *)outputGenerator;
@end
