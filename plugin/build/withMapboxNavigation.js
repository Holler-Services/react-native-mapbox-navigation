"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.setExcludedArchitectures = exports.addMapboxInstallerBlock = exports.addInstallerBlock = exports.addDisableOutputPathsBlock = exports.addConstantBlock = exports.applyCocoaPodsModifications = void 0;
const fs_1 = require("fs");
const path_1 = __importDefault(require("path"));
const config_plugins_1 = require("@expo/config-plugins");
const generateCode_1 = require("@expo/config-plugins/build/utils/generateCode");
let pkg = {
    name: '@hollertaxi/react-native-mapbox-navigation',
};
try {
    pkg = require('@hollertaxi/react-native-mapbox-navigation/package.json');
}
catch (_a) {
    // empty catch block
}
/**
 * Dangerously adds the custom installer hooks to the Podfile.
 * In the future this should be removed in favor of some custom hooks provided by Expo autolinking.
 *
 * @param config
 * @returns
 */
const withCocoaPodsInstallerBlocks = (c, { RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken, RNMapboxMapsVersion }) => {
    return (0, config_plugins_1.withDangerousMod)(c, [
        'ios',
        async (config) => {
            const file = path_1.default.join(config.modRequest.platformProjectRoot, 'Podfile');
            const contents = await fs_1.promises.readFile(file, 'utf8');
            await fs_1.promises.writeFile(file, applyCocoaPodsModifications(contents, {
                RNMBNAVVersion,
                RNMBNAVDownloadToken,
                RNMBNAVPublicToken,
                RNMapboxMapsVersion
            }), 'utf-8');
            return config;
        },
    ]);
};
// Only the preinstaller block is required, the post installer block is
// used for spm (swift package manager) which Expo doesn't currently support.
function applyCocoaPodsModifications(contents, { RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken, RNMapboxMapsVersion }) {
    // Ensure installer blocks exist
    let src = addConstantBlock(contents, RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken, RNMapboxMapsVersion);
    src = addDisableOutputPathsBlock(src);
    src = addInstallerBlock(src, 'pre');
    src = addInstallerBlock(src, 'post');
    src = addMapboxInstallerBlock(src, 'pre');
    src = addMapboxInstallerBlock(src, 'post');
    return src;
}
exports.applyCocoaPodsModifications = applyCocoaPodsModifications;
function addConstantBlock(src, RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken, RNMapboxMapsVersion) {
    const tag = `@hollertaxi/react-native-mapbox-navigation-rbmbnaversion`;
    return (0, generateCode_1.mergeContents)({
        tag,
        src,
        newSrc: [
            RNMBNAVVersion && RNMBNAVVersion.length > 0 ? `$RNMBNAVVersion = '${RNMBNAVVersion}'` : '',
            RNMBNAVDownloadToken && RNMBNAVDownloadToken.length > 0 ? `$RNMBNAVDownloadToken = '${RNMBNAVDownloadToken}'` : '',
            RNMBNAVPublicToken && RNMBNAVPublicToken.length > 0 ? `$RNMBNAVPublicToken = '${RNMBNAVPublicToken}'` : '',
            RNMapboxMapsVersion && RNMapboxMapsVersion.length > 0 ? `$RNMapboxMapsVersion = '${RNMapboxMapsVersion}'` : ''
        ].join('\n'),
        anchor: /target .+ do/,
        // We can't go after the use_react_native block because it might have parameters, causing it to be multi-line (see react-native template).
        offset: 0,
        comment: '#',
    }).contents;
}
exports.addConstantBlock = addConstantBlock;
function addDisableOutputPathsBlock(src) {
    const tag = `@hollertaxi/react-native-mapbox-navigation-rbmbnatop`;
    return (0, generateCode_1.mergeContents)({
        tag,
        src,
        newSrc: ':disable_input_output_paths => true, \n',
        anchor: /:deterministic_uuids => false/,
        // We can't go after the use_react_native block because it might have parameters, causing it to be multi-line (see react-native template).
        offset: 0,
        comment: '#',
    }).contents;
}
exports.addDisableOutputPathsBlock = addDisableOutputPathsBlock;
function addInstallerBlock(src, blockName) {
    const matchBlock = new RegExp(`${blockName}_install do \\|installer\\|`);
    const tag = `${blockName}_installer`;
    for (const line of src.split('\n')) {
        const contents = line.trim();
        // Ignore comments
        if (!contents.startsWith('#')) {
            // Prevent adding the block if it exists outside of comments.
            if (contents.match(matchBlock)) {
                // This helps to still allow revisions, since we enabled the block previously.
                // Only continue if the generated block exists...
                const modified = (0, generateCode_1.removeGeneratedContents)(src, tag);
                if (!modified) {
                    return src;
                }
            }
        }
    }
    return (0, generateCode_1.mergeContents)({
        tag,
        src,
        newSrc: [`  ${blockName}_install do |installer|`, '  end'].join('\n'),
        anchor: /use_react_native/,
        // We can't go after the use_react_native block because it might have parameters, causing it to be multi-line (see react-native template).
        offset: 0,
        comment: '#',
    }).contents;
}
exports.addInstallerBlock = addInstallerBlock;
function addMapboxInstallerBlock(src, blockName) {
    return (0, generateCode_1.mergeContents)({
        tag: `@hollertaxi/react-native-mapbox-navigation-${blockName}_installer`,
        src,
        newSrc: `    $RNMBNAV.${blockName}_install(installer)`,
        anchor: new RegExp(`^\\s*${blockName}_install do \\|installer\\|`),
        offset: 1,
        comment: '#',
    }).contents;
}
exports.addMapboxInstallerBlock = addMapboxInstallerBlock;
/**
 * Exclude building for arm64 on simulator devices in the pbxproj project.
 * Without this, production builds targeting simulators will fail.
 */
