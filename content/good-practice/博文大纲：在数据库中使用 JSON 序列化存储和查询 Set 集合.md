### 为什么写了这篇文章？

最近有些朋友向我询问，如何在单一源数据库中实现不同用户对不同数据的权限控制，以及如何设计这样的数据库表。同时，在日常开发中，我也遇到了一个挑战：如何在数据库中存放集合字段，并且实现代码的低侵入性。这些问题促使我深入思考和实践，最终形成了一些有效的解决方案。

为了帮助更多的开发者解决类似问题，我决定写一篇博文，分享我如何使用 `JSON_CONTAINS` 函数和 `StringSetTypeHandler` 来管理用户权限，并高效地存储和查询集合类型的数据。



### 引言

在当代软件开发领域，类型处理器（Type Handler）是一个关键组件，它承担着桥接应用程序数据和数据库数据之间转换的重要任务。特别是在使用对象关系映射（ORM）框架如 MyBatis 和 Hibernate 时，类型处理器的重要性更是不言而喻。它们使得复杂数据类型的存储和检索变得简单和直接，通过提供一种机制来定义和执行数据类型之间的转换，从而使得开发者能够将更多的精力集中于业务逻辑的实现上，而非数据的基础处理过程。

`Set` 集合，作为 Java 中常用的数据结构之一，在业务逻辑处理中发挥着至关重要的角色。无论是处理无序且不允许重复的数据集，还是在进行批量数据处理时确保数据的唯一性，`Set` 都提供了极为便利的解决方案。然而，当这些集合需要被持久化到数据库中时，就面临着不小的挑战。由于传统的关系型数据库并不直接支持 `Set` 类型的数据结构，这就要求开发者需要在应用层做额外的处理来实现这一数据类型的存储和查询，通常这一过程涉及到数据的序列化和反序列化。

在实际的应用开发过程中，如何有效地存储和查询这些集合数据，同时保证数据的完整性和性能，是每个 Java 开发者都需要面对的问题。合理使用类型处理器，特别是在处理如 `Set` 这样的集合类型时，成为了设计高效、可扩展和可维护应用系统的关键。

接下来的章节中，笔者将深入探讨 `StringSetTypeHandler` 的实现细节，它是如何帮助我们在数据库中存储和查询基于 JSON 格式的 `Set` 集合，以及这种方法在实际开发中的应用和优势。我们也将通过具体的代码示例，展示在业务实体中如何利用这一类型处理器来简化数据处理流程，确保数据的一致性和系统的响应速度。



### 你将会学到

1. **权限管理的实现**：我将详细介绍如何使用 `JSON_CONTAINS` 函数和 JSON 数据字段来实现复杂的权限管理逻辑。这包括如何设计数据库表以存储和处理权限相关的信息，以及如何通过动态查询确保每个用户只能访问他们被授权看到的数据。
2. **数据存储策略**：你将学到如何利用 JSON 类型字段来存储灵活的数据结构，如用户组、权限列表等，以及如何使用自定义的类型处理器如 `StringSetTypeHandler` 来简化这些数据的处理和查询。
3. **低侵入性代码实践**：文章将解释如何通过封装数据库类型转换的代理类的代码设计来保持系统的低侵入性，使得新功能的加入不会破坏或过度依赖现有的系统架构。
5. **实际案例分析**：通过具体的示例和案例分析，你将看到这些技术和方法如何在实际的业务场景中得到应用，以及它们如何帮助解决实际问题。

希望通过本篇博文，你能获得实际的操作技巧和理论知识，以更自信地处理你的软件项目中的数据管理和权限控制问题。欢迎大家在博文发布后积极交流和提问，共同提升我们的技术水平。



### 第一部分：了解 `SetTypeHandler` 和 `StringSetTypeHandler`

#### 设计 `SetTypeHandler` 的背景和目的
在 MyBatis 和 MyBatis Plus 框架中，虽然 `BaseTypeHandler` 提供了基本的类型处理功能，但它并没有直接支持复杂的数据结构，如集合类型的处理。

