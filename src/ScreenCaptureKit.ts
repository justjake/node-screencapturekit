import { CGRect, CGSize } from "./CoreGraphics";
import {
  createStreamConfiguration as RAW_createStreamConfiguration,
  getSharableContent as RAW_getSharableContent,
  createContentFilter as RAW_createContentFilter,
  captureImage as RAW_captureImage,
  pickContentFilter as RAW_pickContentFilter,
  SCContentSharingPickerMode as RAW_SCContentSharingPickerMode,
} from "./.build/Module.node";

export interface SCDisplay {
  readonly displayID: string;
  readonly frame: CGRect;
  readonly width: number;
  readonly height: number;
}

export interface SCRunningApplication {
  readonly processID: number;
  readonly bundleIdentifier: string;
  readonly applicationName: string;
}

export interface SCWindow {
  readonly windowID: number;
  readonly frame: CGRect;
  /** The layer of the window relative to other windows. */
  readonly windowLayer: number;
  /** A boolean value that indicates whether the window is on screen.  */
  readonly isOnScreen: boolean;
}

export interface SCSharableContent {
  readonly windows: SCWindow[];
  readonly displays: SCDisplay[];
  readonly applications: SCRunningApplication[];
}

export const SCSharableContent = {
  async getSharableContent(args: {
    includeDesktopWindows?: boolean;
    onScreenWindowsOnly?: boolean;
    onScreenWindowsOnlyAbove?: SCWindow;
    onScreenWindowsOnlyBelow?: SCWindow;
  }): Promise<SCSharableContent> {
    return RAW_getSharableContent(args);
  },
} as const;

interface SCContentFilterDisplayBase {
  display: SCDisplay;
  excludeMenuBar?: boolean;
}

interface SCContentFilterDisplayWindows extends SCContentFilterDisplayBase {
  windows: SCWindow[];
}

interface SCContentFilterDisplayExcludingWindows
  extends SCContentFilterDisplayBase {
  excludingWindows: SCWindow[];
}

interface SCContentFilterDisplayIncludingApps
  extends SCContentFilterDisplayBase {
  includingApplications: SCRunningApplication[];
  excludingWindows?: SCWindow[];
}

interface SCContentFilterDisplayExcludingApps
  extends SCContentFilterDisplayBase {
  excludingApplications: SCRunningApplication[];
  windows?: SCWindow[];
}

interface SCContentFilter {
  readonly contentRect: CGRect;
  readonly pointPixelScale: number;
  readonly scaledContentSize: CGSize;
  readonly includeMenuBar?: boolean;
  createStreamConfiguration(): SCStreamConfiguration;
}

export const SCContentFilter = {
  forWindow(args: {
    window: SCWindow;
    includeWindowShadow?: boolean;
  }): SCContentFilter {
    return RAW_createContentFilter(args);
  },

  forDisplay(
    args:
      | SCContentFilterDisplayWindows
      | SCContentFilterDisplayExcludingWindows
      | SCContentFilterDisplayIncludingApps
      | SCContentFilterDisplayExcludingApps
  ): SCContentFilter {
    return RAW_createContentFilter(args);
  },
};

type TODO = "todo";
type CFString = TODO;
type CGColor = TODO;
type OSType = TODO;
type CMTime = TODO;

interface SCStreamConfiguration {
  width: number;
  height: number;
  size: CGSize; // width and height
  scalesToFit: boolean;
  sourceRect: CGRect;
  destinationRect: CGRect;
  preservesAspectRatio: boolean;
  /*
BGRA
Packed little endian ARGB8888.

l10r
Packed little endian ARGB2101010.

420v
Two-plane “video” range YCbCr 4:2:0.

420f
Two-plane “full” range YCbCr 4:2:0.
  */
  pixelFormat: OSType;
  colorMatrix: CFString;
  colorSpaceName: CFString;
  backgroundColor: CGColor;
  showsCursor: boolean;
  shouldBeOpaque: boolean;
  capturesShadowsOnly: boolean;
  ignoreShadowsDisplay: boolean;
  ignoreShadowsSingleWindow: boolean;
  ignoreGlobalClipDisplay: boolean;
  ignoreGlobalClipSingleWindow: boolean;
  queueDepth: number;
  minimumFrameInterval: CMTime;
  captureResolution: number; // SCCaptureResolutionType
  capturesAudio: boolean;
  sampleRate: number;
  channelCount: number;
  excludesCurrentProcessAudio: boolean;
  streamName: string | undefined;
}

export const SCStreamConfiguration = {
  create(args: Partial<SCStreamConfiguration> = {}): SCStreamConfiguration {
    const result = RAW_createStreamConfiguration() as SCStreamConfiguration;
    Object.assign(result, args);
    return result;
  },
} as const;

export interface ScreenShotImage {
  size: CGSize;
  getImageData(): Promise<Uint8ClampedArray>;
}

/** https://developer.apple.com/documentation/screencapturekit/scscreenshotmanager/4251334-captureimage */
export async function captureImage(
  contentFilter?: SCContentFilter,
  config?: SCStreamConfiguration
): Promise<ScreenShotImage> {
  return RAW_captureImage(contentFilter, config);
}

/*
   public var allowedPickerModes: SCContentSharingPickerMode

   public var excludedWindowIDs: [Int]

   public var excludedBundleIDs: [String]

   public var allowsChangingSelectedContent: Bool
*/

/** Bitfield. Use bitwise or to combine options. */
export type SCContentSharingPickerMode = number;
/** Bitfield. Use bitwise or to combine options. */
export const SCContentSharingPickerMode: SCContentSharingPickerModes =
  RAW_SCContentSharingPickerMode;

interface SCContentSharingPickerModes {
  readonly multipleApplications: SCContentSharingPickerMode;
  readonly multipleWindows: SCContentSharingPickerMode;
  readonly singleApplication: SCContentSharingPickerMode;
  readonly singleWindow: SCContentSharingPickerMode;
  readonly singleDisplay: SCContentSharingPickerMode;
}

export interface SCContentSharingPickerConfiguration {
  allowedPickerModes: SCContentSharingPickerMode;
  excludedWindowIDs: number[];
  excludedBundleIDs: string[];
  allowsChangingSelectedContent: boolean;
}

export async function pickContentFilter(
  args: Partial<SCContentSharingPickerConfiguration> = {}
): Promise<SCContentFilter> {
  return RAW_pickContentFilter(args);
}
