#AHDispatch for GCD

AHDispatch provides queue throttling functionality for Apple's [Grand Central Dispatch](https://developer.apple.com/library/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html) (GCD) framework.

<table width="100%" border=0>
	<tr>
		<td width="50%">1. <a href="#overview">Overview</a></td>
		<td>7. <a href="#ref-documentation">Reference Documentation</a></td>
	</tr>
	<tr>
		<td>2. <a href="#requirements">Requirements</a></td>
		<td>8. <a href="#debugging">Debugging</a></td>
	</tr>
	<tr>
		<td>3. <a href="#installation">Installation</a></td>
		<td>9. <a href="#notes">Additional Notes</a></td>
	</tr>
	<tr>
		<td>4. <a href="#quickstart">Coding Quick Start</a></td>
		<td>10. <a href="#contact">Contact</a></td>
	</tr>
	<tr>
		<td>5. <a href="#functions">Functions by Task</a></td>
		<td>11. <a href="#license">License</a></td>
	</tr>
	<tr>
		<td>6. <a href="#mutability">Throttle Mutability & Monitors</a></td>
	</tr>

</table>

##1. <a name="overview">Overview</a>

AHDispatch consists of a number of interfaces similar to GCD that can be used to create throttled serial queues and to dispatch asynchronous and syncronous block tasks to them. 

*But doesn't GCD come with the [`dispatch_after`](https://developer.apple.com/library/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html#//apple_ref/c/func/dispatch_after) call?* Yes it does! And that's great if you need to hang around before your block executes. AHDispatch was borne out of the necessity to comply to the rate limit rules of 3rd party API services. AHDispatch doesn't use `dispatch_after`, so that first block submitted to an empty queue executes without this constraint (but with the usual constraints of concurrent code executing on multicore hardware, of course).

##2. <a name="requirements">Requirements</a>
AHDispatch is written for ARC-enabled apps. By default your build target will need to comply with one of the following:

* iOS 6 or later
* OS X 10.8 and later

If you aren't using ARC, you can still use AHDispatch by specifying the [`-fobjc-arc`](http://clang.llvm.org/docs/AutomaticReferenceCounting.html#general) compiler flag for the `AHDispatch.m` file in your target's *Compile Sources*  section of the *Build Phases* tab.

##3. <a name="installation">Installation</a>
While you can simply drag 'n drop the source files from the repo into your Xcode project, installation via [CocoaPods](http://www.cocoapods.org) is the recommended way of integrating AHDispatch with your project. 

To install via CocoaPods, simply add the following line to your project's [Podfile](http://docs.cocoapods.org/podfile.html):

```
pod 'AHDispatch'
```
then, at the command line, from the same directory as your Podfile, run
 
```
pod install
```


##4. <a name="quickstart">Coding Quick Start</a>
First, <a href="#installation">install</a> the source files to your project, then import the header file into your code somewhere sensible:

```
#import "AHDispatch.h"
```

Next, you can get started by using just 2 API calls: [`ah_throttle_queue_new`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_new) and [`ah_throttle_async`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_async). In the example below we're creating a new queue with the default throttle time of 0.5 seconds and submitting a block for asynchronous execution:

```
dispatch_queue_t throttled_queue = ah_throttle_queue_new();

ah_throttle_async(throttled_queue, ^{
		// this worker block does some queued work here...
});

```

You can change the throttle time for a queue with [`ah_throttle_queue`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue) like this: 

```
ah_throttle_queue(throttled_queue, 1.5);
```
**Note:** any queues that aren't created directly by AHDispatch, this includes any of the queues that iOS comes with out of the box (main or global), will NOT work with AHDispatch's throttle functionality. This limitation was introduced to ensure that only serial queues are used with AHDispatch.



##5. <a name="functions">Functions by Task</a>

A summary of the vaious calls available in [`AHDispatch.h`](AHDispatch.h).

###5.1 Creating and Managing Throttled Queues

