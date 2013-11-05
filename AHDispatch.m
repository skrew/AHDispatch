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

#import <mach/mach.h>
#import <mach/mach_time.h>

static void * kThrottleTimeKey = &kThrottleTimeKey;
static void * kThrottleMonitorKey = &kThrottleMonitorKey;
static void * kThrottleMutabilityKey = &kThrottleMutabilityKey;

#define AH_NSEC_PER_SEC	1000000000ull	/* nanoseconds per second */


uint64_t timed_execution(void (^block)(void))
{
    uint64_t elapsedNanos = 0;
    static mach_timebase_info_data_t sTimebaseInfo;;

    uint64_t before = mach_absolute_time();

    block();
    
    uint64_t after = mach_absolute_time();
    uint64_t elapsed = after - before;
    
    // Convert to nanoseconds.
    
    // If this is the first time we've run, get the timebase.
    // We can use denom == 0 to indicate that sTimebaseInfo is
    // uninitialised because it makes no sense to have a zero
    // denominator as a fraction.
    
    if ( sTimebaseInfo.denom == 0 ) {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
    
    // Do the maths. We hope that the multiplication doesn't
    // overflow; the price you pay for working in fixed point.
    elapsedNanos = elapsed * sTimebaseInfo.numer / sTimebaseInfo.denom;
    
    return elapsedNanos;
}

/*
void set_context_value(dispatch_queue_t queue, void *value, NSString *key)
{
    __strong NSMutableDictionary *context = nil;
    
    // ensure the queue contains a valid context object
    context = (__bridge NSMutableDictionary *)(dispatch_get_context(queue));
    
    if (!context || ![context isKindOfClass:[NSMutableDictionary class]]) {
        // create a context for the queue
        context = [NSMutableDictionary dictionaryWithCapacity:1];
        dispatch_set_context(queue, (void *)CFBridgingRetain(context));
    }

    [context setObject:(__bridge id)value forKey:key];
}

void * get_context_value(dispatch_queue_t queue, NSString *key)
{
    __strong NSMutableDictionary *dictionary = (__bridge  NSMutableDictionary *)(dispatch_get_context(queue));
    
    if (dictionary == nil) return NULL;
    
    return (__bridge void *)[dictionary objectForKey:key];
}
*/

typedef void (^MutableThrottleHandler)(dispatch_queue_t queue);

// a reusable block that waits the specified number of nanoseconds before completing
typedef void (^ThrottleHandler)(uint64_t nanoseconds, dispatch_queue_t queue);

static ThrottleHandler const throttle = ^(uint64_t nanoseconds, dispatch_queue_t queue) {

#ifdef DEBUG
    printf("%g sec throttle started.\n", nanoseconds * 1.0f / AH_NSEC_PER_SEC );
#endif
    __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nanoseconds),
                   dispatch_get_main_queue(), ^{
                       

#ifdef DEBUG
                       printf("%g sec throttle complete.\n", nanoseconds * 1.0f / AH_NSEC_PER_SEC );
#endif
                       dispatch_semaphore_signal(sema);
                   });
    
    while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
};


#pragma mark - Creating and Managing Throttled Queues

dispatch_queue_t ah_throttle_queue_new(void)
{
    time_t now = time(NULL);
    uint64_t nanoseconds = (0.5 * AH_NSEC_PER_SEC);
    
    dispatch_queue_t queue = ah_throttle_queue_create(ctime(&now),
                                                      nanoseconds,
                                                      AH_THROTTLE_MUTABILITY_ALL,
                                                      AH_THROTTLE_MONITOR_CONCURRENT);
    
    return queue;
}


dispatch_queue_t ah_throttle_queue_create(const char *label,
                                          uint64_t nanoseconds,
                                          ah_throttle_mutability_t mutability,
                                          ah_throttle_monitor_t monitor)
{
    dispatch_queue_t queue = dispatch_queue_create(label, NULL);
    dispatch_queue_set_specific(queue, kThrottleMutabilityKey, (void *)mutability, NULL);
    dispatch_queue_set_specific(queue, kThrottleMonitorKey, (void *)monitor, NULL);
    dispatch_queue_set_specific(queue, kThrottleTimeKey, (void *)nanoseconds, NULL);

    return queue;
}


void ah_throttle_queue(dispatch_queue_t queue, uint64_t nanoseconds)
{
    if (queue == NULL) return;
    dispatch_queue_set_specific(queue, kThrottleTimeKey, (void *)nanoseconds, NULL);
}


