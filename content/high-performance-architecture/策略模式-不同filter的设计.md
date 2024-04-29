# 策略模式-不同filter的设计

+++
title = "策略模式-不同filter的设计"

date = 2024-04-28T17:43:19+08:00

draft = true

+++

```java
/**
 * 批量导出新生录取数据
 * @param admissionInformationRO
 * @return
 */
public Boolean batchExportAdmissionInformationByAllRoles(AdmissionInformationRO admissionInformationRO) {
    List<String> roleList = StpUtil.getRoleList();
    String userId = StpUtil.getLoginIdAsString();
    if (roleList.isEmpty()) {
        log.error(ResultCode.ROLE_INFO_FAIL1.getMessage());
        return false;
    } else {
        if (roleList.contains(SECOND_COLLEGE_ADMIN.getRoleName())) {
            // 二级学院管理员
            CollegeInformationPO userBelongCollege = scnuXueliTools.getUserBelongCollege();
            PageRO<AdmissionInformationRO> pageVO = new PageRO<>();
            admissionInformationRO.setCollege(userBelongCollege.getCollegeName());
            pageVO.setEntity(admissionInformationRO);
            boolean send = messageSender.sendExportMsg(pageVO, managerFilter, userId);
            if (send) {
                return true;
            }
        } else if (roleList.contains(XUELIJIAOYUBU_ADMIN.getRoleName()) ||
                roleList.contains(CAIWUBU_ADMIN.getRoleName()) ||
                roleList.contains(ADMISSION_ADMIN.getRoleName())
        ) {
            // 继续教育学院管理员
            PageRO<AdmissionInformationRO> pageVO = new PageRO<>();
            pageVO.setEntity(admissionInformationRO);
            boolean send = messageSender.sendExportMsg(pageVO, managerFilter, userId);
            if (send) {
                return true;
            }
        }
        else if (roleList.contains(TEACHING_POINT_ADMIN.getRoleName())) {
            // 继续教育学院管理员
            PageRO<AdmissionInformationRO> pageVO = new PageRO<>();
            admissionInformationRO.setTeachingPoint(scnuXueliTools.getUserBelongTeachingPoint().getTeachingPointName());
            pageVO.setEntity(admissionInformationRO);
            boolean send = messageSender.sendExportMsg(pageVO, managerFilter, userId);
            if (send) {
                return true;
            }
        }
    }
    return false;
}
```



https://chat.openai.com/c/f916825e-7905-4161-b13e-138d909ebd76

在你提供的代码中，通过使用策略模式的思想，根据用户角色的不同来执行不同的逻辑分支。每种角色对应的逻辑在处理批量导出新生录取数据时略有不同，具体如下：

1. **二级学院管理员** (`SECOND_COLLEGE_ADMIN`):
   - 该管理员只处理其所属学院的录取信息。
   - 首先，通过 `scnuXueliTools.getUserBelongCollege()` 获取管理员所属的学院信息。
   - 然后，设置 `admissionInformationRO` 的学院名称为该管理员所属学院的名称。
   - 最后，封装成 `PageRO` 对象并发送导出请求。

2. **其他管理员** (`XUELIJIAOYUBU_ADMIN`, `CAIWUBU_ADMIN`, `ADMISSION_ADMIN`):
   - 这些角色看起来可以处理更广泛的数据，而不局限于特定的学院或教学点。
   - 他们使用相同的逻辑，直接将 `admissionInformationRO` 封装进 `PageRO` 对象并发送导出请求。
   - 代码没有额外设置特定属性，表明这些角色可能有权限访问所有录取信息。

3. **教学点管理员** (`TEACHING_POINT_ADMIN`):
   - 处理其所属教学点的录取信息。
   - 使用 `scnuXueliTools.getUserBelongTeachingPoint()` 获取所属教学点信息。
   - 设置 `admissionInformationRO` 的教学点名称为所属教学点的名称。
   - 封装成 `PageRO` 对象并发送导出请求。

每个角色的逻辑都包含了生成一个 `PageRO` 对象、设置相关属性（如果需要），并通过 `messageSender.sendExportMsg()` 发送消息以触发导出流程。这些逻辑的差异主要体现在它们设置的属性上（如学院名称或教学点名称），这些属性影响了导出数据的范围和内容。