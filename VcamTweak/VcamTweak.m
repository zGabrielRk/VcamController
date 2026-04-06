/**
 * VcamTweak — Frame replacement tweak
 *
 * Strategy:
 *  1. ObjC hook on AVCaptureVideoDataOutput setSampleBufferDelegate:queue:
 *     catches apps that process frames explicitly (Instagram, FaceTime, etc.)
 *
 *  2. fishhook on CMSampleBufferGetImageBuffer (C function in CoreMedia)
 *     catches Camera.app and any other pipeline that reads pixel buffers
 *     directly, bypassing the delegate path.
 *
 * Video source: /var/mobile/Library/VCam/temp.mov
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include "fishhook.h"

static NSString *const kTempMovPath    = @"/var/mobile/Library/VCam/temp.mov";
static NSString *const kMirrorMarkPath = @"/var/mobile/Library/VCam/vcam_is_mirrored_mark";

// ---------------------------------------------------------------------------
// MARK: - VcamEngine  (video reader + frame cache)
// ---------------------------------------------------------------------------

@interface VcamEngine : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isMirrored;
- (CVPixelBufferRef)nextFakePixelBufferWithSize:(CGSize)size CF_RETURNS_RETAINED;
- (CMSampleBufferRef)nextFakeBufferMatchingTiming:(CMSampleBufferRef)original CF_RETURNS_RETAINED;
- (void)reload;
@end

@implementation VcamEngine {
    AVAssetReader            *_reader;
    AVAssetReaderTrackOutput *_trackOutput;
    CIContext                *_ciContext;
    NSDate                   *_lastFileDate;
    CVPixelBufferRef          _lastPixelBuf;   // reused across fishhook calls
}

+ (instancetype)shared {
    static VcamEngine *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [VcamEngine new]; });
    return s;
}

- (instancetype)init {
    if (self = [super init]) {
        _ciContext = [CIContext contextWithOptions:nil];
        [self reload];
    }
    return self;
}

- (void)_releaseLastPixelBuf {
    if (_lastPixelBuf) {
        CVPixelBufferRelease(_lastPixelBuf);
        _lastPixelBuf = NULL;
    }
}

- (void)reload {
    NSFileManager *fm = [NSFileManager defaultManager];
    _isEnabled  = [fm fileExistsAtPath:kTempMovPath];
    _isMirrored = [fm fileExistsAtPath:kMirrorMarkPath];
    _reader      = nil;
    _trackOutput = nil;
    _lastFileDate = nil;
    [self _releaseLastPixelBuf];

    if (!_isEnabled) return;

    NSDictionary *attrs = [fm attributesOfItemAtPath:kTempMovPath error:nil];
    _lastFileDate = attrs[NSFileModificationDate];

    NSURL *url       = [NSURL fileURLWithPath:kTempMovPath];
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetTrack *track = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!track) { _isEnabled = NO; return; }

    NSDictionary *settings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    _trackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track
                                                              outputSettings:settings];
    NSError *err;
    _reader = [AVAssetReader assetReaderWithAsset:asset error:&err];
    if (!_reader || err) { _isEnabled = NO; return; }

    [_reader addOutput:_trackOutput];
    [_reader startReading];
}

- (void)_checkFileChanged {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL exists = [fm fileExistsAtPath:kTempMovPath];
    if (exists != _isEnabled) { [self reload]; return; }
    if (!exists) return;
    NSDictionary *attrs = [fm attributesOfItemAtPath:kTempMovPath error:nil];
    NSDate *mod = attrs[NSFileModificationDate];
    if (mod && _lastFileDate && [mod compare:_lastFileDate] != NSOrderedSame) [self reload];
}

/// Returns next frame pixel buffer (32BGRA), scaled to `size` if needed.
/// Caller must CVPixelBufferRelease.
- (CVPixelBufferRef)nextFakePixelBufferWithSize:(CGSize)size {
    [self _checkFileChanged];
    if (!_isEnabled || !_reader || !_trackOutput) return NULL;

    _isMirrored = [[NSFileManager defaultManager] fileExistsAtPath:kMirrorMarkPath];

    CMSampleBufferRef sample = [_trackOutput copyNextSampleBuffer];
    if (!sample || _reader.status != AVAssetReaderStatusReading) {
        [self reload];
        sample = [_trackOutput copyNextSampleBuffer];
        if (!sample) return NULL;
    }

    CVImageBufferRef srcBuf = CMSampleBufferGetImageBuffer(sample);
    // NOTE: at this point srcBuf comes from our own AVAssetReader,
    // not from the live camera — safe to call the real function here.

    if (!srcBuf) { CFRelease(sample); return NULL; }

    size_t sw = CVPixelBufferGetWidth(srcBuf);
    size_t sh = CVPixelBufferGetHeight(srcBuf);
    size_t dw = (size.width  > 0) ? (size_t)size.width  : sw;
    size_t dh = (size.height > 0) ? (size_t)size.height : sh;

    CIImage *ci = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)srcBuf];

    // Scale to match destination size
    if (sw != dw || sh != dh) {
        CGFloat sx = (CGFloat)dw / sw;
        CGFloat sy = (CGFloat)dh / sh;
        ci = [ci imageByApplyingTransform:CGAffineTransformMakeScale(sx, sy)];
    }

    // Mirror horizontally if requested
    if (_isMirrored) {
        ci = [ci imageByApplyingTransform:CGAffineTransformMakeScale(-1, 1)];
        ci = [ci imageByApplyingTransform:CGAffineTransformMakeTranslation(dw, 0)];
    }

    CVPixelBufferRef out = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, dw, dh, kCVPixelFormatType_32BGRA, NULL, &out);
    if (out) [_ciContext render:ci toCVPixelBuffer:out];

    CFRelease(sample);
    return out;  // caller must release
}

/// For delegate-proxy path: wraps pixel buffer in a new CMSampleBuffer with original timing.
- (CMSampleBufferRef)nextFakeBufferMatchingTiming:(CMSampleBufferRef)original {
    CVImageBufferRef origImg = CMSampleBufferGetImageBuffer(original);
    CGSize size = CGSizeZero;
    if (origImg) {
        size = CGSizeMake(CVPixelBufferGetWidth(origImg), CVPixelBufferGetHeight(origImg));
    }

    CVPixelBufferRef pix = [self nextFakePixelBufferWithSize:size];
    if (!pix) return NULL;

    CMSampleTimingInfo timing;
    CMSampleBufferGetSampleTimingInfo(original, 0, &timing);

    CMVideoFormatDescriptionRef fmt = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pix, &fmt);

    CMSampleBufferRef result = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pix,
                                       true, NULL, NULL, fmt, &timing, &result);
    if (fmt) CFRelease(fmt);
    CVPixelBufferRelease(pix);
    return result;
}

@end

// ---------------------------------------------------------------------------
// MARK: - VcamDelegateProxy
// ---------------------------------------------------------------------------

@interface VcamDelegateProxy : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
+ (instancetype)proxyFor:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate;
@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> original;
@end

@implementation VcamDelegateProxy

+ (instancetype)proxyFor:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate {
    VcamDelegateProxy *p = [VcamDelegateProxy new];
    p.original = delegate;
    return p;
}

- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = self.original;
    if (!delegate) return;

    CMSampleBufferRef fake = [[VcamEngine shared] nextFakeBufferMatchingTiming:sampleBuffer];
    CMSampleBufferRef toDeliver = fake ? fake : sampleBuffer;
    [delegate captureOutput:output didOutputSampleBuffer:toDeliver fromConnection:connection];
    if (fake) CFRelease(fake);
}

- (BOOL)respondsToSelector:(SEL)sel {
    return [self.original respondsToSelector:sel] || [super respondsToSelector:sel];
}

- (id)forwardingTargetForSelector:(SEL)sel {
    return self.original;
}

@end

// ---------------------------------------------------------------------------
// MARK: - fishhook: CMSampleBufferGetImageBuffer
//
// This intercepts ALL camera pipelines — including Camera.app which doesn't
// use AVCaptureVideoDataOutput. When any code asks for the pixel buffer from
// a camera sample buffer, we return a fake frame instead.
// ---------------------------------------------------------------------------

static CVImageBufferRef (*orig_CMSampleBufferGetImageBuffer)(CMSampleBufferRef) = NULL;

static CVImageBufferRef hooked_CMSampleBufferGetImageBuffer(CMSampleBufferRef sbuf) {
    // Only replace if VCam is active
    VcamEngine *engine = [VcamEngine shared];
    if (!engine.isEnabled) {
        return orig_CMSampleBufferGetImageBuffer(sbuf);
    }

    // Detect if this sample buffer came from a live camera source by checking
    // whether it has a valid image buffer AND came from a camera session.
    // We use a lightweight check: if there's a format description whose media
    // subtype looks like a camera (kCVPixelFormatType common values), replace it.
    CVImageBufferRef real = orig_CMSampleBufferGetImageBuffer(sbuf);
    if (!real) return real;

    // Only intercept pixel buffers (IOSurface-backed, from camera hardware)
    // Skip our own AVAssetReader-produced buffers to avoid recursion.
    // Heuristic: camera buffers are usually IOSurface-backed.
    if (!CVPixelBufferGetIOSurface((CVPixelBufferRef)real)) {
        return real;  // not a camera buffer, return as-is
    }

    CGSize size = CGSizeMake(CVPixelBufferGetWidth(real), CVPixelBufferGetHeight(real));
    CVPixelBufferRef fake = [engine nextFakePixelBufferWithSize:size];
    if (!fake) return real;

    // Store in a thread-local so it's released on next call (avoid leak)
    // Simple approach: keep one retained fake buf per call — caller doesn't
    // release CVPixelBufferRef from CMSampleBufferGetImageBuffer (it's borrowed).
    // We need to keep it alive until the next frame. Use a static with lock.
    static CVPixelBufferRef sPrevFake = NULL;
    static OSSpinLock sLock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&sLock);
    CVPixelBufferRef prev = sPrevFake;
    sPrevFake = fake;  // retain is already held from nextFakePixelBufferWithSize
    OSSpinLockUnlock(&sLock);
    if (prev) CVPixelBufferRelease(prev);

    return (CVImageBufferRef)fake;
}

// ---------------------------------------------------------------------------
// MARK: - ObjC hook: AVCaptureVideoDataOutput setSampleBufferDelegate:queue:
// ---------------------------------------------------------------------------

static IMP orig_setSampleBufferDelegate = NULL;

static void hooked_setSampleBufferDelegate(AVCaptureVideoDataOutput *target,
                                            SEL sel,
                                            id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate,
                                            dispatch_queue_t queue) {
    typedef void (*SetDelegateFn)(id, SEL, id, dispatch_queue_t);
    SetDelegateFn fn = (SetDelegateFn)orig_setSampleBufferDelegate;
    if (delegate && ![delegate isKindOfClass:[VcamDelegateProxy class]]) {
        VcamDelegateProxy *proxy = [VcamDelegateProxy proxyFor:delegate];
        fn(target, sel, proxy, queue);
    } else {
        fn(target, sel, delegate, queue);
    }
}

// ---------------------------------------------------------------------------
// MARK: - ObjC hook: AVCaptureSession startRunning (catch pre-set delegates)
// ---------------------------------------------------------------------------

static IMP orig_startRunning = NULL;

static void hooked_startRunning(AVCaptureSession *self, SEL sel) {
    @autoreleasepool {
        for (AVCaptureOutput *output in self.outputs) {
            if (![output isKindOfClass:[AVCaptureVideoDataOutput class]]) continue;
            AVCaptureVideoDataOutput *vdo = (AVCaptureVideoDataOutput *)output;
            id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = vdo.sampleBufferDelegate;
            if (delegate && ![delegate isKindOfClass:[VcamDelegateProxy class]]) {
                dispatch_queue_t q = vdo.sampleBufferCallbackQueue ?: dispatch_get_main_queue();
                VcamDelegateProxy *proxy = [VcamDelegateProxy proxyFor:delegate];
                typedef void (*SetDelegateFn)(id, SEL, id, dispatch_queue_t);
                SetDelegateFn fn = (SetDelegateFn)orig_setSampleBufferDelegate;
                fn(vdo, @selector(setSampleBufferDelegate:queue:), proxy, q);
            }
        }
    }
    ((void(*)(id,SEL))orig_startRunning)(self, sel);
}

static IMP orig_startRunningCompletion = NULL;

static void hooked_startRunningCompletion(AVCaptureSession *self, SEL sel, void(^completion)(BOOL, NSError*)) {
    @autoreleasepool {
        for (AVCaptureOutput *output in self.outputs) {
            if (![output isKindOfClass:[AVCaptureVideoDataOutput class]]) continue;
            AVCaptureVideoDataOutput *vdo = (AVCaptureVideoDataOutput *)output;
            id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate = vdo.sampleBufferDelegate;
            if (delegate && ![delegate isKindOfClass:[VcamDelegateProxy class]]) {
                dispatch_queue_t q = vdo.sampleBufferCallbackQueue ?: dispatch_get_main_queue();
                VcamDelegateProxy *proxy = [VcamDelegateProxy proxyFor:delegate];
                typedef void (*SetDelegateFn)(id, SEL, id, dispatch_queue_t);
                SetDelegateFn fn = (SetDelegateFn)orig_setSampleBufferDelegate;
                fn(vdo, @selector(setSampleBufferDelegate:queue:), proxy, q);
            }
        }
    }
    ((void(*)(id,SEL,void(^)(BOOL,NSError*)))orig_startRunningCompletion)(self, sel, completion);
}

// ---------------------------------------------------------------------------
// MARK: - Constructor
// ---------------------------------------------------------------------------

__attribute__((constructor))
static void VcamTweakInit(void) {
    @autoreleasepool {
        // Ensure vcam directory exists (accessible by mobile user)
        NSString *dir = @"/var/mobile/Library/VCam";
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
        }

        // ── fishhook: intercept CMSampleBufferGetImageBuffer (C function) ──
        // This catches Camera.app and all other pipelines at the CoreMedia level.
        struct rebinding rb = {
            "CMSampleBufferGetImageBuffer",
            (void *)hooked_CMSampleBufferGetImageBuffer,
            (void **)&orig_CMSampleBufferGetImageBuffer
        };
        rebind_symbols(&rb, 1);

        // ── ObjC swizzle: AVCaptureVideoDataOutput ──
        Class vdoCls = [AVCaptureVideoDataOutput class];
        Method m = class_getInstanceMethod(vdoCls, @selector(setSampleBufferDelegate:queue:));
        if (m) orig_setSampleBufferDelegate = method_setImplementation(m, (IMP)hooked_setSampleBufferDelegate);

        // ── ObjC swizzle: AVCaptureSession startRunning ──
        Class sesCls = [AVCaptureSession class];
        Method m2 = class_getInstanceMethod(sesCls, @selector(startRunning));
        if (m2) orig_startRunning = method_setImplementation(m2, (IMP)hooked_startRunning);

        SEL startCompSel = NSSelectorFromString(@"startRunningWithCompletionHandler:");
        Method m3 = class_getInstanceMethod(sesCls, startCompSel);
        if (m3) orig_startRunningCompletion = method_setImplementation(m3, (IMP)hooked_startRunningCompletion);
    }
}
