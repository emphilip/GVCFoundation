/*
 * NSDictionaryAdditionsTest.m
 * 
 * Created by David Aspinall on 2013-10-02. 
 * Copyright (c) 2013 Global Village Consulting. All rights reserved.
 *
 */

#import <XCTest/XCTest.h>
#import <GVCFoundation/GVCFoundation.h>

#pragma mark - Interface declaration
@interface NSDictionaryAdditionsTest : XCTestCase

@end


#pragma mark - Test Case implementation
@implementation NSDictionaryAdditionsTest

	// setup for all the following tests
- (void)setUp
{
    [super setUp];
}

	// tear down the test setup
- (void)tearDown
{
    [super tearDown];
}

- (void)testgvc_groupArray
{
    // FIXME:
}

- (void)testgvc_groupUniqueArray
{
    // FIXME:
}

- (void)testgvc_sortedKeys
{
    NSDictionary *unsorted = @{ @"a": @"a", @"bbb":@"bbb", @"ddd":@"ddd", @"aaa":@"aaa", @"eae":@"eae", @"cc":@"cc", @"1":@"1" };
    NSArray *sorted = @[ @"1", @"a", @"aaa", @"bbb", @"cc", @"ddd", @"eae" ];

    NSArray *dictSort = [unsorted gvc_sortedKeys];
    XCTAssertTrue(gcv_IsEqualCollection( dictSort, sorted), @"'%@' != sorted '%@'", dictSort, sorted );
}

@end
