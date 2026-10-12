const fs = require('fs');
const path = require('path');

const SHADERS_DIR = path.join(__dirname, '..', 'shaders');
const DIST_DIR = path.join(__dirname, '..', 'dist');
const MEDIA_EXTS = ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.mp4', '.webm', '.mov'];
const SHADER_EXTS = ['.shader', '.hlsl', '.cginc', '.compute', '.glsl'];

function parseProperties(code) {
  const props = [];
  const match = code.match(/Properties\s*\{([\s\S]*?)\n\s*\}/);
  if (!match) return props;

  const block = match[1];
  const re = /(\w+)\s*\(\s*"([^"]*)"\s*,\s*(\w+)(?:\s*\(([^)]*)\))?\s*\)\s*=\s*([^\n}]+)/g;
  let m;
  while ((m = re.exec(block)) !== null) {
    const [, varName, display, type, typeArgs, defaultVal] = m;
    let clean = defaultVal.trim().replace(/\s*\{?\s*$/, '');
    const prop = { var: varName, display, type, default: clean };
    if (typeArgs) {
      const parts = typeArgs.split(',').map(s => s.trim());
      if (type === 'Range' && parts.length >= 2) {
        prop.min = parseFloat(parts[0]);
        prop.max = parseFloat(parts[1]);
      }
    }
    props.push(prop);
  }
  return props;
}

function getShaderName(code) {
  const m = code.match(/Shader\s+"([^"]+)"/);
  return m ? m[1] : null;
}

function classifyMedia(file) {
  const ext = path.extname(file).toLowerCase();
  if (['.mp4', '.webm', '.mov'].includes(ext)) return 'video';
  return 'image';
}

function processShaderDir(dirPath, dirName) {
  const metaPath = path.join(dirPath, 'meta.json');
  if (!fs.existsSync(metaPath)) {
    console.warn(`  [skip] ${dirName}: no meta.json`);
    return null;
  }

  let meta;
  try {
    meta = JSON.parse(fs.readFileSync(metaPath, 'utf-8'));
  } catch (e) {
    console.warn(`  [skip] ${dirName}: meta.json inválido`);
    return null;
  }

  const files = fs.readdirSync(dirPath);
  const shaderFile = files.find(f => SHADER_EXTS.includes(path.extname(f).toLowerCase()));
  let code = '';
  let properties = [];
  let shaderPath = '';

  if (shaderFile) {
    shaderPath = shaderFile;
    code = fs.readFileSync(path.join(dirPath, shaderFile), 'utf-8');
    properties = parseProperties(code);
    if (!meta.name) {
      const parsed = getShaderName(code);
      if (parsed) meta.name = parsed.split('/').pop();
    }
  }

  const mediaDir = path.join(dirPath, 'media');
  const media = [];
  if (fs.existsSync(mediaDir)) {
    for (const f of fs.readdirSync(mediaDir)) {
      if (MEDIA_EXTS.includes(path.extname(f).toLowerCase())) {
        media.push({ file: f, type: classifyMedia(f), path: `shaders/${dirName}/media/${f}` });
      }
    }
  }

  return {
    id: dirName,
    name: meta.name || dirName,
    description: meta.description || '',
    type: meta.type || 'Surface',
    pipeline: meta.pipeline || 'URP',
    format: meta.format || 'HLSL',
    tags: meta.tags || [],
    shaderFile: shaderPath,
    code,
    properties,
    media,
    created: meta.created || new Date().toISOString().split('T')[0]
  };
}

function build() {
  console.log('Shader Vault — Build\n');

  if (!fs.existsSync(DIST_DIR)) fs.mkdirSync(DIST_DIR, { recursive: true });

  const dirs = fs.readdirSync(SHADERS_DIR, { withFileTypes: true })
    .filter(d => d.isDirectory() && !d.name.startsWith('_'))
    .map(d => d.name);

  console.log(`Encontrados: ${dirs.length} shader(s)\n`);

  const shaders = [];
  for (const dir of dirs) {
    console.log(`  Procesando: ${dir}`);
    const result = processShaderDir(path.join(SHADERS_DIR, dir), dir);
    if (result) {
      shaders.push(result);
      console.log(`    ✓ ${result.name} — ${result.properties.length} props, ${result.media.length} media`);
    }
  }

  const data = {
    generated: new Date().toISOString(),
    count: shaders.length,
    shaders
  };

  fs.writeFileSync(path.join(DIST_DIR, 'data.json'), JSON.stringify(data, null, 2));

  fs.copyFileSync(
    path.join(__dirname, '..', 'index.html'),
    path.join(DIST_DIR, 'index.html')
  );

  const shadersDistDir = path.join(DIST_DIR, 'shaders');
  if (!fs.existsSync(shadersDistDir)) fs.mkdirSync(shadersDistDir, { recursive: true });

  for (const shader of shaders) {
    const srcMedia = path.join(SHADERS_DIR, shader.id, 'media');
    const dstMedia = path.join(shadersDistDir, shader.id, 'media');
    if (fs.existsSync(srcMedia)) {
      fs.mkdirSync(dstMedia, { recursive: true });
      for (const f of fs.readdirSync(srcMedia)) {
        if (MEDIA_EXTS.includes(path.extname(f).toLowerCase())) {
          fs.copyFileSync(path.join(srcMedia, f), path.join(dstMedia, f));
        }
      }
    }
  }

  console.log(`\nBuild completo → dist/`);
  console.log(`  data.json: ${shaders.length} shader(s)`);
  console.log(`  index.html: copiado`);
  console.log(`  media: copiados\n`);
}

build();
