import sharp from 'sharp';
await sharp('docs/design/app-icon.svg')
  .resize(1024, 1024).flatten({ background: '#FAF5E9' }).removeAlpha()
  .png().toFile('CountdownApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png');
console.log('Rendered opaque 1024px app icon from editable vector artwork.');
