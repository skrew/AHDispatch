//
//  AHDispatchTests.m
//  AHDispatchTests
//
//  Created by Ray Scott on 19/12/2013.
//  Copyright (c) 2013 Alien Hitcher. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AHDispatchTest.h"

#import "AHDispatch.h"

@interface AHDispatchTests : AHDispatchTest

@end

@implementation AHDispatchTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample
{
    AHThrottleQueueEventHandler hdl = ^(dispatch_queue_t queue, dispatch_time_t time) {
        NSLog(@"idle handler!");
        [self signalFinished];
    };
    
    
    dispatch_queue_t tq = ah_throttle_queue_create(nil,
                                                   3.0,
                                                   AH_THROTTLE_MUTABILITY_NONE,
                                                   AH_THROTTLE_MONITOR_CONCURRENT);
    ah_throttle_queue_set_event_handler(tq,
                                        AH_THROTTLE_QUEUE_DID_BECOME_IDLE_EVENT,
                                        hdl);
    
    ah_throttle_after_async(3.0, tq, ^{
        NSLog(@"I'm worker block 1");
    });
    
    ah_throttle_async(tq, ^{
        NSLog(@"I'm worker block 2");
    });
    
    ah_throttle_async(tq, ^{
        NSLog(@"I'm worker block 3");
    });
    
    [self waitUntilFinished];
    
    ah_throttle_after_async(3.0, tq, ^{
        NSLog(@"I'm worker block A");
    });
    
    ah_throttle_async(tq, ^{
        NSLog(@"I'm worker block B");
    });

    [self waitUntilFinished];
}

@end
