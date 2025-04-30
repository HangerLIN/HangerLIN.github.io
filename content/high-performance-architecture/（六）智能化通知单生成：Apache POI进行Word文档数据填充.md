# 文档填充术：使用Apache POI实现Word字段精准数据填充

### 引言

在现代软件开发实践中，自动化文档处理已成为提高效率和准确性的关键手段。无论是生成报告、发票还是个性化的通信文件，自动化都能显著减少重复性劳动并增加生产力。为了实现这一目标，Apache POI库提供了一套强大的工具，使得Java开发者能够轻松创建、修改和显示MS Office文档。本文将探讨如何利用Apache POI进行高效的Word文档数据填充，特别是在企业级应用中处理大量文档时的优化技术。



#### 业务场景

在教育机构和企业的日常运营中，办公自动化（OA）系统在提升文件处理效率和准确性方面发挥着至关重要的作用。特别是在管理学生事务时，频繁需要根据具体场景生成多种类型的通知单。例如，学生的学籍变动——如转专业、休学或复学——都需要通过正式的通知单来进行沟通。

笔者在此类业务场景下观察到，传统的手动处理方式不仅耗时耗力，而且极易因人为因素导致信息错误。因此，笔者在笔者复杂的OA子系统中集成Apache POI，以自动化的方式对各类Word格式的学生通知单进行数据填充。这一自动化实践不仅大幅提高了处理速度，而且显著增强了数据处理的准确性，确保了学生能够及时且正确地收到每一份通知。



#### 为什么选择Apache POI

Apache POI是处理Microsoft Office文档格式的领先库之一，特别是对于需要在Java应用程序中处理Excel和Word文件的开发者。它支持从旧的HSSF（Horrible SpreadSheet Format）到新的XSSF（XML SpreadSheet Format）的所有主要Office文件格式。笔者选择Apache POI的主要理由包括：

- **全面性**：Apache POI不仅支持文档的读写操作，还能处理复杂的格式和数据结构，如表格、图表、图片、超链接等。
- **高级API**：POI提供了基于DOM（文档对象模型）的API，允许开发者以抽象的方式处理文档，使得代码更简洁、更易于理解和维护。
- **社区和稳定性**：作为一个长期由Apache软件基金会支持的项目，POI拥有一个活跃的社区和稳定的开发周期，这为企业级应用提供了必要的信心。



实际上，像很有名的EasyExcel这个中间件都是封装Apache POI实现的。EasyExcel 是一个基于 Apache POI 的开源库，它为处理 Excel 文件提供了更简单、更高效的方法。EasyExcel 主要针对大数据量的读写进行了优化，使得在处理大型 Excel 文件时，内存使用更低，性能更优。我们可以从Apache POI的使用中进一步了解EasyExcel的设计哲学。

它在性能优化、简化API以及内存管理方面做出了创新，实现了“青出于蓝而胜于蓝”的效果。以下是具体的几个点，通过对比Apache POI和EasyExcel的代码实现和设计，可以进一步理解EasyExcel的设计理念：

##### 1. **基于流的读写**

EasyExcel 采用了基于SAX（Simple API for XML）解析模式的读写方式，这种方式不需要将整个文档加载到内存中，从而显著减少内存消耗。

**Apache POI 示例**（加载整个Excel文件到内存）:
```java
InputStream inp = new FileInputStream("workbook.xlsx");
Workbook wb = WorkbookFactory.create(inp);
Sheet sheet = wb.getSheetAt(0);
Row row = sheet.getRow(2);
Cell cell = row.getCell(3);
```

**EasyExcel 示例**（使用事件驱动模型，按行读取，减少内存使用）:
```java
EasyExcel.read(filename, new ReadListener<RowData>() {
    @Override
    public void invoke(RowData data, AnalysisContext context) {
        System.out.println("读取到一行数据：" + data);
    }

    @Override
    public void doAfterAllAnalysed(AnalysisContext context) {
        System.out.println("所有数据解析完成！");
    }
}).sheet().doRead();
```

##### 2. **简化API**

EasyExcel 的 API 设计更为简洁直观，使得开发者能够更快速地实现Excel的读写操作，降低学习和使用的门槛。

**Apache POI 示例**（写入Excel文件）:
```java
Workbook wb = new XSSFWorkbook();
Sheet sheet = wb.createSheet("New Sheet");
Row row = sheet.createRow(0);
Cell cell = row.createCell(0);
cell.setCellValue("Hello World!");

FileOutputStream fileOut = new FileOutputStream("workbook.xlsx");
wb.write(fileOut);
fileOut.close();
```