为了解决这一问题，我设计了 `SetTypeHandler<T>`，这是一个抽象类，扩展了 MyBatis 的 `BaseTypeHandler`。它的主要目的是提供一个通用框架，以支持任意类型 `T` 的集合（`Set<T>`）在数据库中的序列化和反序列化。

通过这种设计，`SetTypeHandler<T>` 可以被特化来处理特定类型的集合，例如字符串集合 `Set<String>`。



#### `SetTypeHandler<T>` 的关键实现
`SetTypeHandler<T>` 实现了几个核心功能，这些功能是处理集合类型数据在数据库操作中的关键：

1. **序列化集合数据**：
   在 `setNonNullParameter` 方法中，我们将非空的 `Set<T>` 集合转换成 JSON 字符串。这一转换利用了 `JSONObject.toJSONString(ts)` 方法，该方法属于阿里巴巴的 fastjson 库，能够高效地处理 Java 对象到 JSON 字符串的转换。这样，即使是复杂的集合数据也可以作为一个简单的字符串存储在数据库的单个字段中。

   ```java
   @Override
   public void setNonNullParameter(PreparedStatement preparedStatement, int i, Set<T> ts, JdbcType jdbcType) throws SQLException {
       String content = CollectionUtil.isEmpty(ts) ? null : JSONObject.toJSONString(ts);
       preparedStatement.setString(i, content);
   }
   ```

2. **反序列化集合数据**：
   `getNullableResult` 方法从数据库的结果集中取出 JSON 字符串，并将其转换回 Java 中的 `Set<T>` 集合。这一过程使用了 Jackson 库的 `new ObjectMapper().readValue(content, specificType())` 方法进行反序列化。这需要实现一个抽象方法 `specificType()` 来确定具体的集合元素类型。

   ```java
   @Override
   public Set<T> getNullableResult(ResultSet resultSet, String s) throws SQLException {
       try {
           return this.getListByJsonArrayString(resultSet.getString(s));
       } catch (JsonProcessingException e) {
           throw new BusinessException(e);
       }
   }
   ```

3. **类型引用的抽象定义**：
   `specificType` 是一个抽象方法，要求所有继承自 `SetTypeHandler<T>` 的处理器明确指定如何解析集合中的元素类型，这是实现类型安全反序列化的关键。



#### 设计 `StringSetTypeHandler`

基于 `SetTypeHandler` 的框架，`StringSetTypeHandler` 专门处理 `Set<String>` 类型的数据。这个处理器不仅继承了所有的通用集合处理逻辑，还针对字符串类型的特点进行了优化。

最核心的方法，也是被重写的那个方法是 `specificType()`，它定义了如何确定集合中元素的类型。这个方法对于确保数据在序列化和反序列化过程中的类型安全至关重要。

```java
@Override
public TypeReference<Set<String>> specificType() {
    return new TypeReference<Set<String>>() {};
}
```
通过返回一个 `TypeReference<Set<String>>` 的实例，`StringSetTypeHandler` 具体指明了集合中的元素类型为 `String`。这一实现利用了 Jackson 库的功能，使得 JSON 数据的反序列化可以准确地转换为 `Set<String>` 类型，保证了类型的准确性和操作的安全性。

#### 注解配置
在 `StringSetTypeHandler` 类级别上，我使用了 MyBatis 的两个重要注解来配置该处理器的关键属性：

1. **@MappedTypes**
   `@MappedTypes` 注解用于指定这个类型处理器可以应用于哪些 Java 类型。在这里，虽然处理的是 `Set<String>` 类型，注解被设置为 `Collection.class`，这表明该处理器理论上可以支持所有 `Collection` 接口的实现类。这种做法提供了更广的适用性，但在实际使用中，通常会根据需要具体限定处理的集合类型。

   ```java
   @MappedTypes(Collection.class)
   ```

