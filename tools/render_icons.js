const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ICONS = [
  {
    name: 'shop',
    svg: `<svg viewBox="-2 -2 28 28" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2L9 7h6z"></path>
      <path d="M5 10c0-3 14-3 14 0 0 5-3 12-7 12s-7-7-7-12z"></path>
    </svg>`
  },
  {
    name: 'squad',
    svg: `<svg viewBox="-2 -2 28 28" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"></path>
      <path d="M9 12l6-6"></path>
      <path d="M15 12l-6-6"></path>
    </svg>`
  },
  {
    name: 'overdrive',
    svg: `<svg viewBox="-2 -2 28 28" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
    </svg>`
  },
  {
    name: 'recall',
    svg: `<svg viewBox="-2 -2 28 28" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"></path>
      <path d="M3 3v5h5"></path>
    </svg>`
  },
  {
    name: 'tower',
    svg: `<svg viewBox="-2 -2 28 28" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 2L8 10v12h8V10L12 2z"></path>
      <line x1="10" y1="14" x2="14" y2="14"></line>
      <line x1="10" y1="18" x2="14" y2="18"></line>
    </svg>`
  }
];

const outDir = path.resolve(__dirname, '../assets/ui/icons');
fs.mkdirSync(outDir, { recursive: true });

const edgeExe = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';

for (const icon of ICONS) {
  const htmlContent = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  * { box-sizing: border-box; }
  html, body {
    margin: 0;
    padding: 0;
    width: 256px;
    height: 256px;
    background: transparent !important;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
  }
  svg {
    width: 210px;
    height: 210px;
  }
</style>
</head>
<body>
  ${icon.svg}
</body>
</html>`;

  const htmlPath = path.join(outDir, `${icon.name}.html`);
  const pngPath = path.join(outDir, `${icon.name}.png`);
  fs.writeFileSync(htmlPath, htmlContent, 'utf8');

  const fileUrl = 'file:///' + htmlPath.replace(/\\/g, '/');
  const cmd = `"${edgeExe}" --headless --disable-gpu --default-background-color=00000000 --window-size=256,256 --screenshot="${pngPath}" "${fileUrl}"`;
  
  console.log(`Rendering ${icon.name}...`);
  execSync(cmd);
}

console.log('All icons rendered successfully!');
