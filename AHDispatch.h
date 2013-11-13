//
//  AHDispatch.h
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

#include <dispatch/dispatch.h>

/*!
 * @interface AHDispatch
 * @abstract Provides queue throttling functionality for Grand Central Dispatch.
 *
 */
@interface AHDispatch : NSObject

@end


#ifndef AlienHitcher_AHDispatch_h
#define AlienHitcher_AHDispatch_h

/*! Indicates queue behavior with regard to throttle time changes. */
typedef enum {
    AH_THROTTLE_MUTABILITY_ALL,
    AH_THROTTLE_MUTABILITY_DEFAULT,
    AH_THROTTLE_MUTABILITY_NONE
} ah_throttle_mutability_t;

/*! Indicates the way the throttle time is measured and applied. */
typedef enum  {
    AH_THROTTLE_MONITOR_CONCURRENT,
    AH_THROTTLE_MONITOR_SERIAL
} ah_throttle_monitor_t;


#pragma mark - Creating and Managing Throttled Queues

///----------------------------------------------
///  @name Creating and Managing Throttled Queues
///----------------------------------------------


/*!
 *  Creates a standard throttled queue with sensible defaults
 *
 *  Defaults:
 *  1. Label: char* representation of the time the queue was created
 *  2. Throttle Time: 0.5 seconds
 *  3. Mutability: AH_THROTTLE_MUTABILITY_ALL
 *  4. Throttle Monitor: AH_THROTTLE_MONITOR_CONCURRENT
 *
 *  @return A `dispatch_queue_t` initialized with sensible defaults.
 */
dispatch_queue_t ah_throttle_queue_new(void);

/*!
 *  Creates a serial dispatch queue with the the specified throttle time in nanoseconds.
 *  
 *  Takes a time interval in nanoseconds by which to delay the next task. Use the time multiplier constant `NSEC_PER_SEC` to help construst units of time expressed as seconds. For E.G. 3 seconds can be expressed as (3 * NSEC_PER_SEC).
 *
 *  @param label       A string label to identify this queue by. This parameter is optional and can be NULL.
 *  @param seconds    A double value representing the number of seconds by which to throttle tasks.
 *  @param mutability A `ah_throttle_mutability_t` value to apply to the given queue.
 *
 *  @return A `dispatch_queue_t` type with the specified throttle time.
 */
dispatch_queue_t ah_throttle_queue_create(const char *label,
                                          double seconds,
                                          ah_throttle_mutability_t mutability,
                                          ah_throttle_monitor_t monitor);

/*!
 *  Adds the specified throttle time to the given dispatch queue
 *
 *  @param queue       The dispatch queue to throttle. This parameter can not be NULL.
 *  @param seconds     The number of seconds by which to throttle the queue after completion of each block.
 */
void ah_throttle_queue(dispatch_queue_t queue, double seconds);

/*!
 *  Returns the default throttle time, in nanoseconds, for the given queue.
 *
 *  @param queue The queue to act as the receiver for this call.
 *
 *  @return A double value representing the given queue's throttle time in seconds.
 */
double ah_throttle_queue_get_time(dispatch_queue_t queue);

/*!
 *  Sets the behavior of the queue's throttle time mutability.
 * 
 *  A queue's throttle time mutability setting comes into consideration when a client changes a queue's default throttle time (using `ah_queue_throttle()`) for a queue that already has throttled blocks queued in it.
 *  
 *  Mutability behavior explained:
 * 
 *  1. AHDispatchThrottleMutabilityAll - changing the queues throttle time will affect all throttled execution blocks yet to be invoked. This is the default setting.
 *  2. AHDispatchThrottleMutabilityDefault - changing the queues throttle time will only affect throttled execution blocks that were submitted without an explicit throttle time. Set to this behavior type, throttle times for blocks dispatched with the `ah_throttle_after` variant calls are left unchanged after a 'ah_throttle_queue' call. Changes to the queue's throttle time only affect blocks submitted with calls that assumed the queue's default throttle time.
 *  3. AHDispatchThrottleMutabilityNone - The throttle time of blocks already in the throttled queue are left unchanged by changes to the queue's throttle time. The new throttle time will, of course, be applied to any blocks submitted to the queue assuming an implicit throttle time.
 *
 *  @param queue      The queue to act as the receiver for this call.
 *  @param mutability A `ah_throttle_mutability_t` value to apply to the given queue.
 *  
 *  @see ah_throttle_queue
 */
