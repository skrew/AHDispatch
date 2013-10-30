//
//  AHDispatch.m
//  AHDispatch
//
//  Created by Ray Scott on 29/10/2013.
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

#import "AHDispatch.h"

// a reusable block that waits the specified number of nanoseconds before completing
typedef void (^ThrottleHandler)(uint64_t nanoseconds);

ThrottleHandler const throttle = ^(uint64_t nanoseconds) {
    
    __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds),
                   dispatch_get_main_queue(), ^{
                       
                       dispatch_semaphore_signal(sema);
#ifdef DEBUG
                       NSLog(@"%g sec throttle complete.", nanoseconds * 1.0f / NSEC_PER_SEC );
#endif
                   });
    
    while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
};

#pragma mark - Creating and Managing Throttled Queues

dispatch_queue_t ah_throttle_queue_create(const char *label, uint64_t nanoseconds)
{    
    __strong NSValue *value = @(nanoseconds);

    dispatch_queue_t queue = dispatch_queue_create(label, NULL);
    dispatch_set_context(queue, (__bridge void *)(value));

    return queue;
}


void ah_throttle_queue(dispatch_queue_t queue, uint64_t nanoseconds)
{
    if (queue == NULL) {
        return;
    }
    
    __strong NSValue *value = @(nanoseconds);
    dispatch_set_context(queue, (__bridge void *)(value));
}


#pragma mark - Queuing Tasks for Throttled Dispatch

void ah_throttle_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_async(queue, ^{
        
        NSValue *context = (__bridge NSValue *)(dispatch_get_context(queue));
        uint64_t nanoseconds = 0;
        if (context) { [context getValue:&nanoseconds]; }

        block();

        if (nanoseconds > 0) {
            throttle(nanoseconds);
        }

    });
}


void ah_throttle_after_async(uint64_t nanoseconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_async(queue, ^{
        block();
        throttle(nanoseconds);
    });
}


void ah_throttle_sync(dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    NSValue *context = (__bridge NSValue *)(dispatch_get_context(queue));
    uint64_t nanoseconds = 0;
    if (context) { [context getValue:&nanoseconds]; }
    
    dispatch_sync(queue, ^{
        block();
        throttle(nanoseconds);
    });
}


void ah_throttle_after_sync(uint64_t nanoseconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }

    dispatch_sync(queue, ^{
        block();
        throttle(nanoseconds);
    });
}

@implementation AHDispatch

@end
