import { config } from "process";
import { CGPoint } from "./CoreGraphics";
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
    .filter((window) => window.frame.contains(point))
    .sort((a, b) => b.windowLayer - a.windowLayer);
}

export async function captureWindow(args: {
  window: SCWindow;
  ignoreShadows: boolean;
}) {
  const filter = SCContentFilter.forWindow(args.window);
  const streamConfig = SCStreamConfiguration.create({
    ignoreShadowsDisplay: args.ignoreShadows,
    ignoreGlobalClipSingleWindow: args.ignoreShadows,
  });
  return await captureImage(filter, streamConfig);
}
