import { CGPoint, CGRect } from "./CoreGraphics";
import {
  SCContentFilter,
  SCSharableContent,
  SCStreamConfiguration,
  SCWindow,
  captureImage,
} from "./ScreenCaptureKit";

export function getMousePosition(): CGPoint {
  throw new Error("not implemented");
}

export async function getWindowsUnderPoint(
  point: CGPoint
): Promise<SCWindow[]> {
  const content = await SCSharableContent.getSharableContent({
    onScreenWindowsOnly: true,
  });

  return content.windows
    .filter((window) => CGRect.containsPoint(window.frame, point))
    .sort((a, b) => b.windowLayer - a.windowLayer);
}

export async function captureWindow(args: {
  window: SCWindow;
  ignoreShadows: boolean;
}) {
  const filter = SCContentFilter.forWindow({
    window: args.window,
    includeWindowShadow: !args.ignoreShadows
  });
  return await captureImage(filter);
}
