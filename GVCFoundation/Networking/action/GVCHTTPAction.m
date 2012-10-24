/*
 * GVCHTTPAction.m
 * 
 * Created by David Aspinall on 2012-10-23. 
 * Copyright (c) 2012 Global Village Consulting. All rights reserved.
 *
 */

#import "GVCHTTPAction.h"
#import "GVCMacros.h"
#import "GVCFunctions.h"
#import "GVCNetworking.h"

@interface GVCHTTPAction ()
@end

@implementation GVCHTTPAction

- (id)init
{
	self = [super init];
	if ( self != nil )
	{
		[self setAlerts:YES];
	}
	
    return self;
}

- (NSURL *)requestURL:(NSURL *)baseURL
{
	GVC_DBC_REQUIRE(
					GVC_DBC_FACT_NOT_NIL(baseURL);
					)
	
	// implementation
	
	GVC_DBC_ENSURE(
				   GVC_DBC_FACT_NOT_NIL(baseURL);
				   )

	return baseURL;
}

- (NSString *)localizedAlertMessage
{
	NSString *localizedValue = nil;
	GVC_DBC_REQUIRE(
					GVC_DBC_FACT_NOT_EMPTY([self alertMessageKey]);
					)
	
	// implementation
	localizedValue = GVC_LocalizedString([self alertMessageKey], [self alertMessageKey]);
	
	GVC_DBC_ENSURE(
				   GVC_DBC_FACT_NOT_EMPTY(localizedValue);
				   )

	return localizedValue;
}

- (NSString *)requestMethod
{
	return GVC_HTTP_METHOD_KEY_post;
}

- (NSDictionary *)requestHeaders
{
	return @{ GVC_HTTP_HEADER_KEY_user_agent : @"GVCFoundation" };
}


- (NSData *)requestMessageData
{
	return nil;
}

@end
