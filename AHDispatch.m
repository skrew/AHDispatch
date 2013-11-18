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


static char * kThrottleDomainScope = "com.alienhitcher.ahdispatch.queue";

// properties
static void * kThrottleTimeKey = &kThrottleTimeKey;
static void * kThrottleMonitorKey = &kThrottleMonitorKey;
static void * kThrottleMutabilityKey = &kThrottleMutabilityKey;

// internal
static void * kThrottleQueueKey = &kThrottleQueueKey;
static void * kThrottleCountKey = &kThrottleCountKey;
static void * kThrottleTimeModifiedKey = &kThrottleTimeModifiedKey;

// callbacks
static void * kThrottleQueueDidBecomeActiveHandlerKey = &kThrottleQueueDidBecomeActiveHandlerKey;
static void * kThrottleQueueDidBecomeIdleHandlerKey = &kThrottleQueueDidBecomeIdleHandlerKey;

typedef void (^AHThrottleQueueDidBecomeActiveHandler) (dispatch_queue_t queue, dispatch_time_t time);
typedef void (^AHThrottleQueueDidBecomeIdleHandler) (dispatch_queue_t queue, dispatch_time_t time);

#define AH_NSEC_PER_SEC             1000000000ull	/* nanoseconds per second */
#define AH_THROTTLE_TIME_DEFAULT    0.5             /* sensible default */


#ifdef AH_DISPATCH_DEBUG
    #define debugf(text, ...)  printf(debug_format(__LINE__, text), ##__VA_ARGS__);
    #define debug(text)  printf(debug_format(__LINE__, text), NULL);
#else
    #define debugf(text, ...);
    #define debug(text);
#endif


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




char * debug_format(int line, char *format)
{
    time_t now = time(NULL);
    
    // generate timestamp string
    char *now_str = malloc(20);
    memset(now_str, 0, sizeof(&now_str));
    strftime(now_str, 20, "%Y-%m-%d %H:%M:%S", localtime(&now));
    
    
    char *formatted_str = malloc(256);
    memset(formatted_str, 0, sizeof(&formatted_str));
    strcat(formatted_str, now_str);
    sprintf(formatted_str, "%s %s %d ", formatted_str, __FILE__, line);
    strcat(formatted_str, format);

    return formatted_str;
}

// we don't allow throttling on the default system queues
// throttling is pointless on concurrent queues and the main queue
bool valid_serial_queue(dispatch_queue_t queue)
{
    if (queue == NULL ||
        queue == dispatch_get_main_queue() ||
        queue == dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) ||
        queue == dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) ||
        queue == dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0) ||
        queue == dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)) {
        return false;
    }

    return true;
}


bool valid_mutability(ah_throttle_mutability_t mutability)
{
    return (mutability < 3);
}


bool valid_monitor(ah_throttle_monitor_t monitor)
{
    if (monitor == AH_THROTTLE_MONITOR_CONCURRENT ||
        monitor == AH_THROTTLE_MONITOR_SERIAL) {
        return true;
    }
    
    return false;
}


// a reusable block that waits the specified number of seconds before completing
typedef void (^ThrottleHandler)(double seconds);

static ThrottleHandler const throttle = ^(double seconds) {

#ifdef DEBUG
    //printf("%g sec throttle started.\n", seconds);
#endif
    __block dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, seconds * AH_NSEC_PER_SEC),
                   dispatch_get_main_queue(), ^{
                       

#ifdef DEBUG
                       //printf("%g sec throttle complete.\n", seconds);
#endif
                       dispatch_semaphore_signal(sema);
                   });
    
    while (dispatch_semaphore_wait(sema, DISPATCH_TIME_NOW)) {
        
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    
};


void increment_queue_count(dispatch_queue_t queue)
{
    int *count = dispatch_queue_get_specific(queue, kThrottleCountKey);
    *count += 1;
}


void decrement_queue_count(dispatch_queue_t queue)
{
    int *count = dispatch_queue_get_specific(queue, kThrottleCountKey);
    *count -= 1;
}

