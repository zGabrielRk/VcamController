/**
 * VcamTweak — Frame replacement tweak
 *
 * Hooks AVCaptureVideoDataOutput via delegate proxy:
 * intercepts camera frames and substitutes with frames
 * from /var/jb/var/mobile/Library/temp.mov
 *
 * Injects into all UIKit apps so it works in Camera,
 * FaceTime, Instagram, Snapchat, etc.
 */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kTempMovPath    = @"/var/jb/var/mobile/Library/temp.mov";
static NSString *const kMirrorMarkPath = @"/var/jb/var/mobile/Library/vcam_is_mirrored_mark";

// ---------------------------------------------------------------------------
// MARK: - VcamEngine  (video reader + frame processing)
// ---------------------------------------------------------------------------

@interface VcamEngine : NSObject

+ (instancetype)shared;

@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL isMirrored;

/// Returns the next fake CMSampleBufferRef.
/// If VCam is disabled or the read fails, returns NULL.
/// Caller must CFRelease the returned buffer.
- (CMSampleBufferRef)nextFakeBufferMatchingTiming:(CMSampleBufferRef)original;

/// Force-reload state from disk (call after writing new temp.mov)
- (void)reload;

@end

@implementation VcamEngine {
    AVAssetReader          *_reader;
    AVAssetReaderTrackOutput *_trackOutput;
    CIContext              *_ciContext;
    NSDate                 *_lastFileDate;
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

- (void)reload {
    NSFileManager *fm = [NSFileManager defaultManager];
    _isEnabled = [fm fileExistsAtPath:kTempMovPath];
    _isMirrored = [fm fileExistsAtPath:kMirrorMarkPath];
    _reader = nil;
    _trackOutput = nil;
    _lastFileDate = nil;

    if (!_isEnabled) return;

    NSDictionary *attrs = [fm attributesOfItemAtPath:kTempMovPath error:nil];
    _lastFileDate = attrs[NSFileModificationDate];

    NSURL *url = [NSURL fileURLWithPath:kTempMovPath];
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
    if (mod && _lastFileDate && [mod compare:_lastFileDate] != NSOrderedSame) {
        [self reload];
    }
}

- (CMSampleBufferRef)nextFakeBufferMatchingTiming:(CMSampleBufferRef)original {
    [self _checkFileChanged];

    if (!_isEnabled || !_reader || !_trackOutput) return NULL;

    _isMirrored = [[NSFileManager defaultManager] fileExistsAtPath:kMirrorMarkPath];

    CMSampleBufferRef sample = [_trackOutput copyNextSampleBuffer];
    if (!sample || _reader.status != AVAssetReaderStatusReading) {
        [self reload];
        sample = [_trackOutput copyNextSampleBuffer];
        if (!sample) return NULL;
    }

    // Apply timing from the original live frame so the pipeline stays happy
    CMSampleTimingInfo timing;
    CMSampleBufferGetSampleTimingInfo(original, 0, &timing);

    // If no mirror needed, return as-is
    if (!_isMirrored) return sample;

    // Apply horizontal flip via CoreImage
    CVImageBufferRef imgBuf = CMSampleBufferGetImageBuffer(sample);
    if (!imgBuf) return sample;

    size_t w = CVPixelBufferGetWidth(imgBuf);
    size_t h = CVPixelBufferGetHeight(imgBuf);

    CIImage *ci = [CIImage imageWithCVImageBuffer:imgBuf];
    ci = [ci imageByApplyingTransform:CGAffineTransformMakeScale(-1, 1)];

    CVPixelBufferRef mirrorBuf = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, NULL, &mirrorBuf);
    if (!mirrorBuf) return sample;

    [_ciContext render:ci toCVPixelBuffer:mirrorBuf];

    CMVideoFormatDescriptionRef fmt = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, mirrorBuf, &fmt);

    CMSampleBufferRef mirrored = NULL;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, mirrorBuf,
                                       true, NULL, NULL, fmt, &timing, &mirrored);
    if (fmt)       CFRelease(fmt);
    if (mirrorBuf) CVPixelBufferRelease(mirrorBuf);
    CFRelease(sample);

    return mirrored;
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

    CMSampleBufferRef fake = [[VcamEngine shared] nextFakeBufferMatchingTiming:sampleBuffer];
    CMSampleBufferRef toDeliver = fake ? fake : sampleBuffer;

    [_original captureOutput:output
       didOutputSampleBuffer:toDeliver
              fromConnection:connection];

    if (fake) CFRelease(fake);
}

// Forward any other delegate methods
- (BOOL)respondsToSelector:(SEL)sel {
    return [_original respondsToSelector:sel] || [super respondsToSelector:sel];
}

- (id)forwardingTargetForSelector:(SEL)sel {
    return _original;
}

@end

// ---------------------------------------------------------------------------
// MARK: - Hook AVCaptureVideoDataOutput.setSampleBufferDelegate:queue:
// ---------------------------------------------------------------------------

static IMP orig_setSampleBufferDelegate = NULL;

static void hooked_setSampleBufferDelegate(AVCaptureVideoDataOutput *self,
                                            SEL sel,
                                            id<AVCaptureVideoDataOutputSampleBufferDelegate> delegate,
                                            dispatch_queue_t queue) {
    if (delegate && ![delegate isKindOfClass:[VcamDelegateProxy class]]) {
        VcamDelegateProxy *proxy = [VcamDelegateProxy proxyFor:delegate];
        ((void (*)(id, SEL, id, dispatch_queue_t))orig_setSampleBufferDelegate)(self, sel, proxy, queue);
    } else {
        ((void (*)(id, SEL, id, dispatch_queue_t))orig_setSampleBufferDelegate)(self, sel, delegate, queue);
    }
}

// ---------------------------------------------------------------------------
// MARK: - Constructor
// ---------------------------------------------------------------------------

__attribute__((constructor))
static void VcamTweakInit(void) {
    @autoreleasepool {
        // Ensure vcam directory exists
        NSString *dir = @"/var/jb/var/mobile/Library";
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir
          withIntermediateDirectories:YES
                           attributes:nil
                                error:nil];
        }

        // Hook AVCaptureVideoDataOutput
        Class cls = [AVCaptureVideoDataOutput class];
        SEL sel = @selector(setSampleBufferDelegate:queue:);
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            orig_setSampleBufferDelegate = method_setImplementation(m, (IMP)hooked_setSampleBufferDelegate);
        }
    }
}
