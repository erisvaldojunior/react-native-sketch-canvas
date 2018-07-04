//
//  RNSketchPoint.m
//  RNSketchCanvas
//
//  Created by Jean Regisser on 04/07/2018.
//

#import "RNSketchPoint.h"

@interface RNSketchPoint ()

@property (nonatomic, readwrite) int pathId;
@property (nonatomic, readwrite) CGPoint point;
@property (nonatomic, readwrite) NSUInteger index;

@end

@implementation RNSketchPoint

- (instancetype)initWithId:(int)pathId point:(CGPoint)point index:(NSUInteger)index {
    if (self = [super init]) {
        _pathId = pathId;
        _point = point;
        _index = index;
    }
    return self;
}

@end
