//
//  GVCXMLDigestCreateObjectRule.m
//  HL7ParseTest
//
//  Created by David Aspinall on 11-02-04.
//  Copyright 2011 Global Village Consulting Inc. All rights reserved.
//

#import "GVCXMLDigesterCreateObjectRule.h"

#import "GVCMacros.h"
#import "GVCXMLGenerator.h"
#import "GVCXMLDigester.h"

@implementation GVCXMLDigesterCreateObjectRule

@synthesize classname;
@synthesize classnameFromAttribute;

- (id)initForClassname:(NSString *)clazz orFromAttribute:(NSString *)attrib
{
	self = [super init];
	if ( self != nil )
	{
		[self setClassname:clazz];
		[self setClassnameFromAttribute:attrib];
	}
	return self;
}

- (id)initForClassname:(NSString *)clazz
{
	return [self initForClassname:clazz orFromAttribute:nil];
}

- (id)initForClassnameFromAttribute:(NSString *)attrib
{
	return [self initForClassname:nil orFromAttribute:attrib];
}

- (id)init
{
	return [self initForClassname:nil orFromAttribute:nil];
}

- (void) didStartElement: (NSString*) elementName attributes: (NSDictionary*) attributeDict
{
	NSString *realClassName = [self classname];
	if (classnameFromAttribute != nil)
	{
		NSString *value = [attributeDict objectForKey:classnameFromAttribute];
		if (value != nil) 
		{
			realClassName = value;
		}
	}

	Class nodeClass = NSClassFromString(realClassName);
	GVC_ASSERT(nodeClass != nil, @"Failed to map class name '%@' to object", realClassName);
	[[self digester] pushNodeObject:[[nodeClass alloc] init]];
}

- (void) didEndElement: (NSString*) elementName
{
    GVCXMLDigester *dgst = [self digester];
	[dgst popNodeObject];
}

- (void)writeConfiguration:(GVCXMLGenerator *)outputGenerator
{
	NSMutableDictionary *copyDict = [NSMutableDictionary dictionaryWithCapacity:2];
	[copyDict setObject:GVC_CLASSNAME(self) forKey:@"class_type"];
	
	if ( classnameFromAttribute != nil )
	{
		[copyDict setObject:classnameFromAttribute forKey:GVC_PROPERTY(classnameFromAttribute)];
	}
	else if ( classname != nil )
	{
		[copyDict setObject:classname forKey:GVC_PROPERTY(classname)];
	}
	
	[outputGenerator writeElement:@"rule" inNamespace:nil withAttributes:copyDict];
}

@end