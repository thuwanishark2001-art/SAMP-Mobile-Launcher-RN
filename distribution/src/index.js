const glob = require('glob');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');
const findFiles = promisify(glob);
const { md5FileSync } = require('./md5');

// Settings can be overridden with environment variables, e.g.
//   DIST_DIR=/var/www/kingmakers/mobile SERVER_ADDRESS=1.2.3.4:7777 node src/index.js
// DIST_DIR must contain cache/, cache_snow/ and launcher/ (each may be empty);
// distribution.json is written into it.

// APP_VERSION from the launcher's .env, so the app only offers a launcher
// update when a newer APK is published.
function readAppVersion() {
	const envPath = path.resolve(__dirname, '../../.env');
	const match = fs.existsSync(envPath)
		? fs.readFileSync(envPath, 'utf8').match(/^APP_VERSION=(.+)$/m)
		: null;
	return match ? match[1].trim() : '0.0.0';
}

const versionHash = Math.random().toString(36).substring(7);

const distDir = path.resolve(process.env.DIST_DIR || './../../distributions');
const distributionGeneratePath =
	process.env.OUT_FILE || path.join(distDir, 'distribution.json');

const dirCache = path.join(distDir, 'cache');
const dirCacheSnow = path.join(distDir, 'cache_snow');
const dirLauncher = path.join(distDir, 'launcher');

const projectName = 'Kingmakers RP';
const packageName = 'com.touch.mobile.dark';

const cdnBase = (process.env.CDN_BASE || 'http://65.20.88.67/mobile').replace(
	/\/$/,
	''
);
const cdnCache = `${cdnBase}/cache`;
const cdnLauncher = `${cdnBase}/launcher`;
const serverIcon = `${cdnBase}/image/server_icon.png`;
const serverAddress = process.env.SERVER_ADDRESS || '65.20.88.67:7777';

const appVersion = process.env.APP_VERSION || readAppVersion();
const rss = '';

const filesContinue = ['settings.ini', 'gta_sa.set', 'svconfig.ini'];
const filesIgnore = ['samp_log.txt', 'crash_log.log', 'gtasatelem.set'];

//----------------

return new Promise(async () => {
	const cache = [];
	let cacheId = 1;
	const cacheSnow = [];
	let cacheSnowId = 1;
	const cacheMerge = [];
	let cacheMergeId = 1;

	// Launcher (optional: without an APK in launcher/, no update is offered)
	const clientPath = path.join(dirLauncher, 'app-release.apk');
	const hasClient = fs.existsSync(clientPath);

	const clientCache = {
		appVersion,
		name: `app-release.apk`,
		hash: hasClient ? await md5FileSync(clientPath) : '',
		mtime: hasClient ? unixTimeStamp(fs.statSync(clientPath).mtime) : 0,
		bytes: hasClient ? fs.statSync(clientPath).size : 0,
	};

	// Main cache
	const filePaths = await findFiles(`${path.resolve(dirCache)}/**/*`);
	for (const filePath of filePaths) {
		if (!fs.lstatSync(filePath).isDirectory()) {
			let nameFile = filePath.split('/').pop();

			if (filesIgnore.indexOf(nameFile) === -1) {
				const pathFile = filePath
					.replace(path.resolve(dirCache) + '/', '')
					.split('/');
				pathFile.pop();

				cache.push({
					id: cacheId,
					name: nameFile,
					path: pathFile.join('/'),
					bytes: [fs.statSync(filePath).size],
					gpu: getGpu(nameFile),
				});

				cacheId++;
			}
		}
	}

	// Winter cache
	const fileSnowPaths = await findFiles(`${path.resolve(dirCacheSnow)}/**/*`);
	for (const filePath of fileSnowPaths) {
		if (!fs.lstatSync(filePath).isDirectory()) {
			let nameFile = filePath.split('/').pop();

			if (filesIgnore.indexOf(nameFile) === -1) {
				const pathFile = filePath
					.replace(path.resolve(dirCacheSnow) + '/', '')
					.split('/');
				pathFile.pop();

				cacheSnow.push({
					id: cacheSnowId,
					name: nameFile,
					path: pathFile.join('/'),
					bytes: fs.statSync(filePath).size,
					gpu: getGpu(nameFile),
				});

				cacheSnowId++;
			}
		}
	}

	// Merged cache
	const fileMergePaths = await findFiles(`${path.resolve(dirCache)}/**/*`);
	for (const filePath of filePaths) {
		if (!fs.lstatSync(filePath).isDirectory()) {
			let nameFile = filePath.split('/').pop();

			if (filesIgnore.indexOf(nameFile) === -1) {
				const pathFile = filePath
					.replace(path.resolve(dirCache) + '/', '')
					.split('/');
				pathFile.pop();

				for (const snow of cacheSnow) {
					if (cache[cacheMergeId - 1].name === snow.name) {
						cache[cacheMergeId - 1].bytes = [
							...cache[cacheMergeId - 1].bytes,
							snow.bytes,
						];
					}
				}

				cacheMergeId++;
			}
		}
	}

	// Merged cache
	const cacheMode = [];
	let cacheModeId = 1;
	const fileModePaths = await findFiles(`${path.resolve(dirCache)}/**/*`);
	for (const filePath of filePaths) {
		if (!fs.lstatSync(filePath).isDirectory()) {
			let nameFile = filePath.split('/').pop();

			if (filesIgnore.indexOf(nameFile) === -1) {
				const pathFile = filePath
					.replace(path.resolve(dirCache) + '/', '')
					.split('/');
				pathFile.pop();

				for (const snow of cacheSnow) {
					if (cache[cacheModeId - 1].name === snow.name) {
						cacheMode.push(cache[cacheModeId - 1]);
					}
				}

				cacheModeId++;
			}
		}
	}

	fs.writeFileSync(
		distributionGeneratePath,
		JSON.stringify(
			{
				cache,
				cacheMode,
				projectName,
				packageName,
				versionHash,
				rss,
				cdnCache,
				cdnLauncher,
				filesContinue,
				launcher: clientCache,
				servers: [
					{
						id: 1,
						show: true,
						version: '1.0',
						icon: serverIcon,
						// Badges shown on the server card, e.g.
						// { title: 'x2 Promo', style: 'red' } (style: 'red' | 'blue')
						events: [],
						slot: 100,
						bonus: false,
						name: 'Kingmakers RP',
						description: 'SA-MP Mobile',
						address: serverAddress,
						sampVersion: '0.3.7',
					},
					{
						id: 100,
						show: false,
						version: '1.0',
						icon: serverIcon,
						events: [],
						slot: 1000,
						bonus: false,
						name: 'Localhost',
						description: 'SA-MP Mobile',
						address: '127.0.0.1:7777',
						sampVersion: '0.3.7',
					},
				],
			},
			null,
			4
		)
	);

	console.log('Distribution dir: ' + distributionGeneratePath);
}).catch(error => {
	console.log('Error', error);
});

