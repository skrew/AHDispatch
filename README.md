AHDispatch
==========

AHDispatch provides queue throttling functionality for [Grand Central Dispatch](https://developer.apple.com/library/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html).

## Overview
===

`AHDispatch` consists of a number of interfaces similar to GCD that can be used to create throttled serial queues and dispatch asynchronous and syncronous block tasks to them. 

*But doesn't GCD come with the [`dispatch_after`](https://developer.apple.com/library/mac/documentation/Performance/Reference/GCD_libdispatch_Ref/Reference/reference.html#//apple_ref/c/func/dispatch_after) call?* Yes it does! And that's great if you need to hang around before your block executes. AHDispatch was born out of the need to comply to the rate limit rules of 3rd party API services. AHDispatch doesn't use `dispatch_after`, so that first block submitted to an empty queue executes without this constraint (but with the usual constraints of concurrent code executing on multicore hardware).

The execution of every block task submitted to a throttled serial queue invokes a private throttle block on completion that blocks the queue from executing the next user block in the queue until the throttle time as elapsed. 