2. **@MappedJdbcTypes**
   `@MappedJdbcTypes` 注解定义了该类型处理器适用于哪些 JDBC 类型。在这个例子中，使用了 `JdbcType.LONGVARCHAR`，这是因为 JSON 字符串可能会非常长，使用 `LONGVARCHAR` 类型可以确保数据库能够存储足够长的字符串。

   ```java
   @MappedJdbcTypes(JdbcType.LONGVARCHAR)
   ```



### 这些类的基础关系如下

![image-20240517160031963](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240517160031963.png)



### 第二部分：序列化和反序列化过程及其在 POJO 类中的应用

![image-20240517150132093](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240517150132093.png)

在复杂的数据持久化场景中，将集合如 `Set<String>` 存储在关系型数据库中通常涉及到将这些集合序列化为 JSON 格式的字符串。这一部分将详细讨论在 MyBatis 环境下，如何通过 `SetTypeHandler` 实现 `Set` 对象与 JSON 字符串之间的序列化与反序列化，以及如何在 Java 持久对象（POJO）中配置和使用这一处理器。

#### 序列化过程：`setNonNullParameter` 方法
`setNonNullParameter` 方法在 `SetTypeHandler` 中定义，其职责是将传入的 `Set` 集合转换为 JSON 字符串，以便可以将这些字符串存储在数据库中。该方法接收四个参数：一个 `PreparedStatement` 对象、参数在语句中的索引、非空的 `Set` 对象，以及 `JdbcType`，后者通常指定为 `VARCHAR` 或 `LONGVARCHAR`，具体取决于预期的数据长度。

在 `setNonNullParameter` 中，我们使用了 fastjson 库的 `JSONObject.toJSONString` 方法，该方法能够将 `Set` 集合转换成一个 JSON 格式的字符串。此字符串随后被设置到 `PreparedStatement` 中的对应位置，准备好存储到数据库中，这涉及底层的jdbc操作，我们不展开赘述。

```java
@Override
public void setNonNullParameter(PreparedStatement ps, int i, Set<T> parameter, JdbcType jdbcType) throws SQLException {
    String content = CollectionUtil.isEmpty(parameter) ? null : JSONObject.toJSONString(parameter);
    ps.setString(i, content);
}
```



#### 反序列化过程：`getNullableResult` 方法

反序列化过程在 `SetTypeHandler` 中通过 `getNullableResult` 方法实现，该方法负责将从数据库中检索到的 JSON 字符串转换回 Java 中的 `Set` 类型。这一转换使用了 Jackson 库的 `ObjectMapper.readValue` 方法，根据 `StringSetTypeHandler` 中定义的 `specificType` 方法，准确地将 JSON 字符串解析回 `Set<String>` 对象。

在 `getNullableResult` 中，首先检查从数据库中读取的字符串是否为空，然后根据 `specificType` 方法提供的类型引用进行反序列化。这一操作确保了类型的安全性，并防止了类型错误或数据不匹配的问题。

```java
@Override
public Set<T> getNullableResult(ResultSet rs, String columnName) throws SQLException {
    String content = rs.getString(columnName);
    return StringUtils.isEmpty(content) ? new HashSet<>() : new ObjectMapper().readValue(content, specificType());
}
```



#### 实战：在 POJO 类中的应用

假设我们当前需要处理的数据库的字段如下：

```sql
-- auto-generated definition
create table approval_record
(
    id                 bigint auto_increment comment '主键id'
        primary key,
    approval_type_id   bigint       null comment '审批类型id',
    initiator_username varchar(255) null comment '发起人username',
    created_at         datetime     null comment '审批发起时间',
    update_at          datetime     null comment '最后一次更新时间',
    current_step_id    bigint       null comment '当前步骤id',
    status             varchar(20)  null comment '审批状态：waiting-正在审批，success-成功，failed-失败',
    watch_username_set json         null comment '用户查看集合',
    document_id        varchar(50)  null comment '表单 id'
)
    comment '审批记录';


```

