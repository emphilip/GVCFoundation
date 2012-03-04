/*
 * NSBundle+GVCFoundation.m
 * 
 * Created by David Aspinall on 11-10-02. 
 * Copyright (c) 2011 Global Village Consulting Inc. All rights reserved.
 *
 */

#import "NSBundle+GVCFoundation.h"

@implementation NSBundle (GVCFoundation)

+ (NSString *)gvc_MainBundleName
{
	return [[NSBundle mainBundle] gvc_bundleName];
}

+ (NSString *)gvc_MainBundleDisplayName
{
	NSString *appName = [[NSBundle mainBundle] gvc_bundleDisplayName];
	if ( appName == nil )
	{
		appName = [[NSProcessInfo processInfo] processName];
	}
	return appName;
}

+ (NSString *)gvc_MainBundleVersion
{
	return [[NSBundle mainBundle] gvc_bundleVersion];
}

+ (NSString *)gvc_MainBundleIdentifier
{
	return [[NSBundle mainBundle] gvc_bundleIdentifier];
}

- (NSString *)gvc_bundleName
{
	return [self objectForInfoDictionaryKey:@"CFBundleName"];
}

- (NSString *)gvc_bundleDisplayName
{
	NSString *appName = [self objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	if (appName == nil)
	{
		appName = [self gvc_bundleName];
	}
	return appName;
}

- (NSString *)gvc_bundleVersion
{
	NSString *marketingVersionNumber = [self objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *devVersionNumber = [self objectForInfoDictionaryKey:@"CFBundleVersion"];
	
	NSString *appVersion = nil;
	if (marketingVersionNumber && devVersionNumber) 
	{
		if ([marketingVersionNumber isEqualToString:devVersionNumber]) 
		{
			appVersion = marketingVersionNumber;
		}
		else 
		{
			appVersion = [NSString stringWithFormat:@"%@ rev:%@", marketingVersionNumber, devVersionNumber];
		}
	}
	else
	{
		appVersion = (marketingVersionNumber ? marketingVersionNumber : devVersionNumber);
	}
	
	return appVersion;
}

- (NSString *)gvc_bundleIdentifier
{
	NSString *ident = [self bundleIdentifier];
	if (ident == nil)
	{
		ident = GVC_SPRINTF(@"net.global-village.%@", [[NSProcessInfo processInfo] processName]);
	}
	return ident;
}

@end
