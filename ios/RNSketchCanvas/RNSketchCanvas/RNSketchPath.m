//
//  RNSketchPath.m
//  RNSketchCanvas
//
//  Created by terry on 03/08/2017.
//  Copyright © 2017 Terry. All rights reserved.
//

#import "RNSketchPath.h"
#import "Utility.h"

@interface RNSketchPath ()

@property (nonatomic, readwrite) int pathId;
@property (nonatomic, readwrite) CGFloat strokeWidth;
@property (nonatomic, readwrite) UIColor* strokeColor;
@property (nonatomic, readwrite) NSMutableArray<RNSketchPoint*> *points;

@end

@implementation RNSketchPath

- (instancetype)initWithId:(int) pathId strokeColor:(UIColor*) strokeColor strokeWidth:(int) strokeWidth {
    self = [super init];
    if (self) {
        _pathId = pathId;
        _strokeColor = strokeColor;
        _strokeWidth = strokeWidth;
        _points = [[NSMutableArray alloc] init];
    }
    return self;
}

- (RNSketchPoint*)addPoint:(CGPoint) point {
    RNSketchPoint *p = [[RNSketchPoint alloc] initWithId:_pathId point:point index:_points.count];
    [_points addObject:p];
    return p;
}

- (CGRect)updateRectForPoint:(CGPoint)point {
    CGRect updateRect;

    NSUInteger pointsCount = _points.count;
    if (pointsCount >= 3) {
        CGPoint a = _points[pointsCount - 3].point;
        CGPoint b = _points[pointsCount - 2].point;
        CGPoint c = point;
        CGPoint prevMid = midPoint(a, b);
        CGPoint currentMid = midPoint(b, c);

        updateRect = CGRectMake(prevMid.x, prevMid.y, 0, 0);
        updateRect = CGRectUnion(updateRect, CGRectMake(b.x, b.y, 0, 0));
        updateRect = CGRectUnion(updateRect, CGRectMake(currentMid.x, currentMid.y, 0, 0));
    } else if (pointsCount >= 2) {
        CGPoint a = _points[pointsCount - 2].point;
        CGPoint b = point;
        CGPoint mid = midPoint(a, b);

        updateRect = CGRectMake(a.x, a.y, 0, 0);
        updateRect = CGRectUnion(updateRect, CGRectMake(mid.x, mid.y, 0, 0));
    } else {
        updateRect = CGRectMake(point.x, point.y, 0, 0);
    }

    updateRect = CGRectInset(updateRect, -_strokeWidth * 2, -_strokeWidth * 2);

    return updateRect;
}

- (CGRect)drawLastPointInContext:(CGContextRef)context {
    NSUInteger pointsCount = _points.count;
    if (pointsCount < 1) {
        return CGRectZero;
    };

    NSUInteger index = pointsCount - 1;
    [self drawInContext:context pointIndex:index];

    RNSketchPoint *p = _points[index];
    return [self updateRectForPoint:p.point];
}

- (void)drawInContext:(CGContextRef)context pointIndex:(NSUInteger)pointIndex {
    NSUInteger pointsCount = _points.count;
    if (pointIndex >= pointsCount) {
        return;
    };

    BOOL isErase = [Utility isSameColor:_strokeColor color:[UIColor clearColor]];

    CGContextSetStrokeColorWithColor(context, _strokeColor.CGColor);
    CGContextSetLineWidth(context, _strokeWidth);
    CGContextSetLineCap(context, kCGLineCapRound);
    CGContextSetLineJoin(context, kCGLineJoinRound);
    CGContextSetBlendMode(context, isErase ? kCGBlendModeClear : kCGBlendModeNormal);
    CGContextBeginPath(context);

    if (pointsCount >= 3 && pointIndex >= 2) {
        CGPoint a = _points[pointIndex - 2].point;
        CGPoint b = _points[pointIndex - 1].point;
        CGPoint c = _points[pointIndex].point;
        CGPoint prevMid = midPoint(a, b);
        CGPoint currentMid = midPoint(b, c);

        // Draw a curve
        CGContextMoveToPoint(context, prevMid.x, prevMid.y);
        CGContextAddQuadCurveToPoint(context, b.x, b.y, currentMid.x, currentMid.y);
    } else if (pointsCount >= 2 && pointIndex >= 1) {
        CGPoint a = _points[pointIndex - 1].point;
        CGPoint b = _points[pointIndex].point;
        CGPoint mid = midPoint(a, b);

        // Draw a line to the middle of points a and b
        // This is so the next draw which uses a curve looks correct and continues from there
        CGContextMoveToPoint(context, a.x, a.y);
        CGContextAddLineToPoint(context, mid.x, mid.y);
    } else if (pointsCount >= 1) {
        CGPoint a = _points[pointIndex].point;

        // Draw a single point
        CGContextMoveToPoint(context, a.x, a.y);
        CGContextAddLineToPoint(context, a.x, a.y);
    }

    CGContextStrokePath(context);
}

@end