该对象需要存储到数据库中并能从数据库中反序列化成Java对象。

那么关键点就是这个json格式的`watch_username_set`了。

在第三部分，我们将详细解释如何使用上面的知识来完成类型转化。



### 第三部分：在 MyBatis 查询中的应用

MyBatis 作为一个流行的持久层框架，提供了强大的支持来处理复杂的查询和数据转换任务。`StringSetTypeHandler` 的应用展示了如何在 MyBatis 配置中优雅地处理 JSON 数据类型，以及如何利用 SQL 函数增强查询的表达力。

#### 注册和使用类型处理器

我们主要关心JSON格式的`watch_username_set`。我们可以在Java的POJO类如下配置该字段：

```java
@ApiModelProperty("观察者用户名集合")
@TableField(typeHandler = StringSetTypeHandler.class)
private Set<String> watchUsernameSet;
```

在字段上使用 `@TableField` 注解来指定使用的类型处理器。这一注解不仅标明了如何在数据库操作时处理该字段，还指示了 MyBatis 应如何在读写数据时调用相应的类型处理器，告诉 MyBatis 使用 `StringSetTypeHandler` 来处理该字段的序列化和反序列化。



#### 使用 `JSON_CONTAINS` 函数进行条件查询

##### 什么是`JSON_CONTAINS`函数？

`JSON_CONTAINS` 是一个在 SQL 中用于处理 JSON 数据的函数，广泛应用于支持 JSON 数据类型的数据库系统，如 MySQL。这个函数的主要作用是检查一个 JSON 文档（可以是数组或对象）中是否包含一个特定的值或者另一个 JSON 文档。

**使用 `JSON_CONTAINS` 函数进行条件查询的优势在于直接在数据库层面对 JSON 数据进行查询，无需将数据先加载到应用程序中再进行处理。**

##### 语法结构

在 MySQL 中，`JSON_CONTAINS` 的基本语法如下：

```sql
JSON_CONTAINS(target, candidate[, path])
```

- **target**: JSON 字符串或列，代表要搜索的 JSON 文档。
- **candidate**: 要在 target 中查找的 JSON 文档或值。
- **path** (可选): JSON 路径表达式，指定在 target 中搜索 candidate 的路径。如果不指定路径，默认在整个 target 中搜索。

##### 参数解释

1. **target**:
   - 这是包含 JSON 数据的字段或字符串。它是你想要查询的 JSON 文档的源。

2. **candidate**:
   - 这是你想在 target 中查找的数据，也必须是 JSON 格式。这可以是一个具体的值（如 JSON 字符串、数字等），也可以是一个更复杂的 JSON 对象或数组。

3. **path**:
   - 这是一个可选参数，用来指定在 JSON 文档中查找 candidate 的路径。使用 JSON 路径表达式可以精确指定候选数据应存在的位置，从而提高查询的精确性和效率。

##### 示例

假设有一个名为 `users` 的表，其中的 `profile` 列包含如下 JSON 数据：

```json
{
  "name": "John",
  "age": 30,
  "skills": ["SQL", "Programming", "Design"]
}
```

如果你想查询所有包含技能 "SQL" 的用户记录，可以使用以下 SQL 命令：

```sql
SELECT * FROM users
WHERE JSON_CONTAINS(profile, '"SQL"', '$.skills');
```

在这个例子中，`JSON_CONTAINS` 函数检查 `profile` 列中的 JSON 文档的 `skills` 键是否包含 "SQL"。

##### 应用场景

`JSON_CONTAINS` 函数特别适用于以下情况：

- 快速筛选具有特定属性或值的记录，尤其是当这些数据以 JSON 格式存储时。
- 在不需要将整个 JSON 文档解析到应用层的情况下，直接在数据库层面进行复杂的数据结构查询，提高数据处理效率。
- 实现更复杂的查询条件，例如，当 JSON 字段存储了数组或嵌套对象时，使用该函数可以极大地简化查询逻辑。



