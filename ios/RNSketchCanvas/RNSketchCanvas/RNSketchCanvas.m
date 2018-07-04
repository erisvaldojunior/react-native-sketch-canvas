#import "RNSketchCanvasManager.h"
#import "RNSketchCanvas.h"
#import "RNSketchPath.h"
#import "RNSketchPoint.h"
#import <React/RCTEventDispatcher.h>
#import <React/RCTView.h>
#import <React/UIView+React.h>
#import "Utility.h"

@implementation RNSketchCanvas
{
    RCTEventDispatcher *_eventDispatcher;
    NSMutableDictionary<NSNumber*,RNSketchPath*> *_pathsById;
    NSMutableArray<RNSketchPoint*> *_points;

    CGSize _lastSize;

    CGContextRef _drawingContext;
    CGImageRef _frozenImage;
    BOOL _needsFullRedraw;

    UIImage *_backgroundImage;
    UIImage *_backgroundImageScaled;

}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    self = [super init];
    if (self) {
        _eventDispatcher = eventDispatcher;
        _pathsById = [NSMutableDictionary new];
        _points = [NSMutableArray new];
        _needsFullRedraw = YES;

        self.backgroundColor = [UIColor clearColor];
        self.clearsContextBeforeDrawing = YES;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();

    CGRect bounds = self.bounds;

    if (_needsFullRedraw) {
        [self setFrozenImageNeedsUpdate];
        CGContextClearRect(_drawingContext, bounds);
        for (RNSketchPoint *point in _points) {
            RNSketchPath *path = [_pathsById objectForKey:@(point.pathId)];
            [path drawInContext:_drawingContext pointIndex:point.index];
        }
        _needsFullRedraw = NO;
    }

    if (!_frozenImage) {
        _frozenImage = CGBitmapContextCreateImage(_drawingContext);
    }

    if (_backgroundImage) {
        if (!_backgroundImageScaled) {
            _backgroundImageScaled = [self scaleImage:_backgroundImage toSize:bounds.size];
        }

        [_backgroundImageScaled drawInRect:bounds];
    }

    if (_frozenImage) {
        CGContextDrawImage(context, bounds, _frozenImage);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];

    if (!CGSizeEqualToSize(self.bounds.size, _lastSize)) {
        _lastSize = self.bounds.size;
        CGContextRelease(_drawingContext);
        _drawingContext = nil;
        [self createDrawingContext];
        _needsFullRedraw = YES;
        _backgroundImageScaled = nil;
        [self setNeedsDisplay];
    }
}