**EasyExcel 示例**（写入Excel文件）:
```java
// 定义数据列表
List<SomeData> data = Arrays.asList(new SomeData("Hello World!"));
// 写入操作
EasyExcel.write("workbook.xlsx", SomeData.class).sheet("New Sheet").doWrite(data);
```



##### 3. **性能优化**

EasyExcel 对于性能的优化表现在其对大数据量处理的支持。使用写入时的分批处理和读取时的缓存机制，有效管理资源消耗。

**Apache POI 示例**（处理大数据量时可能会导致内存溢出）:
```java
Workbook wb = new XSSFWorkbook();
Sheet sheet = wb.createSheet("Big Data");
for (int rowNum = 0; rowNum < 100000; rowNum++) {
    Row row = sheet.createRow(rowNum);
    for (int cellNum = 0; cellNum < 10; cellNum++) {
        Cell cell = row.createCell(cellNum);
        cell.setCellValue("Data " + rowNum + cellNum);
    }
}
FileOutputStream fileOut = new FileOutputStream("bigdata.xlsx");
wb.write(fileOut);
fileOut.close();
```

**EasyExcel 示例**（使用分批处理和内存优化）:
```java
// 定义一个模型类来承载数据
List<BigData> data = // 初始化一些大数据
EasyExcel.write("bigdata.xlsx", BigData.class)
         .sheet("Big Data")
         .doWrite(() -> {
             // 分批查询数据库或处理数据
             return fetchSomeData();
         });
```

但是本篇文章重点在于如何使用Apache POI，不再赘述。



### Apache POI简介

Apache POI，一个开源的Java库，旨在为广大开发者提供一种有效的手段来处理所有Microsoft Office格式的文档。POI代表Poor Obfuscation Implementation，这一名称幽默地反映了最初的目标——解读和理解微软的文件格式。

#### 什么是Apache POI？

Apache POI是专为Java平台设计，用以读取和写入Microsoft Office文件格式的一套API。它包括多个组件，每个组件针对不同Office程序的文件格式。利用Apache POI，开发者可以在不需要Microsoft Office软件的情况下，创建、修改或读取Excel、Word和其他Office文档。这对于需要在服务器端自动处理Office文档的应用程序尤其有价值，例如自动报告生成、数据分析应用和内容管理系统。

#### Apache POI支持的文档类型

Apache POI支持广泛的文档类型，覆盖了Office套件中的多个主要应用。具体包括：

- **HSSF 和 XSSF**：用于处理Excel文件（`.xls` 和 `.xlsx`），其中HSSF是处理Excel 97-2003文件，而XSSF是针对Excel 2007及以后版本的文件格式。
- **HWPF 和 XWPF**：用于操作Word文件（`.doc` 和 `.docx`），HWPF用于Word 97-2003格式，XWPF适用于Word 2007及后续版本。
- **HSLF 和 XSLF**：分别处理PowerPoint演示文稿（`.ppt` 和 `.pptx`）。
- **其他组件**：如HDGF和HPBF等，分别用于处理Visio和Publisher文件等特定格式。

#### 主要功能和用途

Apache POI的核心功能不仅限于文件格式的读写。它还包括对复杂文件结构的支持，如图表、图片、嵌入的对象处理等。此外，Apache POI提供了丰富的接口和类，使得开发者可以：

- **生成和修改文档**：自动创建文档，填充数据，修改现有内容，应用样式和布局。
- **数据抽取**：从复杂的文档结构中提取文本、表格和其他媒体内容，用于进一步的处理或展示。
- **文档合并和拆分**：在不同的文档之间复制部分或全部内容，合并多个文件成一个，或将一个文件拆分成多个部分。

通过利用Apache POI，笔者能够在Java应用程序中实现高级的Office文档处理功能，无需借助Office软件本身，从而极大地提升了开发的灵活性和效率。在接下来的部分中，笔者将详细介绍Apache POI操作Word文档的核心组件，以及如何通过编程实现对Word文档的动态数据填充。



### Apache POI的核心组件：三个List结构

![image-20240525145435302](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240525145435302.png)

在处理Microsoft Word文档的自动化过程中，Apache POI提供了一系列的高级API，这些API是操作.docx文件的核心。在本节中，笔者将详细介绍三个关键的组件：`XWPFDocument`、`XWPFParagraph`和`XWPFRun`。这些组件各自承担着不同的职责，并共同构成了Apache POI中处理Word文档的基础。

