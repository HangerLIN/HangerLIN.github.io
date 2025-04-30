# （五）订阅解耦：借助Canal实现数据变更

### 1. 引言

在我们之前的讨论中，我们深入探索了几个关键的数据库问题，其中包括解决MySQL的深度分页问题以及同步MySQL数据到Elasticsearch的策略。这些讨论不仅揭示了直接同步方法的限制，也突出了异步解决方案的多样性和有效性，为处理大量数据提供了可行性和灵活性。

在上一集中，我们详细讨论了如何利用异步机制，例如消息队列，来优化数据同步过程。异步解决方案通过解耦数据生产者和消费者，降低了系统间的直接依赖性，从而增强了系统的稳定性和可扩展性。这种方法不仅提高了数据处理速度，还显著提升了整体系统效率，因为它具备非阻塞的特性。

然而，引入消息队列也带来了一个新问题：代码的**可维护性**可能会下降。随着业务量的增加以及需求的变化，我们可能需要在修改成绩表前后引入一些前置或后置操作。此外，我们可能会引入相关的教学管理员、教务员以及教师，他们都可能对成绩表拥有修改权限。如果维持当前的代码架构，每次修改成绩表时，我们都需要手动复制现有代码以发送信息，这显然不是一个明智的选择。

为了解决当前的问题，笔者在技术选型时考虑了采用数据订阅的模式。

接下来，我们将引入数据订阅作为另一种高效的数据同步策略。通过使用像Canal这样的数据订阅工具，可以实时捕获和响应数据库更改，并将这些更改无缝同步到Elasticsearch，以实现快速搜索和查询。

在本集中，我们将详细探讨如何通过数据订阅优化数据同步过程、实现方式以及这种方法如何有效提高数据一致性和系统响应速度。



### 2. 数据订阅的概念与工作原理

#### 2.1 定义
数据订阅是一种高效的数据同步策略，允许系统以事件驱动的方式实时响应数据库的变更。这种方法通过特定的中间件来实现，这些中间件监控数据库的事务日志，捕捉数据变更事件，并将这些变更推送给订阅者。这不仅确保了数据的实时更新，还降低了数据库直接查询的性能损耗。

数据订阅中间件充当**生产者和消费者**之间的桥梁，通过发布/订阅模式，使得数据的生产者不需要知道谁是数据的消费者，而数据消费者可以灵活地订阅他们感兴趣的数据事件。

先简单的介绍一下这款阿里开源的中间件。

#### 2.2 Canal 基础

**Canal** 是实现数据订阅中非常流行的一个开源工具，它模拟了 MySQL 的数据库复制功能。Canal 的主要技术原理基于 MySQL 的 binlog（二进制日志），它是 MySQL 数据库中记录所有修改数据（如INSERT, UPDATE, DELETE）的操作日志。以下是 Canal 实现数据订阅的主要步骤：

1. **连接到 MySQL 数据库**：Canal 模拟一个 MySQL slave 的身份连接到 MySQL master。
2. **读取 binlog**：Canal 读取 MySQL 数据库的 binlog，这需要确保 MySQL 的 binlog 日志功能被启用。
3. **解析 binlog**：Canal 解析 binlog 中记录的每一个数据变更事件。这一步涉及解析 binlog 中的事件类型、数据表、行数据变更详情等。
4. **数据转换**：将解析出的数据变更转换为统一的格式，方便后续处理。
5. **事件推送**：通过定义的通信协议（如 TCP, Kafka 等），将数据变更事件推送给数据订阅者。

这种基于 binlog 的订阅方式确保了数据的变更能够被实时捕获，并且准确无误地被应用到下游的消费者，如 Elasticsearch、缓存（Redis）等系统，从此实现了数据库和缓存的数据强一致性。

除此以外，Canal 还允许用户指定关注特定的数据库表**结构**的变更。但这并不在我们这章的讨论重点之内。



### 3. Canal的配置与实现

#### 3.1 部署步骤

Canal的部署涉及几个关键步骤，从安装到配置，再到启动服务。以下是详细的部署指南：

