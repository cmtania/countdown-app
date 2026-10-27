import fs from 'node:fs/promises';
import sharp from 'sharp';

// Editable SVG masters and their native asset-catalog exports. No text or face
// is baked into the scenery: the live count and canonical face stay in SwiftUI.
const source = 'docs/design/svg';
const catalog = 'CountdownApp/Resources/Assets.xcassets';
await fs.mkdir(source, { recursive: true });
const svg = (body, width = 32, height = width) => `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`;
const line = body => `<g fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${body}</g>`;
const assets = {};
for (const direction of ['down', 'up']) {
  const arrow = direction === 'down' ? 'M16 11v13m-5-5 5 5 5-5' : 'M16 25V12m-5 5 5-5 5 5';
  assets[`calendar-${direction}`] = svg(line(`<rect x="4" y="5" width="24" height="25" rx="4"/><path d="M10 2v6m12-6v6${arrow}"/>`));
  assets[`calendar-${direction}-filled`] = svg(`<defs><mask id="cut"><rect width="32" height="32" fill="white"/><path d="${arrow}" fill="none" stroke="black" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></mask></defs><g fill="#000"><rect x="3" y="5" width="26" height="26" rx="5" mask="url(#cut)"/><rect x="9" y="1" width="3" height="8" rx="1.5"/><rect x="20" y="1" width="3" height="8" rx="1.5"/></g>`);
}
assets['icon-repeat'] = svg(line('<path d="M5 13a11 11 0 0 1 19-5l3 3M27 5v6h-6M27 19a11 11 0 0 1-19 5l-3-3M5 27v-6h6"/>'));
assets['icon-palette'] = svg(line('<path d="M17 3C9 3 3 9 3 17s6 12 12 12c3 0 4-2 3-4l-2-3c-1-2 0-4 3-4h5c4 0 6-2 5-6C28 6 23 3 17 3Z"/>') + '<g fill="#000"><circle cx="9" cy="14" r="1.8"/><circle cx="14" cy="8" r="1.8"/><circle cx="21" cy="8" r="1.8"/><circle cx="25" cy="13" r="1.8"/></g>');
assets['icon-settings'] = svg(line('<path d="m13 3 6 0 1 3 3 1 3-1 3 5-2 3v4l2 3-3 5-3-1-3 1-1 3h-6l-1-3-3-1-3 1-3-5 2-3v-4l-2-3 3-5 3 1 3-1Z"/><circle cx="16" cy="16" r="5"/>'));

