// ============================================================
// 通用 docx 构建器模板（v3）
//
// 用法：在某篇文献的目录里创建 build.js，require 本模块，
//       传入"内容对象"即可生成标准格式的 解读_全中文版.docx
//
// 内容对象结构见底部 sampleContent
// ============================================================

const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, LevelFormat, HeadingLevel, BorderStyle,
  WidthType, ShadingType, PageNumber, PageBreak, TableOfContents,
  ImageRun,
} = require('docx');
const fs = require('fs');
const path = require('path');

// ============ 字体与配色 ============
const FONT_CJK = 'PingFang SC';
const COLOR_PRIMARY = '1F3864';
const COLOR_ACCENT = 'C00000';
const COLOR_GRAY = '595959';
const COLOR_TABLE_HEAD = 'D9E2F3';

// ============ 段落工具 ============
const h1 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_1,
  children: [new TextRun({ text, font: FONT_CJK, bold: true, size: 32, color: COLOR_PRIMARY })],
  spacing: { before: 360, after: 200 },
});

const h2 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_2,
  children: [new TextRun({ text, font: FONT_CJK, bold: true, size: 26, color: COLOR_PRIMARY })],
  spacing: { before: 300, after: 160 },
});

const h3 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_3,
  children: [new TextRun({ text, font: FONT_CJK, bold: true, size: 22, color: COLOR_PRIMARY })],
  spacing: { before: 220, after: 120 },
});

const h4 = (text) => new Paragraph({
  heading: HeadingLevel.HEADING_4,
  children: [new TextRun({ text, font: FONT_CJK, bold: true, size: 19, color: COLOR_GRAY })],
  spacing: { before: 160, after: 80 },
});

const p = (text) => new Paragraph({
  children: [new TextRun({ text, font: FONT_CJK, size: 22 })],
  spacing: { line: 360, after: 120 },
  alignment: AlignmentType.JUSTIFIED,
});

const pBold = (text) => new Paragraph({
  children: [new TextRun({ text, font: FONT_CJK, size: 22, bold: true })],
  spacing: { line: 360, after: 120 },
});

const pAccent = (text) => new Paragraph({
  children: [new TextRun({ text, font: FONT_CJK, size: 22, bold: true, color: COLOR_ACCENT })],
  spacing: { line: 360, after: 120 },
});

const quote = (text, source = '') => {
  const children = [new TextRun({ text: '「' + text + '」', font: FONT_CJK, size: 22, italics: true, color: COLOR_GRAY })];
  if (source) {
    children.push(new TextRun({ text: '  —— ' + source, font: FONT_CJK, size: 20, color: COLOR_GRAY }));
  }
  return new Paragraph({
    children,
    spacing: { line: 360, before: 80, after: 200 },
    indent: { left: 480, right: 240 },
    border: { left: { style: BorderStyle.SINGLE, size: 12, color: COLOR_PRIMARY, space: 12 } },
  });
};

const bullet = (text, level = 0) => new Paragraph({
  numbering: { reference: 'bullets', level },
  children: [new TextRun({ text, font: FONT_CJK, size: 22 })],
  spacing: { line: 320, after: 60 },
});

const numbered = (text, level = 0) => new Paragraph({
  numbering: { reference: 'numbers', level },
  children: [new TextRun({ text, font: FONT_CJK, size: 22 })],
  spacing: { line: 320, after: 60 },
});

const pageBreak = () => new Paragraph({ children: [new PageBreak()] });

// ============ 图片工具（新增 v3.1）============
//
// 嵌入 PDF 截图。imgPath 是相对 build.js 的相对路径或绝对路径。
// caption 是图下方的说明文字。
// width/height 是显示像素（默认 480x600，A4 适中）。
//
const imageBlock = (imgPath, caption = '', opts = {}) => {
  // 解析路径
  const fullPath = path.isAbsolute(imgPath) ? imgPath : path.resolve(process.cwd(), imgPath);

  if (!fs.existsSync(fullPath)) {
    console.warn(`⚠️  图片不存在: ${fullPath} —— 用占位段落替代`);
    return [new Paragraph({
      children: [new TextRun({
        text: `［图片缺失: ${imgPath}］${caption ? ' · ' + caption : ''}`,
        font: FONT_CJK, size: 20, color: COLOR_ACCENT, italics: true
      })],
      spacing: { after: 200 },
    })];
  }

  // 检测图片类型
  const ext = path.extname(fullPath).toLowerCase().replace('.', '');
  const validExts = ['png', 'jpg', 'jpeg', 'gif', 'bmp'];
  if (!validExts.includes(ext)) {
    console.warn(`⚠️  不支持的图片格式: ${ext}`);
    return [];
  }

  const data = fs.readFileSync(fullPath);
  const width = opts.width || 480;
  const height = opts.height || 600;

  // 图片本体
  const imgPara = new Paragraph({
    children: [new ImageRun({
      type: ext === 'jpg' ? 'jpeg' : ext,
      data,
      transformation: { width, height },
      altText: { title: caption, description: caption, name: path.basename(fullPath) },
    })],
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 60 },
  });

  // 图说
  const blocks = [imgPara];
  if (caption) {
    blocks.push(new Paragraph({
      children: [new TextRun({
        text: '图：' + caption,
        font: FONT_CJK, size: 18, italics: true, color: COLOR_GRAY,
      })],
      alignment: AlignmentType.CENTER,
      spacing: { after: 240 },
    }));
  }
  return blocks;
};

