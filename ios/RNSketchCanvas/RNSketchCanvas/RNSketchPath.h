//
//  RNSketchPath.h
//  RNSketchCanvas
//
//  Created by terry on 03/08/2017.
//  Copyright © 2017 Terry. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RNSketchPoint.h"

@interface RNSketchPath : NSObject

@property (nonatomic, readonly) int pathId;
@property (nonatomic, readonly) CGFloat strokeWidth;
@property (nonatomic, readonly) UIColor* strokeColor;
@property (nonatomic, readonly) NSArray<RNSketchPoint*> *points;

- (instancetype)initWithId:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth;

- (RNSketchPoint*)addPoint:(CGPoint) point;

- (CGRect)drawLastPointInContext:(CGContextRef)context;
- (void)drawInContext:(CGContextRef)context pointIndex:(NSUInteger)pointIndex;

@end
