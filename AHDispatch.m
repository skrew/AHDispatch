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

#import <dispatch/object.h>
#import <dispatch/time.h>

#import <mach/mach.h>
#import <mach/mach_time.h>


static void * kThrottleTimeKey = &kThrottleTimeKey;
static void * kThrottleTimeModifiedKey = &kThrottleTimeModifiedKey;
static void * kThrottleMonitorKey = &kThrottleMonitorKey;
static void * kThrottleMutabilityKey = &kThrottleMutabilityKey;

#define AH_NSEC_PER_SEC	1000000000ull	/* nanoseconds per second */


// any functions that don't begin with "ah_", are private

// worker blocks are timed during execution, so we can determine the throttle
// time for concurrent monitoring
double timed_execution(void (^block)(void))
{
    uint64_t elapsedNanos = 0;
    static mach_timebase_info_data_t sTimebaseInfo;

    dispatch_time_t before = dispatch_time(DISPATCH_TIME_NOW, 0);
    block();
    dispatch_time_t after = dispatch_time(DISPATCH_TIME_NOW, 0);
    
    uint64_t elapsed = after - before;
    
    // Convert to seconds.
    // Taken from Apple example code:
    // https://developer.apple.com/library/mac/qa/qa1398/_index.html
    //
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
    
    double elapsedSeconds = elapsedNanos / AH_NSEC_PER_SEC;

    return elapsedSeconds;
}


// a reusable block that waits the specified number of seconds before completing
typedef void (^ThrottleHandler)(double seconds);

static ThrottleHandler const throttle = ^(double seconds) {

#ifdef DEBUG
    printf("%g sec throttle started.\n", seconds);
#endif
    __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * AH_NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                       

#ifdef DEBUG
                       printf("%g sec throttle complete.\n", seconds);
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
    double seconds = 0.5;
    
    dispatch_queue_t queue = ah_throttle_queue_create(ctime(&now),
                                                      seconds,
                                                      AH_THROTTLE_MUTABILITY_ALL,
                                                      AH_THROTTLE_MONITOR_CONCURRENT);
    return queue;
}


dispatch_queue_t ah_throttle_queue_create(const char *label,
                                          double seconds,
                                          ah_throttle_mutability_t mutability,
                                          ah_throttle_monitor_t monitor)
{
    dispatch_queue_t queue = dispatch_queue_create(label, NULL);
    
    double *_sec = malloc(sizeof(double));
    *_sec = seconds;
    dispatch_queue_set_specific(queue, kThrottleTimeKey, _sec, NULL);
    dispatch_queue_set_specific(queue, kThrottleMutabilityKey, (void *)mutability, NULL);
    dispatch_queue_set_specific(queue, kThrottleMonitorKey, (void *)monitor, NULL);

    return queue;
}


void ah_throttle_queue(dispatch_queue_t queue, double seconds)
{
    if (queue == NULL) return;
    
    double *_sec = malloc(sizeof(double));
    *_sec = seconds;
    dispatch_queue_set_specific(queue, kThrottleTimeKey, _sec, NULL);
}


double ah_throttle_queue_get_time(dispatch_queue_t queue)
{
    double *seconds = dispatch_queue_get_specific(queue, kThrottleTimeKey);
    
    return *seconds;
}


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

void throttle_dispatch(dispatch_block_t block, double seconds, bool explicit)
{
    // lets see how long the working block takes to execute...
    double executionSeconds = timed_execution(^{
        block();
    });
    
    // now lets determine if we need to throttle execution...
    ah_throttle_mutability_t mutability = (ah_throttle_mutability_t) dispatch_get_specific(kThrottleMutabilityKey);
    
    // we only modify seconds if the queue is a mutable type,
    if (AH_THROTTLE_MUTABILITY_ALL == mutability ||
        (AH_THROTTLE_MUTABILITY_DEFAULT == mutability && !explicit)) {
        printf("dispatchd seconds: %f\n", seconds);
        double *ctxsec = dispatch_get_specific(kThrottleTimeKey);
        seconds = *ctxsec;
        printf("overwrote seconds: %f\n", seconds);
    }
    
    ah_throttle_monitor_t monitor = (ah_throttle_monitor_t) dispatch_get_specific(kThrottleMonitorKey);
    
    // a concurrent monitor will dispatch a throttle block to fill the
    // remaining time if a working block completes execution before the
    // queue throttle time has elapsed
    //
    if (AH_THROTTLE_MONITOR_CONCURRENT == monitor) {
        double throttleSeconds = seconds - executionSeconds;
        if (throttleSeconds > 0) {
            throttle(throttleSeconds);
        }
    }
    else {  // AH_THROTTLE_MONITOR_SERIAL == monitor
        // a serial monitor ignores working block execution time and simply
        // throttles using the the user specified queue throttle time
        if (seconds > 0) {
            throttle(seconds);
        }
    }
}

void ah_throttle_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_async(queue, ^{
        @synchronized(queue) {
            
            throttle_dispatch(block, *(double *)dispatch_get_specific(kThrottleTimeKey), false);
        }
    });
}


void ah_throttle_after_async(double seconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_async(queue, ^{
       @synchronized(queue) {
           
           throttle_dispatch(block, seconds, true);
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

            throttle_dispatch(block, *(double *) dispatch_get_specific(kThrottleTimeKey), false);
        }
    });
}


void ah_throttle_after_sync(double seconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (queue == NULL || block == NULL) {
        return;
    }
    
    dispatch_sync(queue, ^{
        @synchronized(queue) {
            
            throttle_dispatch(block, seconds, true);
        }
    });
}


void ah_throttle_queue_debug(dispatch_queue_t queue, char *buffer)
{
    const char * label = dispatch_queue_get_label(queue);
    double *seconds = (double *)dispatch_queue_get_specific(queue, kThrottleTimeKey);
    ah_throttle_monitor_t monitor = (ah_throttle_monitor_t) dispatch_queue_get_specific(queue, kThrottleMonitorKey);
    ah_throttle_mutability_t mutability = (ah_throttle_mutability_t) dispatch_queue_get_specific(queue, kThrottleMutabilityKey);
    
    char * monstr = "";
    
    if (AH_THROTTLE_MONITOR_CONCURRENT == monitor) {
        monstr = "AH_THROTTLE_MONITOR_CONCURRENT";
    }
    else if (AH_THROTTLE_MONITOR_SERIAL == monitor) {
        monstr = "AH_THROTTLE_MONITOR_SERIAL";
    }
    
    char *mutestr = "";
    
    if (AH_THROTTLE_MUTABILITY_NONE == mutability) {
        mutestr = "AH_THROTTLE_MUTABILITY_NONE";
    }
    else if (AH_THROTTLE_MUTABILITY_ALL == mutability) {
        mutestr = "AH_THROTTLE_MUTABILITY_ALL";
    }
    else if (AH_THROTTLE_MUTABILITY_DEFAULT == mutability)
    {
        mutestr = "AH_THROTTLE_MUTABILITY_DEFAULT";
    }
    
    strcat(buffer, "\n\nthrottle queue debug info:\n");

    strcat(buffer, "label: ");
    strcat(buffer, label);

    strcat(buffer, "\nseconds: ");
    char secstr[128];
    sprintf(secstr, "%f", *seconds);
    strcat(buffer, secstr);

    strcat(buffer, "\nmutability: ");
    strcat(buffer, mutestr);
    
    strcat(buffer, "\nmonitor: ");
    strcat(buffer, monstr);
    strcat(buffer, "\n\n");

}


@implementation AHDispatch

@end
