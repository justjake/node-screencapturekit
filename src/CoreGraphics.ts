export interface CGPoint {
  x: number;
  y: number;
}

export interface CGSize {
  width: number;
  height: number;
}

export interface CGRect {
  origin: CGPoint;
  size: CGSize;
}

export const CGRect = {
  containsPoint(rect: CGRect, point: CGPoint): boolean {
    return (
      point.x >= rect.origin.x &&
      point.x <= rect.origin.x + rect.size.width &&
      point.y >= rect.origin.y &&
      point.y <= rect.origin.y + rect.size.height
    );
  },

  area(rect: CGRect): number {
    return rect.size.width * rect.size.height;
  },
};
