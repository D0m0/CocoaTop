// Copyright (c) 2009-2011 Apple Inc. All rights reserved. 

#ifndef __XPC_H__
#define __XPC_H__

//#include "xpc/base.h"

typedef void *xpc_object_t;
typedef void *xpc_pipe_t;
typedef void *xpc_connection_t;

__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_NONNULL1
void
xpc_release(xpc_object_t object); 

__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
xpc_connection_t
xpc_dictionary_get_remote_connection(xpc_object_t xdict);

__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_NONNULL_ALL XPC_WARN_RESULT
const char *
xpc_connection_get_name(xpc_connection_t connection);

//XPC_EXPORT XPC_MALLOC XPC_WARN_RESULT XPC_NONNULL1
char* xpc_copy_description(xpc_object_t object);


__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_MALLOC XPC_RETURNS_RETAINED XPC_WARN_RESULT
xpc_object_t
xpc_dictionary_create(const char * const *keys, const xpc_object_t *values, size_t count);

__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);

__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_NONNULL1 XPC_NONNULL2
void
xpc_dictionary_set_fd(xpc_object_t xdict, const char *key, int fd);

__OSX_AVAILABLE_STARTING(__MAC_10_7, __IPHONE_5_0)
//XPC_EXPORT XPC_WARN_RESULT XPC_NONNULL_ALL
int64_t
xpc_dictionary_get_int64(xpc_object_t xdict, const char *key);

__attribute__((weak_import))
xpc_pipe_t xpc_pipe_create(const char *name, uint64_t flags);

__attribute__((weak_import))
void xpc_pipe_invalidate(xpc_pipe_t pipe);

__attribute__((weak_import))
int xpc_pipe_routine(xpc_pipe_t pipe, xpc_object_t message, xpc_object_t *reply);

//	struct _os_alloc_once_s {
//		long once;
//		u_int64_t *ptr;
//	};

//	extern struct _os_alloc_once_s _os_alloc_once_table[];

extern mach_port_t bootstrap_port;

xpc_pipe_t xpc_pipe_create_from_port(mach_port_t port, int flags);

#endif // __XPC_H__ 