function unixTimeStamp(time) {
	const date = new Date(time);
	return Math.floor(date.getTime() / 1000);
}

function getGpu(file) {
	switch (file) {
		case 'txd.dxt.toc':
		case 'txd.dxt.tmb':
		case 'txd.dxt.dat':
		case 'samp.dxt.toc':
		case 'samp.dxt.tmb':
		case 'samp.dxt.dat':
		case 'mobile.dxt.toc':
		case 'mobile.dxt.tmb':
		case 'mobile.dxt.dat':
		case 'gta3.dxt.dat':
		case 'gta3.dxt.tmb':
		case 'gta3.dxt.toc':
		case 'gta_int.dxt.toc':
		case 'gta_int.dxt.tmb':
		case 'gta_int.dxt.dat':
		case 'touch.dxt.toc':
		case 'touch.dxt.tmb':
		case 'touch.dxt.dat': {
			return 'A';
		}
		case 'txd.etc.toc':
		case 'txd.etc.tmb':
		case 'txd.etc.dat':
		case 'samp.etc.toc':
		case 'samp.etc.tmb':
		case 'samp.etc.dat':
		case 'mobile.etc.toc':
		case 'mobile.etc.tmb':
		case 'mobile.etc.dat':
		case 'gta3.etc.dat':
		case 'gta3.etc.tmb':
		case 'gta3.etc.toc':
		case 'gta_int.etc.toc':
		case 'gta_int.etc.tmb':
		case 'gta_int.etc.dat':
		case 'touch.etc.toc':
		case 'touch.etc.tmb':
		case 'touch.etc.dat': {
			return 'M';
		}
		case 'txd.pvr.toc':
		case 'txd.pvr.tmb':
		case 'txd.pvr.dat':
		case 'samp.pvr.toc':
		case 'samp.pvr.tmb':
		case 'samp.pvr.dat':
		case 'mobile.pvr.toc':
		case 'mobile.pvr.tmb':
		case 'mobile.pvr.dat':
		case 'gta3.pvr.dat':
		case 'gta3.pvr.tmb':
		case 'gta3.pvr.toc':
		case 'gta_int.pvr.toc':
		case 'gta_int.pvr.tmb':
		case 'gta_int.pvr.dat':
		case 'touch.pvr.toc':
		case 'touch.pvr.tmb':
		case 'touch.pvr.dat': {
			return 'PT';
		}
		default:
			return '';
	}
}
