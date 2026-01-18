# MOOC Flow（智学流）- HarmonyOS ArkTS 课程项目

一款基于 MOOCCube 裁剪数据的效率型教育应用，集「课程发现 / 学习计划（收藏）/ 专注倒计时 / 白噪音伴学 / 学习数据统计 / 系统分享」于一体。

## 功能概览

- 注册/登录：本地 SQLite（HarmonyOS RDB）持久化用户信息
- 课程发现：首页分类筛选 + 搜索 + 课程列表（来自 `resources/rawfile/mooc_data.json`）
- 课程详情：课程封面/简介展示；收藏（加入学习计划）；开始专注；分享课程（调用系统消息能力）
- 专注学习：番茄钟倒计时（15/25/45 + 自定义时长）；支持暂停/继续/停止保存；专注记录写入数据库
- 白噪音/音乐：从 `resources/rawfile/` 发现音频并用 AVPlayer 播放；播放失败不影响计时（有提示）
- 个人中心：总专注时长/学习次数/收藏课程数；TOP3；最近专注；学习计划列表

## 技术栈

- UI：ArkTS + ArkUI（声明式 UI）
- 路由：`@ohos.router`
- 本地数据库：`@ohos.data.relationalStore`（RdbStore / SQLite）
- 音频：`@ohos.multimedia.media`（AVPlayer）
- 资源：`resourceManager`（rawfile / media）

## 页面与代码结构

页面（`entry/src/main/ets/pages`）：

- `LoginPage.ets`：注册/登录
- `HomePage.ets`：课程发现 + 搜索/筛选 + 统计卡片
- `DetailPage.ets`：课程详情 + 收藏 + 分享 + 跳转专注
- `FocusPage.ets`：专注倒计时 + 自定义时长 + 音频选择/播放
- `ProfilePage.ets`：个人中心 + 统计 + TOP3 + 最近专注 + 学习计划

核心工具（`entry/src/main/ets/utils`）：

- `DatabaseHelper.ets`：建表、登录/注册、收藏、学习记录、统计缓存刷新
- `FocusSessionManager.ets`：专注会话管理（计时、暂停、结束写库、跨页面保持）
- `CourseRepository.ets`：读取 `mooc_data.json` 并缓存课程列表
- `AudioDiscovery.ets`：发现 rawfile 音频（含 manifest 兜底）
- `AudioManager.ets`：AVPlayer 封装（load/play/pause/stop + 错误回调）

## 数据与资源

- 课程数据：`entry/src/main/resources/rawfile/mooc_data.json`（MOOCCube 裁剪子集）
- 音频清单：`entry/src/main/resources/rawfile/audio_manifest.json`
- 音频文件：`entry/src/main/resources/rawfile/*.mp3`（或其他音频格式）
- 课程封面：`entry/src/main/resources/base/media/`、`entry/src/main/resources/course/`（按项目实际放置）
- 校徽：`entry/src/main/resources/base/schools/`

## 数据库说明（SQLite / RDB）

数据库文件名：`mooc_flow.db`（见 `entry/src/main/ets/utils/DatabaseHelper.ets`）。

表结构：

- `User`：用户表（`username` 唯一）
- `Favorite`：收藏/学习计划（`(user_id, course_id)` 唯一）
- `StudyRecord`：专注记录（`duration` 秒、`create_time` 时间戳；白噪音专注使用 `course_id='noise'`）

数据库文件位于应用沙箱（包名见 `AppScope/app.json5`）：

- 常见路径（真机/模拟器其一存在）：
  - `/data/storage/el2/database/<bundleName>/rdb/mooc_flow.db`
  - `/data/storage/el1/database/<bundleName>/rdb/mooc_flow.db`

## 构建与运行

推荐：使用 DevEco Studio 打开项目并运行到模拟器/真机。

命令行构建（可选）：

1. 配置 HarmonyOS SDK 环境变量（示例）：
   - `DEVECO_SDK_HOME=E:\DevEco Studio\sdk`
2. 运行 hvigor：
   - `E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat -p entry assembleHap --no-daemon`

## 截图与文档

实验报告中建议展示：

- 页面流程/跳转总图、E-R 图、三表结构截图
- 关键界面：登录、首页、课程详情、专注（含自定义时长与音频选择）、个人中心
- 核心代码：`DatabaseHelper`、`FocusSessionManager`、`AudioManager/AudioDiscovery`、典型 UI 布局（Stack/Scroll）

## 免责声明

本项目为课程作业用途，数据库中密码为明文存储，仅用于演示本地存储/登录流程；实际产品应进行加盐哈希等安全处理。