// ============ 表格工具 ============
const tBorder = { style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF' };
const tBorders = { top: tBorder, bottom: tBorder, left: tBorder, right: tBorder, insideHorizontal: tBorder, insideVertical: tBorder };

const cell = (text, opts = {}) => {
  const isHeader = opts.header || false;
  const width = opts.width;
  const textArr = Array.isArray(text) ? text : [text];
  return new TableCell({
    width: width ? { size: width, type: WidthType.DXA } : undefined,
    borders: tBorders,
    shading: isHeader ? { fill: COLOR_TABLE_HEAD, type: ShadingType.CLEAR } : undefined,
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    children: textArr.map(t => new Paragraph({
      children: [new TextRun({ text: t, font: FONT_CJK, size: 20, bold: isHeader })],
      spacing: { line: 300 },
    })),
  });
};

const makeTable = (columnWidths, rows) => {
  const total = columnWidths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: total, type: WidthType.DXA },
    columnWidths,
    rows: rows.map((row, i) => new TableRow({
      tableHeader: i === 0,
      children: row.map((c, j) => cell(c, { width: columnWidths[j], header: i === 0 })),
    })),
  });
};

// ============ 解析"段落数组" ============
// 一篇文献的内容用一个数组表达，每个元素是 { type, ...args }
// 支持的 type：h1/h2/h3/h4/p/pBold/pAccent/quote/bullet/numbered/pageBreak/table
function renderBlocks(blocks) {
  const result = [];
  for (const b of blocks) {
    if (typeof b === 'string') {
      result.push(p(b));
      continue;
    }
    switch (b.type) {
      case 'h1': result.push(h1(b.text)); break;
      case 'h2': result.push(h2(b.text)); break;
      case 'h3': result.push(h3(b.text)); break;
      case 'h4': result.push(h4(b.text)); break;
      case 'p': result.push(p(b.text)); break;
      case 'pBold': result.push(pBold(b.text)); break;
      case 'pAccent': result.push(pAccent(b.text)); break;
      case 'quote': result.push(quote(b.text, b.source || '')); break;
      case 'bullet': result.push(bullet(b.text, b.level || 0)); break;
      case 'numbered': result.push(numbered(b.text, b.level || 0)); break;
      case 'pageBreak': result.push(pageBreak()); break;
      case 'table': result.push(makeTable(b.columnWidths, b.rows)); break;
      case 'image':
        // image block 返回 2 段（图 + 图说），需要展开
        for (const seg of imageBlock(b.path, b.caption, b.opts || {})) {
          result.push(seg);
        }
        break;
      default:
        console.warn('Unknown block type:', b.type);
    }
  }
  return result;
}