uint64_t ah_throttle_queue_get_time(dispatch_queue_t queue)
{
    uint64_t nanoseconds = 0;
    nanoseconds = (uint64_t)dispatch_queue_get_specific(queue, kThrottleTimeKey);
    
    return nanoseconds;
}

/* changing the mutablity behavior should not be allowed, after queue creation
void ah_throttle_queue_set_mutability(dispatch_queue_t queue, AHDispatchThrottleMutability mutability)
{
    if (queue == NULL) return;
    
    __strong NSValue *value = @(mutability);
    set_context_value(queue, (__bridge void *)value, kThrottleMutabilityKey);
}
*/

ah_throttle_mutability_t ah_throttle_queue_get_mutability(dispatch_queue_t queue)
{
    ah_throttle_mutability_t mutability;
    mutability = (ah_throttle_mutability_t) dispatch_queue_get_specific(queue, kThrottleMutabilityKey);
    
    return mutability;
}


ah_throttle_monitor_t ah_throttle_queue_get_monitor(dispatch_queue_t queue)
{
    ah_throttle_monitor_t monitor;
    monitor = (ah_throttle_monitor_t) dispatch_queue_get_specific(queue, kThrottleMonitorKey);
    
    return monitor;
}


#pragma mark - Queuing Tasks for Throttled Dispatch

void ah_throttle_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_async(queue, ^{
        
        @synchronized(queue) {

            // lets see how long the working block takes to execute...
            uint64_t executionNanos = timed_execution(^{
                block();
            });
            
            // now lets determine if we need to throttle execution...
            uint64_t queueNanos = (uint64_t)dispatch_queue_get_specific(queue, kThrottleTimeKey);
            ah_throttle_monitor_t monitor = (ah_throttle_monitor_t) dispatch_queue_get_specific(queue, kThrottleMonitorKey);
            
            // a concurrent monitor will dispatch a throttle block to fill the
            // remaining time if a working block completes execution before the
            // queue throttle time has elapsed
            if (AH_THROTTLE_MONITOR_CONCURRENT == monitor) {
                int64_t throttleNanos = queueNanos - executionNanos;
                if (throttleNanos > 0) {
                    throttle(throttleNanos, queue);
                }
            }
            else { // AH_THROTTLE_MONITOR_SERIAL == monitor
                // a serial monitor ignores working block execution time and simply
                // throttles using the the user specified queue throttle time
                if (queueNanos > 0) {
                    throttle(queueNanos, queue);
                }
            }
        
        }

    });
}


void ah_throttle_after_async(uint64_t nanoseconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_async(queue, ^{
       @synchronized(queue) {
            block();
           
            if (nanoseconds > 0) {
                throttle(nanoseconds, queue);
            }
       }
    });

}


void ah_throttle_sync(dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_sync(queue, ^{
        @synchronized(queue) {

            block();
            uint64_t nanoseconds = 0;
            nanoseconds = (uint64_t) dispatch_queue_get_specific(queue, kThrottleTimeKey);
            
            if (nanoseconds > 0) {
                throttle(nanoseconds, queue);
            }
        }
    });
}


void ah_throttle_after_sync(uint64_t nanoseconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_sync(queue, ^{
        @synchronized(queue) {
            
            block();
            
            if (nanoseconds > 0) {
                throttle(nanoseconds, queue);
            }
        }
    });
}


void ah_throttle_queue_debug(dispatch_queue_t queue, char *buffer)
{
    const char * label = dispatch_queue_get_label(queue);
    uint64_t nanoseconds = (uint64_t) dispatch_queue_get_specific(queue, kThrottleTimeKey);
    ah_throttle_monitor_t monitor = (ah_throttle_monitor_t) dispatch_queue_get_specific(queue, kThrottleMonitorKey);
    
    char * monstr = "";
    
    if (monitor == AH_THROTTLE_MONITOR_CONCURRENT) {
        monstr = "AH_THROTTLE_MONITOR_CONCURRENT";
    }
    else if (monitor == AH_THROTTLE_MONITOR_SERIAL) {
        monstr = "AH_THROTTLE_MONITOR_SERIAL";
    }
    
    strcat(buffer, "label: ");
    strcat(buffer, label);
    strcat(buffer, ", monitor: ");
    strcat(buffer, monstr);    
    strcat(buffer, ", nanoseconds: ");
    char nanostr[128];
    sprintf(nanostr, "%llu\n", nanoseconds);
    strcat(buffer, nanostr);

}


@implementation AHDispatch

@end
