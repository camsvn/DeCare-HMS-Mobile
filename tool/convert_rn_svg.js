// Converts a react-native-svg JSX component into a plain SVG file.
// Usage: node tool/convert_rn_svg.js <input.tsx> <output.svg>
const fs = require('fs');

const [, , input, output] = process.argv;
let s = fs.readFileSync(input, 'utf8');
const start = s.indexOf('<Svg');
const end = s.indexOf('</Svg>') + '</Svg>'.length;
s = s.slice(start, end);

s = s.replace(/^\s*\/\/.*$/gm, ''); // JSX line comments inside tags
s = s.replace(/\{\.\.\.props\}/g, '');
s = s.replace(/=\{([\d.]+)\}/g, '="$1"'); // width={70.454} -> width="70.454"
s = s.replace(/'/g, '"');

const tags = {
  Svg: 'svg', Path: 'path', Circle: 'circle', G: 'g', Rect: 'rect', Defs: 'defs',
  ClipPath: 'clipPath', Use: 'use', Stop: 'stop', LinearGradient: 'linearGradient',
  Image: 'image', Ellipse: 'ellipse', Line: 'line', Polygon: 'polygon', Polyline: 'polyline',
};
for (const [jsx, svg] of Object.entries(tags)) {
  s = s.replace(new RegExp(`<${jsx}(?=[\\s>/])`, 'g'), `<${svg}`);
  s = s.replace(new RegExp(`</${jsx}>`, 'g'), `</${svg}>`);
}

const attrs = {
  strokeWidth: 'stroke-width', strokeLinecap: 'stroke-linecap', strokeLinejoin: 'stroke-linejoin',
  strokeDasharray: 'stroke-dasharray', strokeMiterlimit: 'stroke-miterlimit',
  fillRule: 'fill-rule', clipRule: 'clip-rule', fillOpacity: 'fill-opacity',
  strokeOpacity: 'stroke-opacity', xlinkHref: 'xlink:href',
};
for (const [jsx, svg] of Object.entries(attrs)) {
  s = s.replace(new RegExp(`\\b${jsx}=`, 'g'), `${svg}=`);
}

// Root <svg>: drop width/height (Flutter sizes by viewBox) and ensure xmlns.
s = s.replace(/<svg([^>]*)>/, (m, inner) => {
  let a = inner.replace(/\s(width|height)="[^"]*"/g, '');
  if (!/xmlns=/.test(a)) a = ` xmlns="http://www.w3.org/2000/svg"${a}`;
  return `<svg${a}>`;
});

fs.writeFileSync(output, s.trim() + '\n');
console.log(`wrote ${output}`);