#### XWPFDocument：文档对象模型的入口点

`XWPFDocument`是这一层级结构的顶层，代表整个Word文档。在Apache POI的上下文中，`XWPFDocument`实例是操作.docx文件的入口点。一个`XWPFDocument`实例可以包含多个`XWPFParagraph`实例，每个实例对应文档中的一个段落。

**数据结构**：在`XWPFDocument`中，段落是以列表的形式存储的，这个列表通常是`ArrayList`类型。这种结构选择利于快速随机访问和高效的遍历，同时也方便在特定位置插入或删除段落。

```java
// 加载现有文档
XWPFDocument doc = new XWPFDocument(new FileInputStream("existing_document.docx"));

// 创建新文档
XWPFDocument newDoc = new XWPFDocument();
```

#### XWPFParagraph：段落处理

`XWPFParagraph`位于层级结构的中间层，代表文档中的一个单独段落。每个`XWPFParagraph`可以包含多个`XWPFRun`对象，每个对象代表一段具有统一格式的连续文本。

**数据结构**：与`XWPFDocument`相似，`XWPFParagraph`使用列表来存储其下属的`XWPFRun`实例，这些实例代表不同的文本运行。这样的存储方式优化了文本格式修改的处理，例如加粗、斜体或下划线，每个`XWPFRun`可以有独立的格式设置。

```java
// 创建一个新段落
XWPFParagraph paragraph = newDoc.createParagraph();
paragraph.setAlignment(ParagraphAlignment.CENTER);

// 向段落中添加文本
XWPFRun run = paragraph.createRun();
run.setText("Welcome to Apache POI!");
run.setBold(true);
```

#### XWPFRun：文本运行和格式

`XWPFRun`是层级结构中的最底层，它直接与文本内容和格式设置相关联。`XWPFRun`封装了一系列具有相同属性（如字体、大小、颜色、样式等）的文本。一个`XWPFRun`可以是一个词、一个句子或任何连续的文本片段，这取决于需要应用的格式。

**数据结构**：尽管`XWPFRun`不存储其他`XWPFRun`对象，它在`XWPFParagraph`的上下文中以列表形式存在，使得段落内的文本编辑和格式化变得灵活和精确。

```java
// 向段落中添加文本运行
XWPFRun run2 = paragraph.createRun();
run2.setText(" This text will be italic and underlined.");
run2.setItalic(true);
run2.setUnderline(UnderlinePatterns.SINGLE);
```





### 实现数据填充的步骤

#### 用例图

![image-20240525151654198](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240525151654198.png)



#### 流程实现

![image-20240525151943999](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240525151943999.png)



先准备一份文档，内部的英文字段都是在VO中定义好的字段。

当我们，传入对应的VO对象的时候，都会按照VO中的每一个数据进行填充到文档之中。

![image-20240525152341262](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240525152341262.png)



完整代码如下： `generateNotificationForm` 中，这个方法设计用于生成通知单，并且它接受四个参数。这四个参数是该功能的核心部分。见注释：

