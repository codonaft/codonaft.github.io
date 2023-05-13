// lib/constants.ts
var KnownBrowsers = {
  chrome: "Google Chrome",
  brave: "Brave",
  crios: "Google Chrome",
  edge: "Microsoft Edge",
  edg: "Microsoft Edge",
  edgios: "Microsoft Edge",
  fennec: "Mozilla Firefox",
  jsdom: "JsDOM",
  mozilla: "Mozilla Firefox",
  fxios: "Mozilla Firefox",
  msie: "Microsoft Internet Explorer",
  opera: "Opera",
  opios: "Opera",
  opr: "Opera",
  opt: "Opera",
  rv: "Microsoft Internet Explorer",
  safari: "Safari",
  samsungbrowser: "Samsung Browser",
  electron: "Electron"
};
var KnownPlatforms = {
  "android": "Android",
  "androidTablet": "Android Tablet",
  "cros": "Chrome OS",
  "fennec": "Android Tablet",
  "ipad": "IPad",
  "ipod": "IPod",
  "iphone": "IPhone",
  "jsdom": "JsDOM",
  "linux": "Linux",
  "mac": "Macintosh",
  "tablet": "Android Tablet",
  "win": "Windows",
  "windows phone": "Windows Phone",
  "xbox": "Microsoft Xbox"
};

// lib/utils.ts
var toFixed = (val, fixed = -1) => {
  const REG_EXP = new RegExp(`^-?\\d+(?:.\\d{0,${fixed}})?`);
  const match = Number(val).toString().match(REG_EXP);
  return match ? match[0] : null;
};
var utils_default = {
  toFixed
};

// package.json
var version = "4.1.0";

// lib/browser-dtector.ts
var getNavigator = () => {
  if (typeof window !== "undefined") {
    return window.navigator;
  }
  return null;
};
var BrowserDetector = class {
  userAgent;
  constructor(inputUA) {
    this.userAgent = inputUA || getNavigator()?.userAgent || null;
  }
  static get VERSION() {
    return version;
  }
  parseUserAgent(userAgent) {
    const browserMatches = {};
    const uaFresh = userAgent || this.userAgent || "";
    const ua = uaFresh.toLowerCase().replace(/\s\s+/g, " ");
    const browserMatch = /(edge)\/([\w.]+)/.exec(ua) || /(edg)[/]([\w.]+)/.exec(ua) || /(opr)[/]([\w.]+)/.exec(ua) || /(opt)[/]([\w.]+)/.exec(ua) || /(fxios)[/]([\w.]+)/.exec(ua) || /(edgios)[/]([\w.]+)/.exec(ua) || /(jsdom)[/]([\w.]+)/.exec(ua) || /(samsungbrowser)[/]([\w.]+)/.exec(ua) || /(electron)[/]([\w.]+)/.exec(ua) || /(chrome)[/]([\w.]+)/.exec(ua) || /(crios)[/]([\w.]+)/.exec(ua) || /(opios)[/]([\w.]+)/.exec(ua) || /(version)(applewebkit)[/]([\w.]+).*(safari)[/]([\w.]+)/.exec(ua) || /(webkit)[/]([\w.]+).*(version)[/]([\w.]+).*(safari)[/]([\w.]+)/.exec(ua) || /(applewebkit)[/]([\w.]+).*(safari)[/]([\w.]+)/.exec(ua) || /(webkit)[/]([\w.]+)/.exec(ua) || /(opera)(?:.*version|)[/]([\w.]+)/.exec(ua) || /(msie) ([\w.]+)/.exec(ua) || /(fennec)[/]([\w.]+)/.exec(ua) || ua.indexOf("trident") >= 0 && /(rv)(?::| )([\w.]+)/.exec(ua) || ua.indexOf("compatible") < 0 && /(mozilla)(?:.*? rv:([\w.]+)|)/.exec(ua) || [];
    const platformMatch = /(ipad)/.exec(ua) || /(ipod)/.exec(ua) || /(iphone)/.exec(ua) || /(jsdom)/.exec(ua) || /(windows phone)/.exec(ua) || /(xbox)/.exec(ua) || /(win)/.exec(ua) || /(tablet)/.exec(ua) || /(android)/.test(ua) && /(mobile)/.test(ua) === false && ["androidTablet"] || /(android)/.exec(ua) || /(mac)/.exec(ua) || /(linux)/.exec(ua) || /(cros)/.exec(ua) || [];
    let name = browserMatch[5] || browserMatch[3] || browserMatch[1] || null;
    const platform = platformMatch[0] || null;
    const version2 = browserMatch[4] || browserMatch[2] || null;
    const navigator = getNavigator();
    if (name === "chrome" && typeof navigator?.brave?.isBrave === "function") {
      name = "brave";
    }
    if (name) {
      browserMatches[name] = true;
    }
    if (platform) {
      browserMatches[platform] = true;
    }
    const isAndroid = Boolean(browserMatches.tablet || browserMatches.android || browserMatches.androidTablet);
    const isTablet = Boolean(browserMatches.ipad || browserMatches.tablet || browserMatches.androidTablet);
    const isMobile = Boolean(browserMatches.android || browserMatches.androidTablet || browserMatches.tablet || browserMatches.ipad || browserMatches.ipod || browserMatches.iphone || browserMatches["windows phone"]);
    const isDesktop = Boolean(browserMatches.cros || browserMatches.mac || browserMatches.linux || browserMatches.win);
    const isWebkit = Boolean(browserMatches.brave || browserMatches.chrome || browserMatches.crios || browserMatches.opr || browserMatches.safari || browserMatches.edg || browserMatches.electron);
    const isIE = Boolean(browserMatches.msie || browserMatches.rv);
    const isChrome = Boolean(browserMatches.chrome || browserMatches.crios);
    const isFireFox = Boolean(browserMatches.fxios || browserMatches.fennec || browserMatches.mozilla);
    const isSafari = Boolean(browserMatches.safari);
    const isOpera = Boolean(browserMatches.opera || browserMatches.opios || browserMatches.opr || browserMatches.opt);
    const isEdge = Boolean(browserMatches.edg || browserMatches.edge || browserMatches.edgios);
    const browserInfo = {
      name: KnownBrowsers[name] ?? null,
      platform: KnownPlatforms[platform] ?? null,
      userAgent: uaFresh,
      version: version2,
      shortVersion: version2 ? utils_default.toFixed(parseFloat(version2), 2) : null,
      isAndroid,
      isTablet,
      isMobile,
      isDesktop,
      isWebkit,
      isIE,
      isChrome,
      isFireFox,
      isSafari,
      isOpera,
      isEdge
    };
    return browserInfo;
  }
  getBrowserInfo() {
    const browserInfo = this.parseUserAgent();
    return {
      name: browserInfo.name,
      platform: browserInfo.platform,
      userAgent: browserInfo.userAgent,
      version: browserInfo.version,
      shortVersion: browserInfo.shortVersion
    };
  }
};
var browser_dtector_default = BrowserDetector;
export {
  BrowserDetector,
  KnownBrowsers,
  KnownPlatforms,
  browser_dtector_default as default
};
//# sourceMappingURL=browser-dtector.js.map