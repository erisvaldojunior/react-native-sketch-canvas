package com.terrylinla.rnsketchcanvas;

import android.graphics.PointF;

public class SketchPoint {
    public final int pathId, index;
    public final PointF point;

    public SketchPoint(int pathId, PointF point, int index) {
        this.pathId = pathId;
        this.point = point;
        this.index = index;
    }
}
