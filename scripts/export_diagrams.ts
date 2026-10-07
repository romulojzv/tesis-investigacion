import * as fs from 'fs';
import * as path from 'path';

async function exportDiagram(mmdFilename: string, outBasename: string) {
  const mmdPath = path.join(process.cwd(), 'docs', 'semana_8', mmdFilename);
  const content = fs.readFileSync(mmdPath, 'utf-8');
  
  // mermaid.ink supports base64 encoding directly or JSON wrapped
  const base64Str = Buffer.from(content).toString('base64');
  
  // 1. Exportar SVG
  const svgUrl = `https://mermaid.ink/svg/${base64Str}`;
  console.log(`Descargando SVG para ${mmdFilename}...`);
  const svgRes = await fetch(svgUrl);
  if (!svgRes.ok) {
    throw new Error(`Error descargando SVG de ${mmdFilename}: status ${svgRes.status}`);
  }
  const svgText = await svgRes.text();
  const svgOutPath = path.join(process.cwd(), 'docs', 'semana_8', `${outBasename}.svg`);
  fs.writeFileSync(svgOutPath, svgText, 'utf-8');
  console.log(`✅ Guardado: ${svgOutPath} (${svgText.length} bytes)`);

  // 2. Exportar PNG
  const imgUrl = `https://mermaid.ink/img/${base64Str}`;
  console.log(`Descargando PNG para ${mmdFilename}...`);
  const imgRes = await fetch(imgUrl);
  if (imgRes.ok) {
    const imgBuffer = Buffer.from(await imgRes.arrayBuffer());
    const imgOutPath = path.join(process.cwd(), 'docs', 'semana_8', `${outBasename}.png`);
    fs.writeFileSync(imgOutPath, imgBuffer);
    console.log(`✅ Guardado: ${imgOutPath} (${imgBuffer.length} bytes)`);
  } else {
    console.warn(`⚠️ PNG no disponible para ${mmdFilename} (status ${imgRes.status}), SVG exportado exitosamente.`);
  }
}

async function main() {
  await exportDiagram('diagrama_componentes.mmd', 'diagrama_componentes');
  await exportDiagram('diagrama_despliegue.mmd', 'diagrama_despliegue');
  console.log('🎉 Diagramas exportados correctamente.');
}

main().catch((err) => {
  console.error('Error al exportar diagramas:', err);
  process.exit(1);
});
