//
//  RNSketchPoint.h
//  RNSketchCanvas
//
//  Created by Jean Regisser on 04/07/2018.
//

#import <Foundation/Foundation.h>

@interface RNSketchPoint : NSObject

@property (nonatomic, readonly) int pathId;
@property (nonatomic, readonly) CGPoint point;
@property (nonatomic, readonly) NSUInteger index;

- (instancetype)initWithId:(int)pathId point:(CGPoint)point index:(NSUInteger)index;

@end