- (void)createDrawingContext {
    CGFloat scale = self.window.screen.scale;
    CGSize size = self.bounds.size;
    size.width *= scale;
    size.height *= scale;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    _drawingContext = CGBitmapContextCreate(nil, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(colorSpace);

    CGContextConcatCTM(_drawingContext, CGAffineTransformMakeScale(scale, scale));
}

- (void)setFrozenImageNeedsUpdate {
    CGImageRelease(_frozenImage);
    _frozenImage = nil;
}

- (BOOL)openSketchFile:(NSString *)localFilePath {
    if (localFilePath) {
        UIImage *image = [UIImage imageWithContentsOfFile:localFilePath];
        if(image) {
            _backgroundImage = image;
            _backgroundImageScaled = nil;
            [self setNeedsDisplay];

            return YES;
        }
    }
    return NO;
}

- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth {
    RNSketchPath *path = [[RNSketchPath alloc]
                          initWithId: pathId
                          strokeColor: strokeColor
                          strokeWidth: strokeWidth];
    [_pathsById setObject:path forKey:@(pathId)];
}

- (void) addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points {
    if ([_pathsById objectForKey:@(pathId)]) {
        return;
    }

    RNSketchPath *path = [[RNSketchPath alloc] initWithId: pathId
                                              strokeColor: strokeColor
                                              strokeWidth: strokeWidth];
    [_pathsById setObject:path forKey:@(pathId)];

    for (NSValue *pointValue in points) {
        CGPoint point = pointValue.CGPointValue;
        [self addPoint:pathId x:point.x y:point.y];
    }

    [self notifyPathsUpdate];
}

- (void)deletePath:(int) pathId {
    if (![_pathsById objectForKey:@(pathId)]) {
        return;
    }

    [_pathsById removeObjectForKey:@(pathId)];

    // Remove all points with this pathId
    NSMutableArray *newPoints = [NSMutableArray new];
    for (RNSketchPoint *point in _points) {
        if (point.pathId != pathId) {
            [newPoints addObject:point];
        }
    }
    _points = newPoints;

    _needsFullRedraw = YES;
    [self setNeedsDisplay];
    [self notifyPathsUpdate];
}

- (void)addPoint:(int) pathId x: (float)x y: (float)y {
    RNSketchPath *path = [_pathsById objectForKey:@(pathId)];
    CGPoint newPoint = CGPointMake(x, y);
    RNSketchPoint *p = [path addPoint: newPoint];
    [_points addObject:p];

    CGRect updateRect = [path drawLastPointInContext:_drawingContext];

    [self setFrozenImageNeedsUpdate];
    [self setNeedsDisplayInRect:updateRect];
}

- (void)endPath:(int) pathId {
    // Nothing to do
}

- (void) clear {
    [_pathsById removeAllObjects];
    [_points removeAllObjects];
    _needsFullRedraw = YES;
    [self setNeedsDisplay];
    [self notifyPathsUpdate];
}

- (UIImage*)createImageWithTransparentBackground: (BOOL) transparent {
    CGRect rect = self.bounds;
    UIGraphicsBeginImageContextWithOptions(rect.size, !transparent, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!transparent) {
        CGContextSetRGBFillColor(context, 1.0f, 1.0f, 1.0f, 1.0f);
        CGContextFillRect(context, rect);
    }
    if (_backgroundImage) {
        [_backgroundImage drawInRect:CGRectMake(0.f, 0.f, rect.size.width, rect.size.height)];
    }
    CGContextDrawImage(context, rect, _frozenImage);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (_backgroundImage) {
        CGSize bgImageSize = _backgroundImage.size;
        UIGraphicsBeginImageContextWithOptions(bgImageSize, NO, 0);
        [img drawInRect:CGRectMake(0.f, 0.f, bgImageSize.width, bgImageSize.height)];
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }

    return img;
}

- (void)saveImageOfType:(NSString*) type folder:(NSString*) folder filename:(NSString*) filename withTransparentBackground:(BOOL) transparent {
    UIImage *img = [self createImageWithTransparentBackground:transparent];

    if (folder != nil && filename != nil) {
        NSURL *tempDir = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent: folder];
        NSError * error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:[tempDir path]
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
        if (error == nil) {
            NSURL *fileURL = [[tempDir URLByAppendingPathComponent: filename] URLByAppendingPathExtension: type];
            NSData *imageData = [self getImageData:img type:type];
            [imageData writeToURL:fileURL atomically:YES];

            if (_onChange) {
                _onChange(@{ @"success": @YES, @"path": [fileURL path]});
            }
        } else {
            if (_onChange) {
                _onChange(@{ @"success": @NO, @"path": [NSNull null]});
            }
        }
    } else {
        if ([type isEqualToString: @"png"]) {
            img = [UIImage imageWithData: UIImagePNGRepresentation(img)];
        }
        UIImageWriteToSavedPhotosAlbum(img, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    }
}

- (UIImage *)scaleImage:(UIImage *)originalImage toSize:(CGSize)size
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, size.width, size.height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
    CGContextClearRect(context, CGRectMake(0, 0, size.width, size.height));
    
    if (originalImage.imageOrientation == UIImageOrientationRight) {
        CGContextRotateCTM(context, -M_PI_2);
        CGContextTranslateCTM(context, -size.height, 0.0f);
        CGContextDrawImage(context, CGRectMake(0, 0, size.height, size.width), originalImage.CGImage);
    } else {
        CGContextDrawImage(context, CGRectMake(0, 0, size.width, size.height), originalImage.CGImage);
    }
    
    CGImageRef scaledImage = CGBitmapContextCreateImage(context);
    CGColorSpaceRelease(colorSpace);
    CGContextRelease(context);
    
    UIImage *image = [UIImage imageWithCGImage:scaledImage];
    CGImageRelease(scaledImage);
    
    return image;
}

- (NSString*) transferToBase64OfType: (NSString*) type withTransparentBackground: (BOOL) transparent {
    UIImage *img = [self createImageWithTransparentBackground:transparent];
    NSData *data = [self getImageData:img type:type];
    return [data base64EncodedStringWithOptions: NSDataBase64Encoding64CharacterLineLength];
}

- (NSData*)getImageData:(UIImage*)img type:(NSString*) type {
    NSData *data;
    if ([type isEqualToString: @"jpg"]) {
        data = UIImageJPEGRepresentation(img, 1.0);
    } else {
        data = UIImagePNGRepresentation(img);
    }
    return data;
}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo: (void *) contextInfo {
    if (_onChange) {
        _onChange(@{ @"success": error != nil ? @NO : @YES });
    }
}

- (void)notifyPathsUpdate {
    if (_onChange) {
        _onChange(@{ @"pathsUpdate": @(_pathsById.count) });
    }
}

@end
