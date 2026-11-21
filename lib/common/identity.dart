const _useDevIdentity = bool.fromEnvironment('APP_DEV');
const _useStandardBuild = bool.fromEnvironment('APP_STANDARD');

class AppIdentity {
  static const isDev = _useDevIdentity;
  static const isStandard = _useStandardBuild;

  static const productName = 'WhyBox';
  static const desktopProductName = 'Bettbox';
  static const devSuffix = 'Dev';
  static const packageId = 'com.why.whybox';

  static const compactName = isDev ? '$productName$devSuffix' : productName;
  static const desktopCompactName = isDev
      ? '$desktopProductName$devSuffix'
      : desktopProductName;
  static const displayName = isDev ? '$productName Dev' : productName;
  static const mainExecutableName = desktopProductName;
  static const coreExecutableName = '${desktopCompactName}Core';
  static const dataDirName = desktopCompactName;
  static const tunDeviceName = compactName;
}

class WindowsHelperIdentity {
  static const serviceName = '${AppIdentity.desktopCompactName}HelperService';
  static const pipeName = '\\\\.\\pipe\\${AppIdentity.desktopCompactName}.Helper';
}
