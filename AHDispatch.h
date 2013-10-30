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



#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>

#ifndef AlienHitcher_AHDispatch_h
#define AlienHitcher_AHDispatch_h


#pragma mark - Creating and Managing Throttled Queues

///----------------------------------------------
///  @name Creating and Managing Throttled Queues
///----------------------------------------------


/**
 *  Creates a serial dispatch queue with the the specified throttle time in nanoseconds.
 *  
 *  Takes a time interval in nanoseconds by which to delay the next task. Use the time multiplier constant `NSEC_PER_SEC` to help construst units of time expressed as seconds. For E.G. 3 seconds can be expressed as (3 * NSEC_PER_SEC).
 *
 *  @param label       A string label to identify this queue by. This parameter is optional and can be NULL.
 *  @param nanoseconds The number of nanoseconds by which to throttle tasks.
 *
 *  @return A `dispatch_queue_t` type with the specified throttle time.
 */
dispatch_queue_t ah_throttle_queue_create(const char *label, uint64_t nanoseconds);

/**
 *  Adds the specified throttle time to the given dispatch queue
 *
 *  @param queue       The dispatch queue to throttle. This parameter can not be NULL.
 *  @param nanoseconds The number of nanoseconds by which to throttle the queue after completion of each block.
 */
void ah_throttle_queue(dispatch_queue_t queue, uint64_t nanoseconds);


#pragma mark - Queuing Tasks for Throttled Dispatch

///--------------------------------------------
///  @name Queuing Tasks for Throttled Dispatch
///--------------------------------------------

/**
 *  Submits a block for asynchronous execution on a throttled dispatch queue and returns immediately. 
 *
 *  @param queue The queue on which to submit the block. Once execution of the block has completed the next block in the queue will be delayed until the queues throttle time has completed. This parameter can not be NULL.
 *  @param block The block to submit to the specified dispatch queue. If the block is submitted to a `dispatch_queue_t' that isn't throttled, the next block will begin executing immediately. This parameter can not be NULL.
 */
void ah_throttle_async(dispatch_queue_t queue, dispatch_block_t block);

/**
 *  Submits a block for asynchronous execution on a throttled dispatch queue, with a specified throttle time, to the delay the queue by. This call returns immediately.
 *
 *  @param nanoseconds The number of nanoseconds by which to throttle the queue after completion of this block.
 *  @param queue       The queue on which to submit the block. This parameter can not be NULL.
 *  @param block       The block to submit to the specified dispatch queue. This parameter can not be NULL.
 */
void ah_throttle_after_async(uint64_t nanoseconds, dispatch_queue_t queue, dispatch_block_t block);

/**
 *  Submits a block object for execution on a dispatch queue and waits until that block and the throttle block complete.
 *
 *  @param queue The queue on which to submit the block. This parameter can not be NULL.
 *  @param block The block to be invoked on the throttled dispatch queue. This parameter cannot be NULL.
 */
void ah_throttle_sync(dispatch_queue_t queue, dispatch_block_t block);

/**
 *  Submits a block object for execution on a dispatch queue, with a specified throttle time, and waits until that block and the throttle block complete.
 *
 *  @param nanoseconds The number of nanoseconds by which to throttle the queue after completion of this block.
 *  @param queue The queue on which to submit the block. This parameter can not be NULL.
 *  @param block The block to be invoked on the throttled dispatch queue. This parameter cannot be NULL.
 */
void ah_throttle_after_sync(uint64_t nanoseconds, dispatch_queue_t queue, dispatch_block_t block);

#endif /* AlienHitcher_AHDispatch_h */

/**
 *  GCD Queue Throttling Utilities
 */
@interface AHDispatch : NSObject

@end

