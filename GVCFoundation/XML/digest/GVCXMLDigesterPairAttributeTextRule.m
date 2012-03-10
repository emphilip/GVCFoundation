//
//  GVCXMLDigesterPairAttributeTextRule.m
//  GVCImmunization
//
//  Created by David Aspinall on 11-03-09.
//  Copyright 2011 Global Village Consulting Inc. All rights reserved.
//

#import "GVCXMLDigesterPairAttributeTextRule.h"

#import "GVCMacros.h"
#import "GVCFunctions.h"
#import "GVCXMLGenerator.h"
#import "GVCXMLDigester.h"
#import "NSString+GVCFoundation.h"
#import "GVCPair.h"

@implementation GVCXMLDigesterPairAttributeTextRule

@synthesize attributeName;
@synthesize pairKey;

- (id) init
{
	self = [super init];
	if (self != nil) 
	{
	}
	return self;
}

- (id) initWithPropertyName:(NSString *)pname andAttributeName:(NSString *)aname
{
	self = [super init];
	if (self != nil) 
	{
		[self setPropertyName:pname];
		[self setAttributeName:aname];
	}
	return self;
}

- (id) initWithPropertyName:(NSString *)pname
{
	return [self initWithAttributeName:pname];
}

- (id) initWithAttributeName:(NSString *)pname
{
	self = [super init];
	if (self != nil) 
	{
		[self setAttributeName:pname];
	}
	return self;
}

- (void) didStartElement:(NSString *)element attributes:(NSDictionary *)attributeDict
{
	[self setPairKey:[attributeDict objectForKey:attributeName]];
}

- (void) didEndElement:(NSString *)elementName
{
	GVC_ASSERT_VALID_STRING( pairKey );
	
    id object = [[self digester] peekNodeObject];
	GVCPair *pair = [[GVCPair alloc] initWith:pairKey and:(nodeText == nil ? [NSString gvc_EmptyString] : nodeText)];
	NSString *key = (gvc_IsEmpty(propertyName) ? elementName : propertyName);
	
    
	NSString *selectorName = GVC_SPRINTF( @"set%@:", [key gvc_StringWithCapitalizedFirstCharacter] );
	SEL selector = NSSelectorFromString(selectorName);
	if ( [object respondsToSelector:selector] == YES )
	{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
		[object performSelector:selector withObject:pair];
#pragma clang diagnostic pop
	}
	else
	{
		selectorName = GVC_SPRINTF( @"add%@:", [key gvc_StringWithCapitalizedFirstCharacter] );
		selector = NSSelectorFromString(selectorName);
		if ( [object respondsToSelector:selector] == YES )
		{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			[object performSelector:selector withObject:pair];
#pragma clang diagnostic pop
		}
		else
		{
			GVC_ASSERT( NO, @"Failed to set %@ attribute for %@ on object %@", key, pair, object );
		}
	}
}

- (void)writeConfiguration:(GVCXMLGenerator *)outputGenerator
{
	NSMutableDictionary *copyDict = [NSMutableDictionary dictionaryWithCapacity:2];
	[copyDict setObject:GVC_CLASSNAME(self) forKey:@"class_type"];
	[copyDict setObject:(gvc_IsEmpty(propertyName) == YES ? [NSString gvc_EmptyString] : propertyName) forKey:GVC_PROPERTY(propertyName)];
	[copyDict setObject:(gvc_IsEmpty(attributeName) == YES ? [NSString gvc_EmptyString] : attributeName) forKey:GVC_PROPERTY(attributeName)];
	
	[outputGenerator writeElement:@"rule" inNamespace:nil withAttributes:copyDict];
}


@end