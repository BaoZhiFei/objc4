// TEST_CFLAGS -framework Foundation

#include "test.h"
#include <objc/objc-exception.h>
#include <Foundation/Foundation.h>

#if !defined(__OBJC2__)

int main()
{
    succeed(__FILE__);
}

#else

static int state;

@interface Foo : NSObject @end

@interface Foo (Unimplemented)
+(void)method;
@end


@implementation Foo

-(void)check { state++; }
+(void)check { testassert(!"caught class object, not instance"); }

static id exc;

static void handler(id unused, void *ctx) __attribute__((used));
static void handler(id unused __unused, void *ctx __unused)
{
    testassert(state == 3); state++;
}

+(BOOL) resolveClassMethod:(SEL)__unused name
{
    testassert(state == 1); state++;
#if !TARGET_OS_EMBEDDED  &&  !TARGET_OS_IPHONE  &&  !TARGET_IPHONE_SIMULATOR
    objc_addExceptionHandler(&handler, 0);
    testassert(state == 2); 
#else
    state++;  // handler would have done this
#endif
    state++;
    exc = [Foo new];
    @throw exc;
}


@end

int main()
{
#if TARGET_IPHONE_SIMULATOR
    testwarn("<rdar://problem/7965763> Simulator: cannot throw exceptions across objc_msgSend");
    succeed(__FILE__);
#else
    int i;

    // unwind exception and alt handler through objc_msgSend()

    NSAutoreleasePool *pool = [NSAutoreleasePool new];

    state = 0;
    for (i = 0; i < 100000; i++) {
        @try {
            testassert(state == 0); state++;
            [Foo method];
            testassert(0);
        } @catch (NSException *e) {
            testassert(0);
        } @catch (Foo *e) {
            testassert(e == exc);
            testassert(state == 4); state++;
            testassert(state == 5); [e check];  // state++
            [e release];
        } @catch (id e) {
            testassert(0);
        } @catch (...) {
            testassert(0);
        } @finally {
            testassert(state == 6); state++;
        }
        testassert(state == 7); state = 0;
    }

    [pool drain];

    succeed(__FILE__);
#endif
}

#endif