// ensure queue has valid throttle context
// dispatch calls are routed through this function so that unfamiliar queues play
// nicely with throttling
void enforce_throttle_context(dispatch_queue_t queue)
{
    double *time = dispatch_queue_get_specific(queue, kThrottleTimeKey);
    
    if (time == NULL) {
        time = malloc(sizeof(double));
        *time = AH_THROTTLE_TIME_DEFAULT;
        dispatch_queue_set_specific(queue, kThrottleTimeKey, time, (dispatch_function_t)free);
    }
    
    if (!valid_mutability(ah_throttle_queue_get_mutability(queue))) {
        dispatch_queue_set_specific(queue,
                                    kThrottleMutabilityKey,
                                    (void *)AH_THROTTLE_MUTABILITY_ALL, NULL);
    }
    
    if (!valid_monitor(ah_throttle_queue_get_monitor(queue))) {
        dispatch_queue_set_specific(queue,
                                    kThrottleMonitorKey,
                                    (void *)AH_THROTTLE_MONITOR_CONCURRENT, NULL);
    }
    
    if ((__bridge dispatch_queue_t)(dispatch_get_specific(kThrottleQueueKey)) == NULL) {
        dispatch_queue_set_specific(queue,
                                    kThrottleQueueKey,
                                    (void *)CFBridgingRetain(queue),
                                    (dispatch_function_t)CFBridgingRelease);
    }
    
    int *count = (int *)dispatch_queue_get_specific(queue, kThrottleCountKey);
    if (count == NULL) {
        count = malloc(sizeof(int));
        *count = 0;
        dispatch_queue_set_specific(queue, kThrottleCountKey, count, (dispatch_function_t)free);
    }
   
}


void throttle_dispatch(dispatch_block_t block, double seconds, bool explicit)
{
    dispatch_queue_t queue = (__bridge dispatch_queue_t)(dispatch_get_specific(kThrottleQueueKey));
    
    // if we're dispatching to an empty queue, perform the did become active block
    /*
     if (ah_throttle_queue_get_size(queue) == 0) {
     
     }
     */
    
    // lets see how long the working block takes to execute...
    
    debug("block started...\n");

    double executionSeconds = timed_execution(^{
        block();
    });
    
    
    decrement_queue_count(queue);
    
    debugf("done in %gs\n", executionSeconds);
    
    // now lets determine if we need to throttle execution...
    ah_throttle_mutability_t mutability = (ah_throttle_mutability_t) dispatch_get_specific(kThrottleMutabilityKey);
    
    // we only modify seconds if the queue is a mutable type,
    if (AH_THROTTLE_MUTABILITY_ALL == mutability ||
        (AH_THROTTLE_MUTABILITY_DEFAULT == mutability && !explicit)) {
        
        double dispatch_seconds = seconds;
        double *ctxsec = dispatch_get_specific(kThrottleTimeKey);
        
        if (seconds != *ctxsec) {
            seconds = *ctxsec;
            debugf("overwrote %g throttle with %g\n", dispatch_seconds, seconds);
        }
    }
    
    // a concurrent monitor will dispatch a throttle block to fill the
    // remaining time if a working block completes execution before the
    // queue throttle time has elapsed
    
    ah_throttle_monitor_t monitor = (ah_throttle_monitor_t) dispatch_get_specific(kThrottleMonitorKey);
    seconds = (AH_THROTTLE_MONITOR_SERIAL == monitor) ? : seconds - executionSeconds;
    
    if (seconds > 0) {
        
        debugf("throttling: %g... \n", seconds);
        time_t start, end;
        start = time(NULL);
        
        throttle(seconds);
        
        end = time(NULL);
        //debugf("done in %g.\n", difftime(end, start));
        debug("done\n");
    }
    else {
        debug("throttle unneccessary\n");
    }
    
    // TODO  examine queue size and perform queueDidBecomeIdleBlock() if equal to zero
    
}


#pragma mark - Creating and Managing Throttled Queues

dispatch_queue_t ah_throttle_queue_new(void)
{
    time_t now = time(NULL);
    
    char label[256]  = "";
    strcat(label, kThrottleDomainScope);
    strcat(label, "-");
    strcat(label, ctime(&now));
    
    dispatch_queue_t queue = ah_throttle_queue_create(label,
                                                      AH_THROTTLE_TIME_DEFAULT,
                                                      AH_THROTTLE_MUTABILITY_ALL,
                                                      AH_THROTTLE_MONITOR_CONCURRENT);
    return queue;
}


dispatch_queue_t ah_throttle_queue_create(const char *label,
                                          double seconds,
                                          ah_throttle_mutability_t mutability,
                                          ah_throttle_monitor_t monitor)
{
    dispatch_queue_t queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL);
    
    double *_sec = malloc(sizeof(double));
    *_sec = seconds;
    dispatch_queue_set_specific(queue, kThrottleTimeKey, _sec, (dispatch_function_t)free);
    dispatch_queue_set_specific(queue, kThrottleMutabilityKey, (void *)mutability, NULL);
    dispatch_queue_set_specific(queue, kThrottleMonitorKey, (void *)monitor, NULL);
    dispatch_queue_set_specific(queue, kThrottleQueueKey, (void *)CFBridgingRetain(queue), (dispatch_function_t)CFBridgingRelease);
    
    int *count = malloc(sizeof(int));
    *count = 0;
    dispatch_queue_set_specific(queue, kThrottleCountKey, count, (dispatch_function_t)free);

    return queue;
}


