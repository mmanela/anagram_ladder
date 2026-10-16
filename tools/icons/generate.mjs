import assert from 'node:assert/strict';
import { mkdir, readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const root = new URL('../../', import.meta.url);
const source = await readFile(new URL('assets/app_icon.svg', root));
const targets = new Map();

function addTarget(path, size) {
  assert(Number.isInteger(size) && size > 0, `Invalid icon size: ${path}`);
  const existing = targets.get(path);
  assert(existing === undefined || existing === size, `Conflicting sizes: ${path}`);
  targets.set(path, size);
}

const iosDirectory = 'ios/Runner/Assets.xcassets/AppIcon.appiconset/';
const catalog = JSON.parse(await readFile(new URL(`${iosDirectory}Contents.json`, root)));
for (const image of catalog.images) {
  const [width, height] = image.size.split('x').map(Number);
  assert.equal(width, height, `Non-square icon: ${image.filename}`);
  addTarget(`${iosDirectory}${image.filename}`, width * Number.parseFloat(image.scale));
}

for (const [density, size] of Object.entries({
  mdpi: 48,
  hdpi: 72,
  xhdpi: 96,
  xxhdpi: 144,
  xxxhdpi: 192,
})) {
  addTarget(`android/app/src/main/res/mipmap-${density}/ic_launcher.png`, size);
}

const manifest = JSON.parse(await readFile(new URL('web/manifest.json', root)));
for (const icon of manifest.icons) {
  const [width, height] = icon.sizes.split('x').map(Number);
  assert.equal(width, height, `Non-square web icon: ${icon.src}`);
  addTarget(`web/${icon.src}`, width);
}
addTarget('web/favicon.png', 32);
addTarget('assets/GooglePlay/ag_logo_simple_512.png', 512);
addTarget('assets/app_icon.png', 512);

// Also refresh unused sizes retained in the existing iOS asset catalog folder.
for (const size of [16, 32, 64, 128, 256, 512]) {
  addTarget(`${iosDirectory}${size}.png`, size);
}

for (const [path, size] of targets) {
  const output = fileURLToPath(new URL(path, root));
  await sharp(source, { density: 384 })
    .resize(size, size)
    .removeAlpha()
    .png()
    .toFile(output);
  const metadata = await sharp(output).metadata();
  assert.equal(metadata.width, size, path);
  assert.equal(metadata.height, size, path);
  assert.equal(metadata.hasAlpha, false, `Icon must be opaque: ${path}`);
}

console.log(`Generated and verified ${targets.size} icons from assets/app_icon.svg.`);

const launchTargets = [
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png', 120],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png', 240],
  ['ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png', 360],
  ...Object.entries({ mdpi: 120, hdpi: 180, xhdpi: 240, xxhdpi: 360, xxxhdpi: 480 })
    .map(([density, size]) => [
      `android/app/src/main/res/drawable-${density}/launch_icon.png`, size,
    ]),
];
for (const [path, size] of launchTargets) {
  const output = new URL(path, root);
  await mkdir(new URL('.', output), { recursive: true });
  const mask = Buffer.from(
    `<svg width="${size}" height="${size}"><rect width="${size}" height="${size}" rx="${size * 28 / 120}" fill="white"/></svg>`,
  );
  await sharp(source, { density: 384 })
    .resize(size, size)
    .composite([{ input: mask, blend: 'dest-in' }])
    .png()
    .toFile(fileURLToPath(output));
  const { data, info } = await sharp(fileURLToPath(output))
    .raw().toBuffer({ resolveWithObject: true });
  assert.equal(info.width, size, path);
  assert.equal(info.height, size, path);
  assert.equal(info.channels, 4, path);
  assert.equal(data[3], 0, `Launch badge corners must be transparent: ${path}`);
}
console.log(`Generated and verified ${launchTargets.length} rounded launch badges.`);