1. **下载 Canal**：
   
   - 首先，访问 Canal 的官方 [GitHub 页面](https://github.com/alibaba/canal) 或其官网下载最新的稳定版本。选择与你的系统兼容的包进行下载。
   
2. **解压 Canal**：
   - 下载完成后，将压缩文件解压到你选择的目录。例如，使用以下命令解压到 `/opt/canal/`：
     ```bash
     tar -zxvf canal.deployer-x.x.x.tar.gz -C /opt/canal/
     ```

3. **配置 MySQL**：
   - 在开始配置 Canal 之前，你需要确保 MySQL 的 binlog 功能已经开启，并且 binlog 的格式为 `ROW`，因为 Canal 依赖于解析 row-based 的 binlog。
   - 修改 MySQL 的配置文件 `my.cnf`（通常位于 `/etc/mysql/my.cnf`），确保以下配置生效：
     ```ini
     [mysqld]
     log-bin=mysql-bin # 开启binlog
     binlog-format=ROW # 设置binlog格式为ROW
     server-id=1 # 设置MySQL的server-id，确保每个MySQL实例的ID唯一
     ```
   - 重启 MySQL 服务以应用这些更改。

4. **配置 Canal**：
   - 修改 `conf` 目录下的 `canal.properties` 文件以配置 Canal 的全局参数，如端口、Zookeeper 连接等。
   - 修改 `conf/example/instance.properties` 文件以配置特定的 Canal 实例，这包括 MySQL 数据源的地址、用户名、密码，以及你想要订阅的数据库或表。例如：
     ```properties
     canal.instance.master.address=127.0.0.1:3306
     canal.instance.dbUsername=canal
     canal.instance.dbPassword=canal
     canal.instance.connectionCharset=UTF-8
     canal.instance.tsdb.enable=true
     canal.instance.gtidon=false
     ```

5. **启动 Canal 服务**：
   - 进入 Canal 的 bin 目录，使用以下命令启动 Canal 服务：
     ```bash
     sh startup.sh
     ```
   - 检查日志文件以确保没有错误，并验证服务是否正常运行。

6. **监控和日志**：
   
   - Canal 提供了简单的日志和监控功能，你可以通过查看 `logs` 目录下的日志文件来监控 Canal 的运行状况。
   - 可以通过访问 Canal Admin（如果已启用）来管理和监控 Canal 的多个实例。



#### 3.2 配置使用

在使用 Canal 来处理数据库变更时，有两种主要的监听方式，一种是针对数据内容的变更，另一种是针对数据库**结构（DDL）**的变更。笔者本章重点讨论前者的实现。

##### 1. 监听数据内容变更（DML）

如果只需要处理对数据库中数据的变更（如插入、更新、删除），使用 `@CanalTable` 注解标注监听的表，实现 `EntryHandler` 接口，并且泛型参数传入上面监听表对应的实体类通常就足够了。举个例子，我们使用监听一张product表：

```java
import top.javatool.canal.client.annotation.CanalTable;
import top.javatool.canal.client.handler.EntryHandler;

@CanalTable("product")
public class ProductEntryHandler implements EntryHandler<Product> {

    @Override
    public void insert(Product data) {
        // 处理插入操作
    }

    @Override
    public void update(Product before, Product after) {
        // 处理更新操作
    }

    @Override
    public void delete(Product data) {
        // 处理删除操作
    }
}
```

只需要确保数据模型（如 `Product` 类）与数据库表结构相匹配，Canal 客户端会自动处理数据的解析和传递给相应的处理方法。可以在各个操作内部自定义后置操作，选择和redis或者是es中间件进行交互。

我们可以写出下述的代码，同时通过 Canal 整合 Elasticsearch 和 Redis 之间完成数据的同步操作：

```java
@CanalTable("product")
public class ProductEntryHandler implements EntryHandler<Product> {
    private RestHighLevelClient elasticsearchClient;

    public ProductEntryHandler(RestHighLevelClient client) {
        this.elasticsearchClient = client;
    }

    @Override
    public void insert(Product product) {
        // 更新 Elasticsearch 索引
        IndexRequest request = new IndexRequest("products").id(product.getId().toString()).source(product.toJson(), XContentType.JSON);
        elasticsearchClient.index(request, RequestOptions.DEFAULT);
    }

    @Override
    public void update(Product before, Product after) {
        // 更新 Elasticsearch 索引
        IndexRequest request = new IndexRequest("products").id(after.getId().toString()).source(after.toJson(), XContentType.JSON);
        elasticsearchClient.index(request, RequestOptions.DEFAULT);
    }

    @Override
    public void delete(Product product) {
        // 删除 Elasticsearch 索引
        DeleteRequest request = new DeleteRequest("products", product.getId().toString());
        elasticsearchClient.delete(request, RequestOptions.DEFAULT);
    }
}

@CanalTable("orders")
public class OrderEntryHandler implements EntryHandler<Order> {
    private RedisTemplate<String, String> redisTemplate;

    public OrderEntryHandler(RedisTemplate<String, String> redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public void update(Order before, Order after) {
        if ("paid".equals(after.getStatus()) && !"paid".equals(before.getStatus())) {
            // 使用 Redis 发布订单已支付的事件
            redisTemplate.convertAndSend("order-events", "Order Paid: " + after.getId());
            // 通知物流开始处理
        }
    }
}
```



##### 2. 监听数据库结构变更（DDL）

对于监听数据库结构的变更，如表结构（DDL）变更，通常需要处理原始的 `CanalEntry` 数据，因为这些信息包含了关于数据库结构变更的详细信息，如变更的 SQL 语句。需要使用 protobuf 库（引入新的依赖）来解析从 Canal 服务器发送的原始消息。

**示例代码**：

```java
import com.alibaba.otter.canal.protocol.CanalEntry;
import com.alibaba.otter.canal.client.CanalConnector;
import com.alibaba.otter.canal.protocol.Message;

public class DDLHandler {
    public void handleEntry(CanalEntry.Entry entry) {
        if (entry.getEntryType() == CanalEntry.EntryType.ROWDATA) {
            CanalEntry.RowChange rowChange = null;
            try {
                rowChange = CanalEntry.RowChange.parseFrom(entry.getStoreValue());
            } catch (Exception e) {
                System.err.println("ERROR: Error in parsing entry data.");
                return;
            }
            if (rowChange.getIsDdl()) {
                System.out.println("DDL Statement: " + rowChange.getSql());
            }
        }
    }
}
```

在这个例子中，`RowChange.parseFrom(entry.getStoreValue())` 调用是关键，它将原始的 Protobuf 消息转换为 `RowChange` 对象，可以从中读取到 DDL 语句和其他相关信息。本章不再对此赘述。



### 5. 项目实战案例

在此次改进中，笔者计划使用Canal来实现MySQL数据库与Elasticsearch的同步，从而实时准确地处理和同步成绩信息。

然而，直接对`product`表格的变动进行监听存在一个问题——这是一个同步操作。同步操作意味着每次数据库的插入、更新或删除操作都需要等待Elasticsearch的操作完成才能继续。这种依赖关系可能显著增加数据库操作的响应时间，特别是在Elasticsearch服务响应慢或不可用时。由于每个数据变更都需要立即反映在Elasticsearch中，这种同步操作可能导致系统难以应对高并发情况，限制了系统的扩展性。

为了优化这种“同步信息发送”的问题，笔者采用了在Canal内部使用RabbitMQ异步发送消息的方式来同步数据，从而实现数据库操作和Elasticsearch索引更新的解耦。在上一章中，我们已经详细介绍了如何使用消息队列来同步数据。只需要将消息队列发送的API整合到Canal内部的方法中即可。

通过这种方式，数据库操作可以快速完成并立即响应用户，而数据同步任务则被推送到消息队列中异步处理。此外，即使Elasticsearch服务暂时不可用，数据也不会丢失，因为它们被安全地存储在队列中，待服务恢复后重新处理。这种方式提高了系统的可靠性和容错能力。

现在，笔者将回到教育平台，根据学生成绩同步到Elasticsearch的业务需求，进行架构升级改造。妈妈

#### 5.0 引入相关依赖配置

在maven中引入相关maven的依赖。

```xml
        <!--canal-->
        <dependency>
            <groupId>top.javatool</groupId>
            <artifactId>canal-spring-boot-starter</artifactId>
            <version>1.2.1-RELEASE</version>
        </dependency>
```

在application.yml文件中配置canal的server地址和端口号，以及目标地址（要捕获和同步变更的实际数据库实例或数据源的名称），这里笔者的测试地址连接的是我本地的数据库`example`

```yml
canal:
  server: 139.159.132.31:11111
  destination: example
```



#### 5.1 **Canal 监听 MySQL 变动**：

在此场景中，Canal 被配置为监听 `score_information` 表。当表中的数据发生变化时，Canal 捕获这些变化并生成数据事件。

![image-20240501194955089](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimagesimage-20240501194955089.png)

```java
@CanalTable("score_information")
@Component
public class ScoreHandler implements EntryHandler<ScoreInformation> {
    @Resource
    private MessageSender messageSender;

    @Override
    public void insert(ScoreInformation document) {
        JSONObject jsonObject = JSONObject.parseObject(JSON.toJSONString(document));
        messageSender.sendScoreInformation("insert", jsonObject);
    }
}
```



#### 5.2 **处理数据并发送至消息队列**：

`scoreHandler` 类接收来自 Canal 的数据事件。

在这个部分，方法首先解析接收到的消息内容为JSON对象。然后从JSON对象中提取出操作类型（`type`，如"insert", "update", "delete"）和具体的内容（`content`）。之后，它调用`scoreElasticSearchService.syncScore`方法来处理具体的同步逻辑。

若处理成功，它会发送一个acknowledgement（确认消息已处理）给RabbitMQ服务器。如果在处理过程中出现异常，则发送一个negative acknowledgement（否认消息已处理），告诉RabbitMQ不要删除消息，可能因配置不重新入队。

```java
public boolean sendScoreInformation(String type, JSONObject coursesClassInformation) {
    try {
        JSONObject jsonObject = new JSONObject();
        jsonObject.put("type", type);
        jsonObject.put("message", coursesClassInformation);
        this.rabbitTemplate.convertAndSend(queue8, jsonObject.toJSONString());
        log.info("成功发送导出文件处理消息 ");
        return true;
    } catch (AmqpException e) {
        log.error("发送导出文件处理消息失败: " + e.getMessage());
        return false;
    }
}
```



#### **5.3 消费消息并同步到 Elasticsearch**

`MessageReceiver` 类监听 RabbitMQ 队列，消费消息，并根据消息类型（如插入、更新、删除）通过 `ScoreElasticSearchService` 同步到 Elasticsearch。

```java
@RabbitListener(queuesToDeclare = @Queue("${spring.rabbitmq.queue8}"))
public void processCanal(String messageContent, Channel channel, Message msg) {
    try {
        JSONObject message = JSON.parseObject(messageContent);
        String type = message.getString("type");
        JSONObject content = message.getJSONObject("message");

        scoreElasticSearchService.syncScore(type, content);
        channel.basicAck(msg.getMessageProperties().getDeliveryTag(), false);
    } catch (Exception e) {
        log.error("处理canal消息时出现异常: ", e);
        channel.basicNack(msg.getMessageProperties().getDeliveryTag(), false, false);
    }
}
```



#### 5.4 数据同步到Elasticsearch

```java
public void syncScore(String type, JSONObject jsonObject) throws IOException {
    ScoreInformationPO scoreInformationPO = jsonObject.toJavaObject(ScoreInformationPO.class);

    if ("insert".equals(type) || "update".equals(type)) {
        IndexRequest request = new IndexRequest("score_information");
        request.id(String.valueOf(scoreInformationPO.getId()));
        String jsonEntity = JSONObject.toJSONString(scoreInformationPO);
        request.source(jsonEntity, XContentType.JSON);

        restHighLevelClient.index(request, RequestOptions.DEFAULT);
    } else if ("delete".equals(type)) {
        DeleteRequest request = new DeleteRequest("score_information", String.valueOf(scoreInformationPO.getId()));
        restHighLevelClient.delete(request, RequestOptions.DEFAULT);
    }
}
```

这个方法根据消息类型来处理数据同步到Elasticsearch的逻辑。

首先，它将JSON对象转换成`ScoreInformationPO`类的实例。如果操作类型是"insert"或"update"，则创建一个`IndexRequest`，设置要索引的文档ID，并将`ScoreInformationPO`实例序列化为JSON字符串后，作为文档源发送到Elasticsearch。

如果操作类型是"delete"，则创建一个`DeleteRequest`，并通过Elasticsearch的客户端发送请求以删除相应的文档。

通过这种方式，配置同步已经完全写完！Canal 与消息队列和 Elasticsearch 的协作，确保了成绩信息一旦在数据库中更新，便能迅速反映在用户的界面上，极大地提高了数据的实时性。



### 6. 结语

在本文中，我们探讨了如何使用Canal来实现MySQL数据库与Elasticsearch之间的同步，以确保成绩信息实时准确地处理和更新。我们发现，直接监听`product`表的变动是一种同步操作，会导致数据库操作必须等待Elasticsearch的完成，这可能导致响应时间增加，尤其在高并发或Elasticsearch服务不可用时表现得尤为明显。

为了解决这个问题，我们选择了在Canal内部使用RabbitMQ异步发送消息的方式来同步数据，从而实现数据库操作和Elasticsearch索引更新的解耦。通过将数据同步任务推送到消息队列中异步处理，数据库操作可以更快地响应用户需求，并且即使Elasticsearch暂时不可用，数据也不会丢失。这样的设计提高了系统的可靠性和容错能力。

为实现这一策略，我们详细讨论了如何在maven中引入相关依赖配置、使用Canal监听MySQL的变动、处理数据并发送至消息队列、消费消息并同步到Elasticsearch，以及最终将数据同步到Elasticsearch。

通过引入这些技术，学生成绩同步到Elasticsearch的业务实践得到了有效的架构升级改造，为教育平台带来了更加高效和稳定的数据处理方案。



### 7.三篇文章的总结与展望

在本系列的三篇文章中，笔者探讨了如何构建一个高性能的在线教育平台。通过深入研究分页优化、数据同步以及高级数据订阅策略，揭示了如何通过技术手段来提升成绩查询中的系统性能、稳定性和用户满意度。

#### 第一集：解决深度分页问题

在第一集中，我们着眼于深度分页问题，这在处理大量学生成绩数据时尤为突出。我们通过深入分析SQL语句的执行情况并且使用子查询、分析业务规模和数据量实施分库分表、索引优化以及使用全局唯一标识符等策略来优化数据库性能。通过这一集的探索，我们不仅解决了深度分页问题，还为后续的同步策略打下了基础。

#### 第二集：同步策略—直接同步与异步解决方案

第二集中，我们深入探讨了数据一致性的问题，尤其关注了MySQL与Elasticsearch之间的双写一致性。我们对比了直接同步双写和异步双写（消息队列）两种策略的优缺点。直接同步具有简单、快速的特点，适合小规模的数据同步，而异步双写则通过解耦合系统和提高响应速度来增强系统的可扩展性。

#### 第三集：先进的同步策略—数据订阅

在第三集中，我们介绍了数据订阅作为一种高效的数据同步策略。通过Canal等工具，我们能够实时捕获和响应数据库的更改，并无缝同步到Elasticsearch。我们探讨了数据订阅的优势和挑战，以及如何通过实际案例在在线教育平台中实施这一策略。通过数据订阅，我们实现了业务侵入性低、实时性好的数据同步方案。

#### 总结与展望

在本系列中，我们从解决深度分页问题到探讨同步策略，再到引入数据订阅的方法，系统地提升了在线教育平台的性能和可靠性。在下一章中，我们将继续探讨异步后台并行双系统数据同步策略，并进一步研究高性能大规模数据查询架构，包括如何从深度分页优化到双写异步同步，为读者提供更全面的技术指导。

