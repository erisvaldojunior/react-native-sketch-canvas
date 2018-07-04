#import <UIKit/UIKit.h>

@class RCTEventDispatcher;

@interface RNSketchCanvas : UIView

@property (nonatomic, copy) RCTBubblingEventBlock onChange;

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher;

- (BOOL)openSketchFile:(NSString *)localFilePath;
- (void)newPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth;
- (void)addPath:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth points:(NSArray*) points;
- (void)deletePath:(int) pathId;
- (void)addPoint:(int) pathId x: (float)x y: (float)y;
- (void)endPath:(int) pathId;
- (void)clear;
- (void)saveImageOfType:(NSString*) type folder:(NSString*) folder filename:(NSString*) filename withTransparentBackground:(BOOL) transparent;
- (NSString*) transferToBase64OfType: (NSString*) type withTransparentBackground: (BOOL) transparent;

@end