function setExcludedArchitectures(project) {
    const configurations = project.pbxXCBuildConfigurationSection();
    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
    // @ts-ignore
    for (const { buildSettings } of Object.values(configurations || {})) {
        // Guessing that this is the best way to emulate Xcode.
        // Using `project.addToBuildSettings` modifies too many targets.
        if (typeof (buildSettings === null || buildSettings === void 0 ? void 0 : buildSettings.PRODUCT_NAME) !== 'undefined') {
            buildSettings['"EXCLUDED_ARCHS[sdk=iphonesimulator*]"'] = '"arm64"';
        }
    }
    return project;
}
exports.setExcludedArchitectures = setExcludedArchitectures;
const withExcludedSimulatorArchitectures = (c) => {
    return (0, config_plugins_1.withXcodeProject)(c, (config) => {
        config.modResults = setExcludedArchitectures(config.modResults);
        return config;
    });
};
const withAndroidPropertiesDownloadToken = (config, { RNMBNAVDownloadToken }) => {
    const key = 'MAPBOX_DOWNLOADS_TOKEN';
    if (RNMBNAVDownloadToken) {
        return (0, config_plugins_1.withGradleProperties)(config, (config) => {
            config.modResults = config.modResults.filter((item) => {
                if (item.type === 'property' && item.key === key) {
                    return false;
                }
                return true;
            });
            // eslint-disable-next-line fp/no-mutating-methods
            config.modResults.push({
                type: 'property',
                key,
                value: RNMBNAVDownloadToken,
            });
            return config;
        });
    }
    else {
        return config;
    }
};
const withAndroidPropertiesPublicToken = (config, { RNMBNAVPublicToken }) => {
    const key = 'MAPBOX_ACCESS_TOKEN';
    if (RNMBNAVPublicToken) {
        return (0, config_plugins_1.withGradleProperties)(config, (config) => {
            config.modResults = config.modResults.filter((item) => {
                if (item.type === 'property' && item.key === key) {
                    return false;
                }
                return true;
            });
            // eslint-disable-next-line fp/no-mutating-methods
            config.modResults.push({
                type: 'property',
                key: key,
                value: RNMBNAVPublicToken,
            });
            return config;
        });
    }
    else {
        return config;
    }
};
const withAndroidProperties = (config, { RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken, RNMapboxMapsVersion }) => {
    config = withAndroidPropertiesDownloadToken(config, {
        RNMBNAVDownloadToken,
    });
    config = withAndroidPropertiesPublicToken(config, {
        RNMBNAVPublicToken
    });
    return config;
};
const addLibCppFilter = (appBuildGradle) => {
    if (appBuildGradle.includes("pickFirst 'lib/x86/libc++_shared.so'"))
        return appBuildGradle;
    return (0, generateCode_1.mergeContents)({
        tag: `@hollertaxi/react-native-mapbox-navigation-libcpp`,
        src: appBuildGradle,
        newSrc: `packagingOptions {
        pickFirst 'lib/x86/libc++_shared.so'
        pickFirst 'lib/x86_64/libc++_shared.so'
        pickFirst 'lib/arm64-v8a/libc++_shared.so'
        pickFirst 'lib/armeabi-v7a/libc++_shared.so'
    }`,
        anchor: new RegExp(`^\\s*android\\s*{`),
        offset: 1,
        comment: '//',
    }).contents;
};
const addMapboxMavenRepo = (projectBuildGradle) => {
    if (projectBuildGradle.includes('api.mapbox.com/downloads/v2/releases/maven'))
        return projectBuildGradle;
    /*
    return projectBuildGradle.replace(
      /repositories \s?{/,
      `repositories {
         maven {
          url 'https://api.mapbox.com/downloads/v2/releases/maven'
          authentication { basic(BasicAuthentication) }
          credentials {
            username = 'mapbox'
            password = project.properties['MAPBOX_DOWNLOADS_TOKEN'] ?: ""
          }
         }
    `,
    );*/
    return (0, generateCode_1.mergeContents)({
        tag: `@hollertaxi/react-native-mapbox-navigation-v2-maven`,
        src: projectBuildGradle,
        newSrc: `maven {
      url 'https://api.mapbox.com/downloads/v2/releases/maven'
      authentication { basic(BasicAuthentication) }
      credentials {
        username = 'mapbox'
        password = project.properties['MAPBOX_DOWNLOADS_TOKEN'] ?: ""
      }
    }`,
        anchor: new RegExp(`^\\s*allprojects\\s*{`),
        offset: 2,
        comment: '//',
    }).contents;
};
const withAndroidAppGradle = (config) => {
    return (0, config_plugins_1.withAppBuildGradle)(config, ({ modResults, ...config }) => {
        if (modResults.language !== 'groovy') {
            config_plugins_1.WarningAggregator.addWarningAndroid('withMapboxNavigation', `Cannot automatically configure app build.gradle if it's not groovy`);
            return { modResults, ...config };
        }
        modResults.contents = addLibCppFilter(modResults.contents);
        return { modResults, ...config };
    });
};
const withAndroidProjectGradle = (config) => {
    return (0, config_plugins_1.withProjectBuildGradle)(config, ({ modResults, ...config }) => {
        if (modResults.language !== 'groovy') {
            config_plugins_1.WarningAggregator.addWarningAndroid('withMapboxNavigation', `Cannot automatically configure app build.gradle if it's not groovy`);
            return { modResults, ...config };
        }
        modResults.contents = addMapboxMavenRepo(modResults.contents);
        return { modResults, ...config };
    });
};
const withMapboxNavigationAndroid = (config, { RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken, RNMapboxMapsVersion }) => {
    config = withAndroidProperties(config, {
        RNMBNAVVersion,
        RNMBNAVDownloadToken,
        RNMBNAVPublicToken
    });
    config = withAndroidProjectGradle(config, { RNMBNAVVersion });
    config = withAndroidAppGradle(config, { RNMBNAVVersion });
    return config;
};
const withMapboxNavigation = (config, { RNMBNAVVersion, RNMBNAVDownloadToken, RNMBNAVPublicToken }) => {
    config = withExcludedSimulatorArchitectures(config);
    config = withMapboxNavigationAndroid(config, {
        RNMBNAVVersion,
        RNMBNAVDownloadToken,
        RNMBNAVPublicToken
    });
    return withCocoaPodsInstallerBlocks(config, {
        RNMBNAVVersion,
        RNMBNAVDownloadToken,
        RNMBNAVPublicToken
    });
};
exports.default = (0, config_plugins_1.createRunOncePlugin)(withMapboxNavigation, pkg.name, pkg.version);