// ============ 主函数：生成 docx ============
//
// content: {
//   title: string,        // 主标题（出现在封面 + 页眉）
//   subtitle: string,     // 副标题
//   author: string,       // 原作者
//   advisor: string,      // 指导教授（可选）
//   institution: string,  // 原作机构
//   year: number,         // 原作年份
//   readingLevel: string, // 阅读档位
//   blocks: Array,        // 正文段落块数组
//   outputPath: string,   // 输出路径
// }
//
function generateDocx(content) {
  const cover = [
    new Paragraph({ children: [new TextRun('')], spacing: { before: 1200 } }),
    new Paragraph({
      children: [new TextRun({ text: content.title, font: FONT_CJK, size: 56, bold: true, color: COLOR_PRIMARY })],
      alignment: AlignmentType.CENTER, spacing: { after: 200 },
    }),
    new Paragraph({
      children: [new TextRun({ text: content.subtitle || '— 深度解读 · 全中文版 —', font: FONT_CJK, size: 28, color: COLOR_GRAY })],
      alignment: AlignmentType.CENTER, spacing: { after: 800 },
    }),
    new Paragraph({
      children: [new TextRun({ text: '原作者：' + content.author, font: FONT_CJK, size: 24 })],
      alignment: AlignmentType.CENTER, spacing: { after: 80 },
    }),
    ...(content.advisor ? [new Paragraph({
      children: [new TextRun({ text: '指导教授：' + content.advisor, font: FONT_CJK, size: 24 })],
      alignment: AlignmentType.CENTER, spacing: { after: 80 },
    })] : []),
    new Paragraph({
      children: [new TextRun({ text: '原作机构：' + content.institution, font: FONT_CJK, size: 24 })],
      alignment: AlignmentType.CENTER, spacing: { after: 80 },
    }),
    new Paragraph({
      children: [new TextRun({ text: '原作年份：' + content.year, font: FONT_CJK, size: 24 })],
      alignment: AlignmentType.CENTER, spacing: { after: 800 },
    }),
    new Paragraph({
      children: [new TextRun({ text: '解读完成日期：' + (content.readingDate || new Date().toISOString().slice(0,10)), font: FONT_CJK, size: 22, color: COLOR_GRAY })],
      alignment: AlignmentType.CENTER,
    }),
    new Paragraph({
      children: [new TextRun({ text: '采用阅读档位：' + (content.readingLevel || '三档（全文精读 + 虚拟再实现）'), font: FONT_CJK, size: 22, color: COLOR_GRAY })],
      alignment: AlignmentType.CENTER,
    }),
    new Paragraph({ children: [new PageBreak()] }),
  ];

  const toc = [
    h1('目录'),
    new TableOfContents('Table of Contents', { hyperlink: true, headingStyleRange: '1-3' }),
    new Paragraph({ children: [new PageBreak()] }),
  ];

  const header = new Header({
    children: [
      new Paragraph({
        children: [new TextRun({ text: content.title + ' · 深度解读', font: FONT_CJK, size: 18, color: COLOR_GRAY })],
        alignment: AlignmentType.RIGHT,
        border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: COLOR_GRAY, space: 1 } },
      }),
    ],
  });

  const footer = new Footer({
    children: [
      new Paragraph({
        children: [
          new TextRun({ text: '第 ', font: FONT_CJK, size: 18, color: COLOR_GRAY }),
          new TextRun({ children: [PageNumber.CURRENT], font: FONT_CJK, size: 18, color: COLOR_GRAY }),
          new TextRun({ text: ' 页 / 共 ', font: FONT_CJK, size: 18, color: COLOR_GRAY }),
          new TextRun({ children: [PageNumber.TOTAL_PAGES], font: FONT_CJK, size: 18, color: COLOR_GRAY }),
          new TextRun({ text: ' 页', font: FONT_CJK, size: 18, color: COLOR_GRAY }),
        ],
        alignment: AlignmentType.CENTER,
      }),
    ],
  });

  const doc = new Document({
    styles: {
      default: { document: { run: { font: FONT_CJK, size: 22 } } },
      paragraphStyles: [
        { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 32, bold: true, font: FONT_CJK, color: COLOR_PRIMARY },
          paragraph: { spacing: { before: 360, after: 200 }, outlineLevel: 0 } },
        { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 26, bold: true, font: FONT_CJK, color: COLOR_PRIMARY },
          paragraph: { spacing: { before: 300, after: 160 }, outlineLevel: 1 } },
        { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 22, bold: true, font: FONT_CJK, color: COLOR_PRIMARY },
          paragraph: { spacing: { before: 220, after: 120 }, outlineLevel: 2 } },
        { id: 'Heading4', name: 'Heading 4', basedOn: 'Normal', next: 'Normal', quickFormat: true,
          run: { size: 19, bold: true, font: FONT_CJK, color: COLOR_GRAY },
          paragraph: { spacing: { before: 160, after: 80 }, outlineLevel: 3 } },
      ],
    },
    numbering: {
      config: [
        { reference: 'bullets',
          levels: [
            { level: 0, format: LevelFormat.BULLET, text: '•', alignment: AlignmentType.LEFT,
              style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
            { level: 1, format: LevelFormat.BULLET, text: '◦', alignment: AlignmentType.LEFT,
              style: { paragraph: { indent: { left: 1440, hanging: 360 } } } },
          ] },
        { reference: 'numbers',
          levels: [
            { level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
              style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
          ] },
      ],
    },
    sections: [{
      properties: {
        page: {
          size: { width: 11906, height: 16838 },
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
        },
      },
      headers: { default: header },
      footers: { default: footer },
      children: [
        ...cover,
        ...toc,
        ...renderBlocks(content.blocks),
      ],
    }],
  });

  return Packer.toBuffer(doc).then(buf => {
    fs.writeFileSync(content.outputPath, buf);
    return { path: content.outputPath, size: buf.length };
  });
}

module.exports = {
  generateDocx,
  // 同时把工具函数导出，便于在 content 里嵌入复杂结构
  blocks: {
    h1: (text) => ({ type: 'h1', text }),
    h2: (text) => ({ type: 'h2', text }),
    h3: (text) => ({ type: 'h3', text }),
    h4: (text) => ({ type: 'h4', text }),
    p: (text) => ({ type: 'p', text }),
    pBold: (text) => ({ type: 'pBold', text }),
    pAccent: (text) => ({ type: 'pAccent', text }),
    quote: (text, source) => ({ type: 'quote', text, source }),
    bullet: (text, level = 0) => ({ type: 'bullet', text, level }),
    numbered: (text, level = 0) => ({ type: 'numbered', text, level }),
    pageBreak: () => ({ type: 'pageBreak' }),
    table: (columnWidths, rows) => ({ type: 'table', columnWidths, rows }),
    image: (imgPath, caption = '', opts = {}) => ({ type: 'image', path: imgPath, caption, opts }),
  },
};