```java
    /**
     * 生成通知单
     *
     * @param approvalRecordPO 审核记录
     * @param record           通知单填充实体，之所以设置为record，是因为允许传入不同的记录，使得实现“多态”的操作
     * @param username         通知用户的username，设置为最后审批的用户
     * @param configKey		   存储在Minio中模版的名称，用于获取模板
     */
    protected void generateNotificationForm(ApprovalRecordPO approvalRecordPO, Object record, String username, String configKey) {
        log.info("生成通知单 approvalRecord {} resumptionRecord {}", approvalRecordPO, record);
        GlobalConfigPO globalConfigPO = globalConfigMapper.selectOne(Wrappers.<GlobalConfigPO>lambdaQuery().eq(GlobalConfigPO::getConfigKey, configKey));
        if (Objects.isNull(globalConfigPO)) {
            throw new BusinessException("获取通知书模版失败");
        }
        String templatePath = globalConfigPO.getConfigValue();
        InputStream templateInputStream = minioService.getFileInputStreamFromMinio(templatePath);
        if (Objects.isNull(templateInputStream)) {
            log.info("无法获取到模板文件");
            return;
        }
        ByteArrayOutputStream fileOutputStream = new ByteArrayOutputStream();
        Map<String, Object> map = BeanUtil.beanToMap(record, false, true);
        // 使用poi填充模板文件
        try (XWPFDocument doc = new XWPFDocument(templateInputStream)) {
            List<XWPFParagraph> paragraphs = doc.getParagraphs();
            if (CollUtil.isNotEmpty(paragraphs)) {
                for (XWPFParagraph paragraph : paragraphs) {
                    List<XWPFRun> runs = paragraph.getRuns();
                    if (CollUtil.isEmpty(runs)) {
                        continue;
                    }
                    for (XWPFRun run : runs) {
                        String text = run.getText(ZERO_INT);
                        if (StrUtil.isNotBlank(text)) {
                            for (Map.Entry<String, Object> entry : map.entrySet()) {
                                text = text.replace(entry.getKey(), entry.getValue().toString());
                            }
                            run.setText(text, ZERO_INT);
                        }
                    }
                }
            }
            doc.write(fileOutputStream);
        } catch (Exception e) {
            throw new BusinessException(e);
        }
        // 上传到minio中
        String bucketName = MinioBucketEnum.OA_NOTIFICATION.getBucketName();
        String subDirectory = MinioBucketEnum.OA_NOTIFICATION.getSubDirectory();
        Date date = new Date();
        String filename = subDirectory + "/" + approvalRecordPO.getInitiatorUsername() + "_" + DateUtil.format(date, "yyyy-MM-dd") + "_" + configKey + ".docx";
        ByteArrayInputStream uploadInputStream = new ByteArrayInputStream(fileOutputStream.toByteArray());
        boolean uploaded = minioService.uploadStreamToMinio(uploadInputStream, filename, bucketName);
        log.info("上传结果 {}", uploaded);
        // 发送消息通知用户
        if (!uploaded) {
            throw new BusinessException("上传minio失败");
        }
        Long downloadMessageId = downloadMessageService.createDownloadMessage(DownloadMessageRO.builder()
                .createdAt(date)
                .fileName(DownloadFileNameEnum.OA_NOTIFICATION.getFilename())
                .fileMinioUrl(bucketName + "/" + filename)
                .fileSize((long) fileOutputStream.size())
                .build());
        log.info("插入OA通知单下载信息 download message id {}", downloadMessageId);
        int count = platformMessageMapper.insert(PlatformMessagePO.builder()
                .createdAt(date)
                .userId(String.valueOf(platformUserService.getUserIdByUsername(username)))
                .relatedMessageId(downloadMessageId)
                .isRead(false)
                .messageType(MessageEnum.DOWNLOAD_MSG.getMessageName())
                .build());
        if (count <= 0) {
            throw new BusinessException("插入平台消息失败");
        }
    }
```



PS：如何实现多态，看笔者的传参就知道了，只是因为没有限制，所以不要乱传奇怪的Object对象，这个时候需要规约清楚。





下面，笔者将详细描述如何使用Apache POI库结合Java代码来实现Word文档的自动数据填充。

#### 读取Word模板：加载文档和获取段落

首先，系统需要从存储服务（如Minio）中加载Word模板文件。这一步骤是通过调用存储服务API获取文件的输入流实现的，这里以`minioService.getFileInputStreamFromMinio`为例。一旦模板加载成功，使用`XWPFDocument`对象来解析和准备文档结构。

```java
InputStream templateInputStream = minioService.getFileInputStreamFromMinio(templatePath);
if (Objects.isNull(templateInputStream)) {
    log.info("无法获取到模板文件");
    return;
}
XWPFDocument doc = new XWPFDocument(templateInputStream);
```



#### 文本替换逻辑：如何遍历XWPFRun进行数据替换

文档中的每个段落（`XWPFParagraph`）包含一个或多个文本运行（`XWPFRun`），这些文本运行是实际文本和格式化信息的承载体。笔者通过遍历每个段落和运行，检查其中的文本，并将包含特定占位符的文本替换为动态数据。

```java
List<XWPFParagraph> paragraphs = doc.getParagraphs();
for (XWPFParagraph paragraph : paragraphs) {
    List<XWPFRun> runs = paragraph.getRuns();
    for (XWPFRun run : runs) {
        String text = run.getText(0);
        if (StrUtil.isNotBlank(text)) {
            for (Map.Entry<String, Object> entry : map.entrySet()) {
                text = text.replace(entry.getKey(), entry.getValue().toString());
            }
            run.setText(text, 0);
        }
    }
}
```



#### 填充数据到模板：遍历键值对替换文本

数据填充过程中，笔者首先将需要填充的数据转换为键值对的形式（即`Map<String, Object>`）。这些数据通常来源于业务对象或数据库查询结果。随后，笔者将这些键值对与文档中的占位符进行匹配和替换。