void ah_throttle_queue(dispatch_queue_t queue, double seconds)
{
    if (!valid_serial_queue(queue)) return;
    
    //  NOTE:
    //  We do not need to test for queue mutability here before changing the default
    //  throttle time. Any queue can have it's throttle time changed, at any time.
    //  Mutability is with respect to the throttle blocks already queued for
    //  execution, and that check occurs in `throttle_dispatch`
    double *ctxsecs = dispatch_queue_get_specific(queue, kThrottleTimeKey);
    
    if (&ctxsecs != NULL) {
        *ctxsecs = seconds;
    }
    else {
        ctxsecs = malloc(sizeof(double));
        *ctxsecs = seconds;
        dispatch_queue_set_specific(queue, kThrottleTimeKey, ctxsecs, (dispatch_function_t)free);
    }
}


double ah_throttle_queue_get_time(dispatch_queue_t queue)
{
    if (!valid_serial_queue(queue)) {
        return 0;
    }
    
    double *seconds = dispatch_queue_get_specific(queue, kThrottleTimeKey);
    
    return *seconds;
}


ah_throttle_mutability_t ah_throttle_queue_get_mutability(dispatch_queue_t queue)
{
    if (!valid_serial_queue(queue)) {
        return AH_THROTTLE_MUTABILITY_NONE;
    }
    
    ah_throttle_mutability_t mutability;
    mutability = (ah_throttle_mutability_t) dispatch_queue_get_specific(queue, kThrottleMutabilityKey);
    
    return mutability;
}


ah_throttle_monitor_t ah_throttle_queue_get_monitor(dispatch_queue_t queue)
{
    if (!valid_serial_queue(queue)) {
        return AH_THROTTLE_MONITOR_CONCURRENT;
    }
    
    ah_throttle_monitor_t monitor;
    monitor = (ah_throttle_monitor_t) dispatch_queue_get_specific(queue, kThrottleMonitorKey);
    
    return monitor;
}


int ah_throttle_queue_get_size(dispatch_queue_t queue)
{
    if (!valid_serial_queue(queue)) return 0;
    
    int *count;
    count = (int *)dispatch_queue_get_specific(queue, kThrottleCountKey);
    
    if (count == NULL) {
        count = malloc(sizeof(int));
        *count = 0;
        dispatch_queue_set_specific(queue, kThrottleCountKey, count, (dispatch_function_t)free);
    }
    
    return *count;
}

void ah_throttle_queue_set_did_become_active_block(void (^active)(dispatch_queue_t queue, dispatch_time_t time))
{
    
}

#pragma mark - Queuing Tasks for Throttled Dispatch


void ah_throttle_async(dispatch_queue_t queue, dispatch_block_t block)
{
    if (!valid_serial_queue(queue) || block == NULL) {
        return;
    }
    
    enforce_throttle_context(queue);
    increment_queue_count(queue);
    
    dispatch_async(queue, ^{
        @synchronized(queue) {
            
            throttle_dispatch(block, *(double *)dispatch_get_specific(kThrottleTimeKey), false);
        }
    });
}


void ah_throttle_after_async(double seconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (!valid_serial_queue(queue) || block == NULL) {
        return;
    }
    
    enforce_throttle_context(queue);
    increment_queue_count(queue);
    
    dispatch_async(queue, ^{
       @synchronized(queue) {
           
           throttle_dispatch(block, seconds, true);
       }
    });
}


void ah_throttle_sync(dispatch_queue_t queue, dispatch_block_t block)
{
    if (!valid_serial_queue(queue) || block == NULL) {
        return;
    }
    
    enforce_throttle_context(queue);
    increment_queue_count(queue);
    
    dispatch_sync(queue, ^{
        @synchronized(queue) {

            throttle_dispatch(block, *(double *) dispatch_get_specific(kThrottleTimeKey), false);
        }
    });
}


void ah_throttle_after_sync(double seconds, dispatch_queue_t queue, dispatch_block_t block)
{
    if (!valid_serial_queue(queue) || block == NULL) {
        return;
    }
    
    enforce_throttle_context(queue);
    increment_queue_count(queue);
    
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
    
    char * monstr = (AH_THROTTLE_MONITOR_CONCURRENT == monitor) ? "AH_THROTTLE_MONITOR_CONCURRENT"
                                                                : "AH_THROTTLE_MONITOR_SERIAL";
    
    char *mutestr = "";
    switch (mutability) {
        case AH_THROTTLE_MUTABILITY_NONE:
            mutestr = "AH_THROTTLE_MUTABILITY_NONE";
            break;
            
        case AH_THROTTLE_MUTABILITY_DEFAULT:
            mutestr = "AH_THROTTLE_MUTABILITY_DEFAULT";
            break;
            
        default:
            mutestr = "AH_THROTTLE_MUTABILITY_ALL";
            break;
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
