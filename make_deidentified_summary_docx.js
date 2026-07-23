const fs = require("fs");
const zlib = require("zlib");

const output = "全局复利踩坑日志-去隐私摘要.docx";

function xml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function zip(entries) {
  const files = [];
  let offset = 0;
  for (const entry of entries) {
    const name = Buffer.from(entry.name, "utf8");
    const data = Buffer.from(entry.data, "utf8");
    const compressed = zlib.deflateRawSync(data);
    const header = Buffer.alloc(30);
    header.writeUInt32LE(0x04034b50, 0);
    header.writeUInt16LE(20, 4);
    header.writeUInt16LE(0x0800, 6);
    header.writeUInt16LE(8, 8);
    header.writeUInt32LE(crc32(data), 14);
    header.writeUInt32LE(compressed.length, 18);
    header.writeUInt32LE(data.length, 22);
    header.writeUInt16LE(name.length, 26);
    files.push({ name, data, compressed, header, offset });
    offset += header.length + name.length + compressed.length;
  }

  const central = [];
  for (const file of files) {
    const header = Buffer.alloc(46);
    header.writeUInt32LE(0x02014b50, 0);
    header.writeUInt16LE(20, 4);
    header.writeUInt16LE(20, 6);
    header.writeUInt16LE(0x0800, 8);
    header.writeUInt16LE(8, 10);
    header.writeUInt32LE(crc32(file.data), 16);
    header.writeUInt32LE(file.compressed.length, 20);
    header.writeUInt32LE(file.data.length, 24);
    header.writeUInt16LE(file.name.length, 28);
    header.writeUInt32LE(file.offset, 42);
    central.push(Buffer.concat([header, file.name]));
  }
  const centralData = Buffer.concat(central);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(centralData.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([
    ...files.flatMap((file) => [file.header, file.name, file.compressed]),
    centralData,
    end,
  ]);
}

function paragraph(text, style, bullet = false) {
  const pStyle = style ? `<w:pPr><w:pStyle w:val="${style}"/>${bullet ? '<w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr>' : ""}</w:pPr>` : "";
  return `<w:p>${pStyle}<w:r><w:t>${xml(text)}</w:t></w:r></w:p>`;
}

const body = [
  paragraph("运营复盘与防错手册", "Title"),
  paragraph("去隐私摘要", "Subtitle"),
  paragraph("本文档提炼可复用的风险控制经验。已移除人员、账号、链接、绝对路径、项目与产品标识、具体指标、金额、日期、平台入口及内部技术细节。", "Normal"),
  paragraph("使用原则", "Heading1"),
  paragraph("将每次已解决的问题记录为可检索的复盘条目，并在新项目启动、重大操作前和异常发生时复查相关经验，避免同类问题重复发生。", "Normal"),
  paragraph("每条复盘应至少记录现象、根因、解决方法和下一次的预防动作；重大问题可补充场景、影响和验证结果。", "Normal"),
  paragraph("运营监控", "Heading1"),
  paragraph("为竞价、预算和异常消耗设定明确上限；对长期无效的活动及时停止或调整，避免持续损耗。", "Normal", true),
  paragraph("排名或流量明显波动时，先验证竞争变化、索引状态和数据完整性，再决定是否调整投入。", "Normal", true),
  paragraph("避免把单一实体或单一词的短期表现当作整体结论，应以组合策略分散风险并持续复查。", "Normal", true),
  paragraph("内容与上架验收", "Heading1"),
  paragraph("上架或内容更新后，应检查搜索索引、曝光和关键字段是否生效；未通过验收前不应假定内容已被平台收录。", "Normal", true),
  paragraph("关键词命名需避免歧义，首次使用前应人工核验实际搜索结果和匹配对象。", "Normal", true),
  paragraph("安全与协作", "Heading1"),
  paragraph("密钥、令牌和其他凭证不得写入代码、文档或会话记录；一旦暴露，应立即轮换并改用受控存储或环境变量。", "Normal", true),
  paragraph("协作系统写入失败时，优先检查访问授权、身份权限和目标资源共享关系。", "Normal", true),
  paragraph("数据与工具可靠性", "Heading1"),
  paragraph("任何单一数据源都可能存在覆盖盲区、临时故障或频率限制；关键结论应准备替代来源并交叉验证。", "Normal", true),
  paragraph("面对无法直接读取的动态页面或画布数据，应优先使用正式导出能力获取结构化文件，而不是依赖脆弱的界面解析。", "Normal", true),
  paragraph("自动化数据处理需要验证字符编码、特殊符号和中间结果的完整性，避免命令解释或编码转换导致数据失真。", "Normal", true),
  paragraph("文件与知识管理", "Heading1"),
  paragraph("将产出、导出文件和运行记录集中存放在受控工作目录，并使用一致命名，避免跨盘散落和残留文件。", "Normal", true),
  paragraph("将重复出现的故障沉淀为检查清单、模板或统一入口脚本，使预防措施成为日常流程的一部分。", "Normal", true),
  paragraph("计划与节奏", "Heading1"),
  paragraph("对具有季节性的品类，应依据历史趋势制定上架、补货和投入节奏；关键阈值和具体数量须以当期数据重新验证。", "Normal"),
  paragraph("公开使用注意", "Heading1"),
  paragraph("对外分享时，不应附带原始项目、商品词、内部账号、API 信息、访问地址、本地目录、具体金额、排名、库存或时间表。", "Normal"),
  paragraph("来源说明", "Heading1"),
  paragraph("本摘要基于用户提供的历史复盘日志整理，仅保留通用防错方法与管理原则。", "Normal"),
].join("");

const document = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>${body}<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr></w:body></w:document>`;

const entries = [
  { name: "[Content_Types].xml", data: `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/><Override PartName="/word/numbering.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml"/><Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/><Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/></Types>` },
  { name: "_rels/.rels", data: `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>` },
  { name: "word/_rels/document.xml.rels", data: `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering" Target="numbering.xml"/></Relationships>` },
  { name: "word/document.xml", data: document },
  { name: "word/styles.xml", data: `<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr><w:rFonts w:ascii="Arial" w:eastAsia="Microsoft YaHei"/><w:sz w:val="22"/></w:rPr></w:rPrDefault></w:docDefaults><w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/></w:style><w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Subtitle"><w:name w:val="Subtitle"/><w:rPr><w:color w:val="666666"/><w:sz w:val="24"/></w:rPr></w:style><w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:rPr><w:b/><w:sz w:val="28"/><w:color w:val="1F4E79"/></w:rPr></w:style></w:styles>` },
  { name: "word/numbering.xml", data: `<?xml version="1.0" encoding="UTF-8"?><w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:abstractNum w:abstractNumId="0"><w:lvl w:ilvl="0"><w:start w:val="1"/><w:numFmt w:val="bullet"/><w:lvlText w:val="•"/><w:lvlJc w:val="left"/><w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr></w:lvl></w:abstractNum><w:num w:numId="1"><w:abstractNumId w:val="0"/></w:num></w:numbering>` },
  { name: "docProps/core.xml", data: `<?xml version="1.0" encoding="UTF-8"?><cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><dc:title>运营复盘与防错手册 - 去隐私摘要</dc:title><dc:creator>Codex</dc:creator><dcterms:created xsi:type="dcterms:W3CDTF">2026-07-14T00:00:00Z</dcterms:created></cp:coreProperties>` },
  { name: "docProps/app.xml", data: `<?xml version="1.0" encoding="UTF-8"?><Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties"><Application>Microsoft Office Word</Application></Properties>` },
];

fs.writeFileSync(output, zip(entries));
console.log(output);