#### 在Mybatis中使用JSON_CONTAIN 与 类型转换器

mybatis plus 引入了强大的**类型转换器**来进行数据的类型转换，这个是原生的MySQL不支持的。

这里，`JSON_CONTAINS` 函数接收两个参数：

```xml
JSON_CONTAINS(watch_username_set, #{entity.watchUsernameSet, typeHandler=com.scnujxjy.backendpoint.handler.type_handler.set.StringSetTypeHandler})
```



代码简化如下：`JSON_CONTAINS(target, candidate)` ，**用于检查目标 JSON （target）中是否包含候选 JSON（candidate）。**

1. **第一个参数 - JSON 字段：**
    - `watch_username_set`：这是存储在数据库中的字段名，它包含 JSON 格式的数据。通常，这个字段会存储如用户名集合这样的数组或是更复杂的 JSON 对象。

2. **第二个参数 - 要检查的值：**
    - `#{entity.watchUsernameSet, typeHandler=com.scnujxjy.backendpoint.handler.type_handler.set.StringSetTypeHandler}`：这个表达式的作用是从应用程序传递的 `entity` 对象中获取 `watchUsernameSet` 属性的值**（前半部分）**，并且使用 `StringSetTypeHandler` 类型处理器来处理这个值**（后半部分）**。
    - 如果提供了非空的 `watchUsernameSet`，查询将利用 `JSON_CONTAINS` 函数来筛选那些 `watch_username_set` JSON 字段包含指定用户名集合的记录。检查目标 JSON （target）中是否包含候选 JSON（candidate）。

    - `StringSetTypeHandler` 负责将 Java 中的 `Set<String>` 类型转换成 JSON 字符串格式，**这样才能被 `JSON_CONTAINS` 函数正确处理。**



***那么传入的类型转换器，扮演什么样的角色呢？***

- `StringSetTypeHandler` 将 `Set<String>` 转换为一个 JSON 格式的数组字符串。例如，如果 `Set<String>` 包含 `["user1", "user2"]`，类型处理器将其转换为 JSON 字符串 `["user1", "user2"]`。
- 转换成JSON字符串之后，`JSON_CONTAINS(watch_username_set, '["user1", "user2"]')` 会检查 `watch_username_set` 字段中的 JSON 数据是否包含所有 `["user1", "user2"]` 中列出的元素。

通过指定 `typeHandler` 属性，MyBatis 知道在执行这个查询前应该如何处理 `entity.watchUsernameSet` 参数。`JSON_CONTAINS` 函数被用来检查数据库中的 `watch_username_set` 字段（这是一个存储 JSON 数据的字段）是否包含指定的用户名集合。



##### 和动态SQL结合

在笔者本人的MyBatis 的映射文件中，编写了动态SQL 来使用 `JSON_CONTAINS` 函数，结合`StringSetTypeHandler`，并且传入一个`entity.watchUsernameSet`对象，

```xml
<select id="selectApprovalRecordPage" resultMap="BaseResultMap">
    SELECT *
    FROM approval_record
    WHERE TRUE
    <if test="entity.approvalTypeId != null">
        AND approval_type_id = #{entity.approvalTypeId}
    </if>
    <if test="entity.initiatorUsername != null">
        AND initiator_username = #{entity.initiatorUsername}
    </if>
    <if test="entity.status != null">
        AND status =#{entity.status}
    </if>
    <if test="entity.watchUsernameSet != null and entity.watchUsernameSet.size() > 0">
        AND JSON_CONTAINS(watch_username_set, #{entity.watchUsernameSet,typeHandler=com.scnujxjy.backendpoint.handler.type_handler.set.StringSetTypeHandler})
    </if>
    <if test="page.pageStart != null and page.pageEnd != null">
        LIMIT #{page.pageStart}, #{page.pageEnd}
    </if>
</select>
```



