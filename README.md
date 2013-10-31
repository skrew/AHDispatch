AHDispatch
==========

AHDispatch provides queue throttling functionality for Apple's [Grand Central Dispatch](https://developer.apple.com/library/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html) framework.

##Overview

AHDispatch consists of a number of interfaces similar to GCD that can be used to create throttled serial queues and to dispatch asynchronous and syncronous block tasks to them. 

*But doesn't GCD come with the [`dispatch_after`](https://developer.apple.com/library/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html#//apple_ref/c/func/dispatch_after) call?* Yes it does! And that's great if you need to hang around before your block executes. AHDispatch was borne out of the necesity to comply to the rate limit rules of 3rd party API services. AHDispatch doesn't use `dispatch_after`, so that first block submitted to an empty queue executes without this constraint (but with the usual constraints of concurrent code executing on multicore hardware, of course).

The execution of every block task submitted to a throttled serial queue invokes a private throttle block on completion that blocks the queue from executing the next user block in the queue until the throttle time as elapsed. 

##Quick Start

You can get started using just 2 API calls: `ah_throttle_queue_create` and `ah_throttle_async`. In the example below we're creating a new queue with a throttle time of 1 second and submitting a block for asynchronous execution:

```
dispatch_queue_t api_queue = ah_throttle_queue_create("queue_label", 1 * NSEC_PER_SEC);

ah_throttle_async(api_queue, ^{
		// Do some queued work here...
        // once this block completes, the queue will sit idle for 1 second
});

```

You can change the throttle time for a queue and even add throttling to an existing `dispatch_queue_t` object with `ah_throttle_queue` like this: 

```
ah_throttle_queue(api_queue, 2 * NSEC_PER_SEC);
```
**Note:** this will overwrite any existing queue context previously set with a `dispatch_set_context` call. If you haven't delved into composing your own queues, you can safely ignore this. 



##Requirements
AHDispatch is written for ARC-enabled apps. By default your build target will need to comply with one of the following:

* iOS 6 or later
* OS X 10.8 and later

If you aren't using ARC, you can still use AHDispatch by specifying the [`-fobjc-arc`](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#general) compiler flag for the `AHDispatch.m` file in your target's *Compile Sources*  section of the *Build Phases* tab.

##Functions by Task

A summary of the vaious calls available in `AHDispatch.h`.

###Creating and Managing Throttled Queues

`ah_throttle_queue_create` 

`ah_throttle_queue`

All queues created are serial in nature. Changing the throttle time of a queue, will not effect blocks already submitted to the queue. They will invoke a throttle block with the throttle time that existed when they were submitted to the queue.

###Queuing Tasks for Throttled Dispatch

`ah_throttle_async`

`ah_throttle_after_async`

`ah_throttle_sync`

`ah_throttle_after_sync`

In addition to the standard block submission calls, `ah_throttle_async` and `ah_throttle_sync`, which use the current throttle time of the receiving queue, it is also possible to submit a block specifying a different throttle time to be applied after the execution of just that block. This can be acheived using the `ah_throttle_after` variant calls above.

##Additional Notes
#### On nanosecond values

As when specifying a delta value on creating a `dispatch_time_t` value, all throttle times are specified in nanoseconds, with a type of `int64_t`. To express a throttle time in terms of seconds please use the time multiplier constant `NSEC_PER_SEC` when specifying throttle times. For example, 3 seconds can be expressed as (3 * NSEC_PER_SEC) and passed to a function as below:

```ah_throttle_queue(api_queue, 3 * NSEC_PER_SEC);```
 

##Contact
AHDispatch is maintained by [Ray Scott](https://github.com/rayascott) ([@rayascott](http://www.twitter.com/rayascott)).


##License
AHDispatch is available under the MIT license. For more information, see the included [LICENSE](./LICENSE) file.

