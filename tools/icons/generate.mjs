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
const macosDirectory = 'macos/Runner/Assets.xcassets/AppIcon.appiconset/';
for (const directory of [iosDirectory, macosDirectory]) {
  const catalog = JSON.parse(await readFile(new URL(`${directory}Contents.json`, root)));
  for (const image of catalog.images) {
    const [width, height] = image.size.split('x').map(Number);
    assert.equal(width, height, `Non-square icon: ${image.filename}`);
    addTarget(`${directory}${image.filename}`, width * Number.parseFloat(image.scale));
  }
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
  if (path.startsWith(macosDirectory)) {
    const artworkSize = Math.round(size * 0.8);
    const mask = Buffer.from(
      `<svg width="${artworkSize}" height="${artworkSize}"><rect width="${artworkSize}" height="${artworkSize}" rx="${artworkSize * 0.22}" fill="white"/></svg>`,
    );
    const artwork = await sharp(source, { density: 384 })
      .resize(artworkSize, artworkSize)
      .composite([{ input: mask, blend: 'dest-in' }])
      .png()
      .toBuffer();
    await sharp({
      create: { width: size, height: size, channels: 4, background: '#00000000' },
    })
      .composite([{ input: artwork, gravity: 'centre' }])
      .png()
      .toFile(output);
    const { data, info } = await sharp(output).raw().toBuffer({ resolveWithObject: true });
    assert.equal(info.width, size, path);
    assert.equal(info.height, size, path);
    assert.equal(info.channels, 4, path);
    assert.equal(data[3], 0, `Mac icon corners must be transparent: ${path}`);
    assert.equal(data[(Math.floor(size / 2) * size + Math.floor(size / 2)) * 4 + 3], 255, path);
    continue;
  }
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

const featureGraphic = new URL('assets/GooglePlay/ag_logo_wide_1024x500.png', root);
const featureSource = Buffer.from(
  `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="500" viewBox="0 0 1024 500">
    <rect width="1024" height="500" fill="#faf7f2"/>
    <image href="data:image/svg+xml;base64,${source.toString('base64')}"
           x="64" y="70" width="360" height="360"/>
    <g fill="#2d273b" font-family="Arial, Helvetica, sans-serif">
      <text x="480" y="225" font-size="68" font-weight="700">Anagram</text>
      <text x="480" y="305" font-size="68" font-weight="700">Ladder</text>
      <text x="480" y="365" font-size="26">Rearrange. Solve. Climb.</text>
    </g>
  </svg>`,
);
await sharp(featureSource)
  .removeAlpha()
  .png()
  .toFile(fileURLToPath(featureGraphic));
const featureMetadata = await sharp(fileURLToPath(featureGraphic)).metadata();
assert.equal(featureMetadata.width, 1024, 'Google Play feature graphic');
assert.equal(featureMetadata.height, 500, 'Google Play feature graphic');
assert.equal(featureMetadata.hasAlpha, false, 'Google Play feature graphic must be opaque');
console.log('Generated and verified the Google Play feature graphic.');

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