const cloud = (x, y, s = 1) => `<path transform="translate(${x} ${y}) scale(${s})" d="M0 22Q0 12 12 12C9-3 28-8 30 7 40-5 52 2 52 14 67 11 69 27 56 27H8Q0 27 0 22Z" fill="#FFFCF4"/>`;
const heart = '<path d="M292 54C271 43 278 29 288 34L296 39C303 20 319 29 315 44L306 65Z" fill="#AB9BE9"/>';
const daisy = (x, y, s, flip = 1) => `<g transform="translate(${x} ${y}) scale(${s})"><path d="M0 0Q${12 * flip} 50 ${-4 * flip} 105" fill="none" stroke="#8FAE65" stroke-width="5"/><path d="M1 77Q-45 66-40 35-12 34 1 77M0 84Q45 75 44 52 18 46 0 84M1 72Q8 34 31 32 37 52 1 72" fill="#8FAE65"/>${Array.from({ length: 7 }, (_, i) => `<ellipse cy="-18" rx="10" ry="18" transform="rotate(${i * 360 / 7})" fill="#FFFCF2"/>`).join('')}<circle r="11" fill="#FFB43E"/></g>`;
assets['scene-seaside'] = svg(`${cloud(18, 43, .82)}${cloud(279, 65, .8)}${cloud(-7, 225, .85)}${cloud(252, 270, .8)}<path d="M0 273C20 261 29 272 41 286S74 285 91 301C112 319 124 331 143 323C173 310 190 320 208 331C236 350 257 336 278 324C308 300 333 310 360 321V350H0Z" fill="#BFB4F0"/><path d="M-8 298Q17 279 36 304T81 315T123 329T168 329" fill="none" stroke="#FFFCF4" stroke-width="5"/><path d="m302 285 22-53 23 53Z" fill="#FF7B35"/><path d="m302 285 22-53v53Z" fill="#FFAA70"/><path d="M324 234v63" stroke="#FFF9ED" stroke-width="2"/><path d="M294 289h58l-8 17h-39Z" fill="#FFFAEB"/>`, 360, 350);
assets['scene-garden'] = svg(`${cloud(18, 41, .82)}${heart}${daisy(39, 248, 1.05)}${daisy(318, 261, .95, -1)}`, 360, 350);
assets['scene-sprout'] = svg(`${cloud(25, 46, .8)}${cloud(278, 65, .7)}<path d="M0 333Q90 295 180 335T360 319V350H0Z" fill="#B9CA8C"/><g fill="#89A461"><path d="M39 350V271H43V350Z"/><path d="M41 312Q-4 300 5 271 36 271 41 312M42 299Q43 260 78 258 78 290 42 299"/><path d="M319 350V284H323V350Z"/><path d="M321 324Q280 315 288 289 318 289 321 324M322 307Q325 274 351 272 351 299 322 307"/></g>`, 360, 350);
assets['scene-gift'] = svg(`${cloud(18, 40, .8)}<g fill="#FFB43E"><circle cx="311" cy="50" r="5"/><circle cx="28" cy="269" r="4"/><path d="m304 244 5 10 11 2-8 8 2 11-10-5-10 5 2-11-8-8 11-2Z"/></g><g transform="translate(13 292) rotate(-8 28 24)"><rect width="57" height="58" rx="7" fill="#B6A7E4"/><path d="M28 0v58M0 16h57" stroke="#FFF9EC" stroke-width="8"/><path d="M28 0C-3-5 7-31 28 0 53-31 62-4 28 0Z" fill="none" stroke="#FF9E59" stroke-width="5"/></g><path d="m300 327 12 9m-8-27 7-8m22 30 9-8" stroke="#B6A7E4" stroke-width="5" stroke-linecap="round"/>`, 360, 350);
assets['scene-home'] = svg(`${cloud(19, 43, .85)}${heart}<path d="M0 330Q80 308 166 337T360 322V350H0Z" fill="#BECF9B"/><g transform="translate(278 268)"><path d="M5 31h60v51H5Z" fill="#FFF9EC"/><path d="m0 34 35-34 35 34" fill="none" stroke="#FF8B3E" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><rect x="27" y="53" width="17" height="29" rx="3" fill="#D0BDE8"/></g><path d="M32 346v-48m0 24Q4 316 8 292 31 297 32 322m0-10q28-8 27-29-24 3-27 29" fill="#8FAE65" stroke="#8FAE65" stroke-width="3"/>`, 360, 350);

for (const [name, content] of Object.entries(assets)) {
  await fs.writeFile(`${source}/${name}.svg`, content + '\n');
  const folder = `${catalog}/${name}.imageset`;
  await fs.mkdir(folder, { recursive: true });
  const scene = name.startsWith('scene-');
  const images = [];
  for (const scale of [1, 2, 3]) {
    const filename = `${name}@${scale}x.png`;
    await sharp(Buffer.from(content), { density: 72 * scale }).png().toFile(`${folder}/${filename}`);
    images.push({ idiom: 'universal', filename, scale: `${scale}x` });
  }
  await fs.writeFile(`${folder}/Contents.json`, JSON.stringify({ images, info: { author: 'xcode', version: 1 }, properties: { 'template-rendering-intent': scene ? 'original' : 'template' } }, null, 2) + '\n');
}
console.log(`Exported ${Object.keys(assets).length} SVG masters and 1x/2x/3x native assets.`);