[`ah_throttle_queue_new()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_new)<br/>
[`ah_throttle_queue_create()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_create)<br/>
[`ah_throttle_queue()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue)<br/>

All queues created are serial in nature. Changing the throttle time of a queue, with [`ah_throttle_queue()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue), may affect blocks already submitted to the queue, depending on the queue's throttle mutability type. See [Throttle Mutability](#mutability) for more information on the mutability behaviour of queues.

[`ah_throttle_queue_new()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_new) creates a queue with the following default settings:

1. A label set to the AHDispatch domain scope, "*com.alienhitcher.ahdispatch.queue*", & the system time.
2. The default throttle time of 0.5 sec (`AH_THROTTLE_TIME_DEFAULT`).
3. A [`ah_throttle_mutability_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_mutability_t) of type `AH_THROTTLE_MUTABILITY_ALL`.
4. A [`ah_throttle_monitor_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_monitor_t) of type `AH_THROTTLE_MONITOR_CONCURRENT`.

###5.2 Queuing Tasks for Throttled Dispatch

####5.2.1 Asynchronous
[`ah_throttle_async`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_async)<br/>
[`ah_throttle_after_async`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_after_async)<br/>
####5.2.2 Synchronous
[`ah_throttle_sync`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_sync)<br/>
[`ah_throttle_after_sync`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_after_sync)<br/>

In addition to the standard block submission calls, [`ah_throttle_async()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_async) and [`ah_throttle_sync()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_sync), which use the current throttle time of the receiving queue, it is also possible to submit a block specifying a different throttle time to be applied after the execution of just that block. This can be acheived using the *ah_throttle_after_&#8727;* variant calls above.

##6. <a name="mutability">Throttle Mutability & Monitors</a>

When we talk about throttle queues being mutable, is it always about the throttle time having the ability to change after the queue has been created and used. Queues are not mutable in the way that an NSMutableArray is mutable, I.E. in the way that objects can be added and removed from a mutable array at will. It can sometimes be more helpful to think of the throttle time as begin mutable, because the working blocks dispatched to a queue certainly aren't mutable. 

Before we take a closer look at throttle mutability, lets briefly touch on throttle monitors so that we have a better understand of the context in which throttle mutability occurs.   

###6.1 Throttle Monitor Types
A throttle monitor, indicated by the type [`ah_throttle_monitor_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_monitor_t) is a device that controls the way in which the throttle time is measured and applied. This measuring of time can occur concurrently, while a worker block is being executed or serially, after a worker block has completed executing.

####6.1.1 Serial Monitors
A serial monitor goes to work after a worker block has finished executing. It is responsible for executing and monitoring throttle times inbetween worker blocks. If a queue has a throttle time of 0.5 sec, and a serial monitor, then the queue will be throttled for a time of 0.5 seconds between each worker block dispatched to the queue. So as you can see, throttle time monitoring and execution occurs serially, with respect to the blocks you dispatch to the throttle queue. They essentially create a time buffer between worker blocks.

A serial monitor can be applied to a queue by specifying the [`ah_throttle_monitor_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_monitor_t) type constant of `AH_THROTTLE_MONITOR_SERIAL` when creating a queue with the [`ah_throttle_queue_create()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_create) function call.

####6.1.2 Concurrent Monitors
While serial monitors are easy to understand, they aren't the most effective way of monitoring and applying a throttle. 

Concurrent monitors are easy to understand within the context of HTTP requests sent to a 3rd party API service. The API service doesn't care how long the response takes to arrive back at the client, or how long your worker block takes to execute. The service only cares that you leave a certain amount of time between the requests you send to it. While serial throttle monitors measure and apply a throttle time relative to the end of a working block's execution, a concurrent monitor, by contrast, measures and applies a throttle time relative to the start of a worker block's execution. 

If an initial worker block takes 1.2 second to execute in a queue with a 0.5 sec throttle time, because the throttle time has been exceeded by the time the worker block completes execution (by 0.7 seconds), the next worker block is executed immediately after that initial worker block completes. So as you can see, throttle time is being monitored concurrently with respect to the blocks you dispatch to the throttle queue. 