***对结果的影响是？***

*当记录被“选中”时*：

- **意味着**：记录满足查询条件。在此上下文中，如果`JSON_CONTAINS`函数返回真（true 或 1），说明指定的JSON字段（如`watch_username_set`）包含了查询条件中指定的元素（如`entity.watchUsernameSet`中的用户名）。因此，这条记录满足查询的要求，并将被包括在最终的查询结果中。
- **结果**：这种记录会出现在查询结果集中，因为它符合用户通过查询设置的过滤条件。

*当记录被“未选中”时*：

- **意味着**：记录不满足查询条件。在这种情况下，如果`JSON_CONTAINS`函数返回假（false 或 0），说明指定的JSON字段不包含查询条件中指定的元素（如查询中提供的用户名“david”不在`watch_username_set`中）。因此，这条记录不满足查询的要求，不会被包括在最终的查询结果中。
- **结果**：这种记录不会出现在查询结果集中，因为它不符合查询中设置的过滤条件。



#### **查询的应用场景和优势**

使用 `JSON_CONTAINS` 函数检查 `watch_username_set` 字段的应用场景非常广泛，尤其适用于需要精细管理用户数据视图和访问权限的系统，笔者讲讲在笔者负责设计的OA系统中启到什么样的功能。

在 OA 系统中，不同的用户基于他们的角色或职责可能有权查看不同的审批记录。例如，教务员可能需要访问其所有学生的审批记录，而学生本人则只能看到与自己相关的记录。这种权限管理要求系统能够灵活地控制数据的可见性。

接入Service层的代码在黄色边框处：

![image-20240517160602859](https://cdn.jsdelivr.net/gh/HangerLIN/imageBeds2@main//imagesimage-20240517160602859.png)

- **权限管理**：在需要根据用户的权限动态展示数据的OA系统中，可以通过 `watch_username_set` 管理哪些权限的用户可以看到哪些符合他们OA审批数据记录。只有传入的`entity.watchUsernameSet`的角色，被包含在数据库已经存好的`watch_username_set`字符串中，才会被展示返回给前端，通过 `JSON_CONTAINS` 函数来筛选用户有权查看的审批记录。
- **数据安全性**：确保用户只能访问他们被授权查看的数据，增強了系统的安全性。

这种基于 `JSON_CONTAINS` 的查询策略不仅提升了数据库查询的效率和精确性，也为应用层提供了强大的数据处理能力，使得管理复杂的用户权限数据成为可能。



### 第四部分：问题与总结

#### 潜在问题

当使用 `StringSetTypeHandler` 进行数据转换时，如果数据格式不一致或转换错误，可能会引发数据错误，从而导致业务逻辑出现问题。因此，在存储这些数据时，我们必须确保数据格式的一致性。我们应尽量避免存储嵌套的 JSON 数据格式。然而，在开发过程中，如果必须处理嵌套的 JSON 数据，我们可以使用如 `fastjson` 库的相关方法来处理这些复杂数据结构。**这些内容将在笔者后续的文章中详细讨论。**

存储和查询 JSON 数据时，确保所有操作都遵循统一的标准和规范至关重要，以防止数据解析错误的发生。

#### 结论

`StringSetTypeHandler` 的设计和实现为 MyBatis 应用提供了强大的功能，使得开发者可以更方便地处理和查询 JSON 类型的数据。通过这种类型处理器，我们可以在保持数据操作灵活性的同时，提升数据处理的准确性和效率。

`StringSetTypeHandler` 不仅简化了开发人员处理 JSON 数据的复杂性，还为应用带来了更高的性能和更好的用户体验。它的实际应用价值在于能够在复杂的数据环境中提供稳定、可靠的解决方案，尤其适用于数据驱动的现代企业应用。

谢谢看到这里的大家，如果文章有所帮助，那就最好啦。