void ah_throttle_queue_set_mutability(dispatch_queue_t queue, ah_throttle_mutability_t mutability);


/*!
 *  Returns the given queue's throttle time mutability behavior type.
 *
 *  @param queue The queue to act as the receiver for this call.
 *
 *  @return The `AHDispatchThrottleMutability` value for the given queue.
 */
ah_throttle_mutability_t ah_throttle_queue_get_mutability(dispatch_queue_t queue);


/*!
 *  Returns the throttle monitor type for this queue.
 *
 *  @param queue The queue to act as the receiver for this call.
 *
 *  @return a `ah_throttle_monitor_t` indicating serial or concurrent throttle monitoring
 */
ah_throttle_monitor_t ah_throttle_queue_get_monitor(dispatch_queue_t queue);


/*!
 *  Returns The number of throttled blocks currently in the queue.
 *
 *  @param queue The queue to act as the receiver for this call.
 *
 *  @return An `int` containing the number of throttled blocks currently in the queue.
 */
int ah_throttle_queue_get_size(dispatch_queue_t queue);


#pragma mark - Queuing Tasks for Throttled Dispatch

///--------------------------------------------
///  @name Queuing Tasks for Throttled Dispatch
///--------------------------------------------

/*!
 *  Submits a block for asynchronous execution on a throttled dispatch queue and returns immediately. 
 *
 *  @param queue The queue on which to submit the block. Once execution of the block has completed the next block in the queue will be delayed until the queues throttle time has completed. This parameter can not be NULL.
 *  @param block The block to submit to the specified dispatch queue. If the block is submitted to a `dispatch_queue_t' that isn't throttled, the next block will begin executing immediately. This parameter can not be NULL.
 */
void ah_throttle_async(dispatch_queue_t queue, dispatch_block_t block);

/*!
 *  Submits a block for asynchronous execution on a throttled dispatch queue, with a specified throttle time, to the delay the queue by. This call returns immediately.
 *
 *  @param seconds     The number of seconds by which to throttle the queue after completion of this block.
 *  @param queue       The queue on which to submit the block. This parameter can not be NULL.
 *  @param block       The block to submit to the specified dispatch queue. This parameter can not be NULL.
 */
void ah_throttle_after_async(double seconds, dispatch_queue_t queue, dispatch_block_t block);

/*!
 *  Submits a block object for execution on a dispatch queue and waits until that block and the throttle block complete.
 *
 *  @param queue The queue on which to submit the block. This parameter can not be NULL.
 *  @param block The block to be invoked on the throttled dispatch queue. This parameter cannot be NULL.
 */
void ah_throttle_sync(dispatch_queue_t queue, dispatch_block_t block);

/*!
 *  Submits a block object for execution on a dispatch queue, with a specified throttle time, and waits until that block and the throttle block complete.
 *
 *  @param seconds The number of seconds by which to throttle the queue after completion of this block.
 *  @param queue The queue on which to submit the block. This parameter can not be NULL.
 *  @param block The block to be invoked on the throttled dispatch queue. This parameter cannot be NULL.
 */
void ah_throttle_after_sync(double seconds, dispatch_queue_t queue, dispatch_block_t block);

/*!
 *  Generates a debug string of the throttle queue properties, into the given buffer.
 *
 *  @param queue   The queue we want debug information on.
 *  @param buffer  Upon return, contains the characters of the debug information from the receiver. buffer must be large enough to contain all characters of the debug information
 */
void ah_throttle_queue_debug(dispatch_queue_t queue, char *buffer);

#endif /* AlienHitcher_AHDispatch_h */