A concurrent throttle monitor can be applied to a queue implicitly by creating a queue with a call to [`ah_throttle_queue_new()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_new) or by specifying the [`ah_throttle_monitor_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_monitor_t) type constant `AH_THROTTLE_MONITOR_CONCURRENT` when creating a queue with the [`ah_throttle_queue_create()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_create) function call.

###6.2 Throttle Mutability Types
Throttle mutability types control queue behaviour with regard to throttle time changes. If you never call [`ah_throttle_queue()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue) on an existing queue, you do not need to concern yourself with throttle time mutability. 

If you do change the throttle time of an existing throttle queue, it's important to understand the implications of this change to blocks that have already been submitted to the queue and are still awaiting execution. It's also important to recognise the implications of throttle time changes on blocks dispatched with the *ah_throttle_after_&#8727;* variant calls, where an explicit throttle time, different from the queue's default throttle time, is specified. 

All queues created by calling [`ah_throttle_queue_new()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_new), are created with a [`ah_throttle_mutability_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_mutability_t) type of `AH_THROTTLE_MUTABILITY_ALL`. This type ensures that after a call to [`ah_throttle_queue()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue), any throttle blocks queued for execution will have this new throttle time applied to them, even blocks submitted with any of the *ah_throttle_after_&#8727;* variant calls. So all throttle blocks are mutable. This is the default setting. Blocks submitted to the queue after the call to change the throttle time, [`ah_throttle_queue()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue), will have that new throttle value applied to them when dispatched using the implicit throttle time function calls ([`ah_throttle_async()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_async) & [`ah_throttle_sync()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_sync)). This is, of course, normal behaviour after changing the default throttle time, irrespective of the queue's mutability type. Mutability type only affects blocks already queued for execution. 

If you create a throttle queue with a mutability type of `AH_THROTTLE_MUTABILITY_DEFAULT`, any calls to change the throttle time of a populated queue will only have an affect on blocks in the queue that were added with function calls that assumed the default throttle time value, when they were called. Throttle time changes do not affect blocks dispatched with the *ah_throttle_after_&#8727;* variant calls, only blocks dispatched with calls assuming the default throttle time.

If you want to prevent throttle time changes from affecting blocks already queued for execution, simply create a queue with a [`ah_throttle_mutability_t`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/tdef/ah_throttle_mutability_t) type of `AH_THROTTLE_MUTABILITY_NONE`. 

**Remember**: throttle mutability relates to blocks that are already queued for execution. You can still affect the default throttle time of blocks submitted to the queue **after** a call to [`ah_throttle_queue()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue) regardless of the queue mutability type. 

##7. <a name="ref-documentation">Reference Documentation</a>
 - [AHDispatch API Reference](http://rayascott.github.io/AHDispatch) 
 - [Grand Central Dispatch (GCD) Reference](https://developer.apple.com/library/ios/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html)

##8. <a name="debugging">Debugging</a>
To enable the output of trace messages to the console, add the key `AH_DISPATCH_DEBUG` to the list of your *Target*'s **Preprocessor Macros**. In XCode 5, this can be found under the heading '**Apple LLVM 5.0 - Preprocessing**' in the **Build Settings** tab.

##9. <a name="notes">Additional Notes</a>

###9.1 Unfamiliar Queues
AHDispatch throttling only works with queues that have been created using AHDispatch's [`ah_throttle_queue_create()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_create) and [`ah_throttle_queue_new()`](http://rayascott.github.io/AHDispatch/index.html#//apple_ref/c/func/ah_throttle_queue_new) function calls. This is necessary to ensure that queues used with the API are serial in nature. Furthermore, AHDispatch does not work with any of the default queues that come with iOS. This includes the main queue and all global queues. 

###9.2 Time Values
Although all `seconds` paramater values are defined as type `double` in the interface, you can safely pass in values declared as type `NSTimeInterval`.

##10. <a name="contact">Contact</a>
AHDispatch is maintained by [Ray Scott](https://github.com/rayascott) ([@rayascott](http://www.twitter.com/rayascott)).


##11. <a name="license">License</a>
AHDispatch is available under the MIT license. For more information, see the included [LICENSE](./LICENSE) file.