```java
Map<String, Object> map = BeanUtil.beanToMap(record, false, true);
```



#### 保存和导出新文档

数据替换完成后，笔者将修改后的文档写入到一个输出流中，并将其上传回Minio服务，然后生成下载链接供前端使用。

```java
ByteArrayOutputStream fileOutputStream = new ByteArrayOutputStream();
doc.write(fileOutputStream);
ByteArrayInputStream uploadInputStream = new ByteArrayInputStream(fileOutputStream.toByteArray());
boolean uploaded = minioService.uploadStreamToMinio(uploadInputStream, filename, bucketName);
```



#### 整体流程的业务触发

此自动化过程被集成在OA系统中，审批完成后自动生成通知单并通知相关用户。具体调用消息见上几篇文章的下载消息部分。

```java
Long downloadMessageId = downloadMessageService.createDownloadMessage(DownloadMessageRO.builder()
    .createdAt(date)
    .fileName(DownloadFileNameEnum.OA_NOTIFICATION.getFilename())
    .fileMinioUrl(bucketName + "/" + filename)
    .fileSize((long) fileOutputStream.size())
    .build());
```



上传生成的文件到Minio以及从Minio下载Word模板的函数逻辑在第一章已经讲解过，不再赘述，有需要的朋友可以参考这篇文章~

[（一）高效异步：利用消息队列优化大规模Excel文件下载_文件下载能用消息队列么-CSDN博客](https://blog.csdn.net/weixin_59736343/article/details/138324227?spm=1001.2014.3001.5501)

![image-20240525150312184](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240525150312184.png)



### 深入文本替换策略

在开发办公自动化系统时，处理文档中的文本替换是一个核心任务。Apache POI提供的功能强大，但在实际应用中，开发者往往需要对其进行深入理解和适当优化，以适应复杂的业务需求。在本节中，笔者将探讨Apache POI文本替换的内部机制。

#### 替换机制的内部工作原理

在Apache POI中，文本替换主要通过`XWPFRun`对象进行，也就是最底层的概念。这些`XWPFRun`按顺序排列，共同构成段落的内容。进行文本替换时，遍历所有段落和它们的运行，寻找与预定模式匹配的文本，然后进行替换：

```java
for (XWPFParagraph paragraph : doc.getParagraphs()) {
    for (XWPFRun run : paragraph.getRuns()) {
        String text = run.getText(0);
        if (text != null) {
            text = text.replace("{{placeholder}}", "replacement");
            run.setText(text, 0);
        }
    }
}
```



#### 处理复杂替换场景（如跨运行的文本）

在某些情况下，**需要替换的文本可能跨越多个`XWPFRun`（虽然本章没有出现）。**这种情况下，简单的替换策略可能不起作用，因为单个`XWPFRun`只包含部分目标文本。处理此类复杂场景需要更高级的逻辑：

1. **合并运行**：首先，可以考虑将包含目标文本的连续运行合并为一个运行，然后进行替换。
2. **预处理文本**：在进行替换之前，先对整个段落的文本进行合并和预处理，以确保替换逻辑可以应用于完整的文本串。

```java
StringBuilder fullText = new StringBuilder();
List<XWPFRun> runs = paragraph.getRuns();
for (XWPFRun run : runs) {
    fullText.append(run.getText(0));
}
String updatedText = fullText.toString().replace("{{placeholder}}", "replacement");

// 重新设置运行文本
int runIndex = 0;
for (XWPFRun run : runs) {
    run.setText("", 0); // 清除原文本
    if (runIndex == 0) {
        run.setText(updatedText, 0); // 只在第一个运行中设置更新后的文本
    }
    runIndex++;
}
```



### 结语

在本文中，笔者详细探讨了Apache POI这一强大的Java库在办公自动化系统中的应用，特别是在自动填充Word文档数据的过程中所展现的高效性和准确性。通过一系列深入的技术解析和示例代码，我们不仅了解了如何使用Apache POI处理复杂的Word文档操作，还探讨了在面对大数据量处理时的性能优化策略。

此外，通过对比Apache POI和基于其封装的EasyExcel，展示了开源社区在持续进步中如何“青出于蓝而胜于蓝”（里面的监听器很有意思，希望有空自己也能深入学习一下）。

总之，无论是开发人员还是业务运营者，了解并掌握如Apache POI这样的工具，都将在数字化转型的道路上扮演关键角色。希望本文的内容能帮助读者在自己的项目中更好地利用这些强大的自动化文档处理工具，以便构建更智能、更高效的系统。
