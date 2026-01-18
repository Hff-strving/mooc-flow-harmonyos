import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import DatabaseHelper from '../utils/DatabaseHelper';
import UserManager from '../utils/UserManager';
import CourseRepository from '../utils/CourseRepository';

interface ProfileTopCourseItem {
  courseId: string;
  totalMinutes: number;
  courseName: string;
}

interface FavoriteCourseItem {
  courseId: string;
  courseName: string;
}

interface RecentStudyItem {
  courseId: string;
  courseName: string;
  durationMinutes: number;
  timeText: string;
}

@Entry
@Component
struct ProfilePage {
  @State username: string = '';
  @State isLoggedIn: boolean = false;
  @StorageLink('statsTotalMinutes') totalMinutes: number = 0;
  @StorageLink('statsStudyCount') studyCount: number = 0;
  @StorageLink('statsFavoriteCount') favoriteCount: number = 0;
  @State topCourses: ProfileTopCourseItem[] = [];
  @State favoriteCourses: FavoriteCourseItem[] = [];
  @State recentStudies: RecentStudyItem[] = [];

  private formatIsoTime(iso: string): string {
    if (!iso) return '';
    return iso.replace('T', ' ').slice(0, 16);
  }

  async aboutToAppear() {
    this.username = UserManager.getCurrentUsername();
    const userId = UserManager.getCurrentUserId();
    this.isLoggedIn = userId > 0;
    if (userId <= 0) {
      this.username = '';
      this.totalMinutes = 0;
      this.studyCount = 0;
      this.favoriteCount = 0;
      this.topCourses = [];
      this.favoriteCourses = [];
      this.recentStudies = [];
      return;
    }

    const ctx = getContext(this) as common.Context;
    await DatabaseHelper.init(ctx);
    await DatabaseHelper.refreshStatsCache(userId);

    const resMgr = ctx.resourceManager;
    await CourseRepository.loadCourses(resMgr);

    const favoriteIds = await DatabaseHelper.getFavoriteCourseIds(userId);
    this.favoriteCount = favoriteIds.length;
    this.favoriteCourses = favoriteIds.slice(0, 8).map(courseId => {
      const course = CourseRepository.getCourseById(courseId);
      const item: FavoriteCourseItem = {
        courseId,
        courseName: course?.name || courseId
      };
      return item;
    });

    // 列表使用全量记录计算；顶部三项统计使用 DatabaseHelper.refreshStatsCache() 的全局缓存
    const recent = await DatabaseHelper.getRecentStudyRecords(userId, 10000);
    const courseMap = new Map<string, number>();
    for (let i = 0; i < recent.length; i++) {
      const cid = recent[i].courseId;
      courseMap.set(cid, (courseMap.get(cid) || 0) + recent[i].durationSeconds);
    }

    const entries = Array.from(courseMap.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3);
    this.topCourses = entries.map((entry) => {
      const courseId = entry[0];
      const seconds = entry[1];
      if (courseId === 'noise') {
        return { courseId: 'noise', totalMinutes: Math.max(1, Math.ceil(seconds / 60)), courseName: '白噪音专注' };
      }
      const course = CourseRepository.getCourseById(courseId);
      const viewItem: ProfileTopCourseItem = {
        courseId,
        totalMinutes: Math.max(1, Math.ceil(seconds / 60)),
        courseName: course?.name || courseId
      };
      return viewItem;
    });

    const viewList: RecentStudyItem[] = [];
    for (let i = 0; i < Math.min(10, recent.length); i++) {
      const rec = recent[i];
      const course = rec.courseId === 'noise' ? null : CourseRepository.getCourseById(rec.courseId);
      const minutes = Math.max(1, Math.ceil(rec.durationSeconds / 60));
      viewList.push({
        courseId: rec.courseId,
        courseName: rec.courseId === 'noise' ? '白噪音专注' : (course?.name || rec.courseId),
        durationMinutes: minutes,
        timeText: this.formatIsoTime(rec.createTime)
      });
    }
    this.recentStudies = viewList;
  }

  build() {
    Column() {
      Column() {
        Row() {
          Image($r('app.media.startIcon'))
            .width(64)
            .height(64)
            .borderRadius(18)
            .margin({ right: 14 })

          Column() {
            Text(this.username || '未登录')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#fff')

            Text('坚持学习，不断进步')
              .fontSize(13)
              .fontColor('#ffffffcc')
              .margin({ top: 6 })
          }
          .layoutWeight(1)

          if (this.isLoggedIn) {
            Text('退出')
              .fontSize(14)
              .fontColor('#fff')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#ff4d4f')
              .borderRadius(14)
              .shadow({ radius: 8, color: '#00000012', offsetY: 2 })
              .onClick(() => {
                UserManager.logout();
                router.replaceUrl({ url: 'pages/LoginPage' });
              })
          } else {
            Text('登录')
              .fontSize(14)
              .fontColor('#1890ff')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor('#fff')
              .borderRadius(14)
              .shadow({ radius: 8, color: '#00000012', offsetY: 2 })
              .onClick(() => {
                router.replaceUrl({ url: 'pages/LoginPage' });
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 16 })
      }
      .width('100%')
      .linearGradient({ colors: [[0x1890ff, 0.0], [0x40a9ff, 1.0]] })

      Scroll() {
        Column() {
          Row() {
            this.StatCard('总专注时长', `${this.totalMinutes}`, '分钟')
            this.StatCard('学习次数', `${this.studyCount}`, '次')
            this.StatCard('收藏课程', `${this.favoriteCount}`, '门')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceAround)
          .margin({ bottom: 14 })

          Column() {
            Text('学习排行 TOP 3')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            if (this.topCourses.length === 0) {
              Text('暂无学习记录')
                .fontSize(13)
                .fontColor('#999')
                .margin({ top: 10 })
            } else {
              ForEach(this.topCourses, (item: ProfileTopCourseItem, index: number) => {
                this.TopCourseItem(index + 1, item.courseName, item.totalMinutes)
              })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(16)
          .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
          .margin({ bottom: 12 })

          Column() {
            Text('最近专注')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            if (this.recentStudies.length === 0) {
              Text('暂无专注记录：去开始一次专注吧')
                .fontSize(13)
                .fontColor('#999')
                .margin({ top: 6 })
            } else {
              ForEach(this.recentStudies, (item: RecentStudyItem) => {
                this.RecentStudyRow(item)
              })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(16)
          .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
          .margin({ bottom: 12 })

          Column() {
            Row() {
              Text('我的学习计划')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .layoutWeight(1)

              Text('查看全部')
                .fontSize(13)
                .fontColor('#1890ff')
                .onClick(() => {
                  router.replaceUrl({ url: 'pages/HomePage' });
                })
            }
            .margin({ bottom: 12 })

            if (this.favoriteCourses.length === 0) {
              Text('还没有收藏课程：去首页挑一门开始吧')
                .fontSize(13)
                .fontColor('#999')
                .margin({ top: 6 })
            } else {
              ForEach(this.favoriteCourses, (item: FavoriteCourseItem) => {
                this.FavoriteCourseItem(item)
              })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(16)
          .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
          .margin({ bottom: 80 })
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding(16)
      .backgroundColor('#f5f8ff')
      .scrollBar(BarState.Auto)

      Row() {
        this.TabItem('首页', false, $r('app.media.ic_home'), () => {
          router.replaceUrl({ url: 'pages/HomePage' });
        })
        this.TabItem('专注', false, $r('app.media.ic_timer'), () => {
          router.replaceUrl({ url: 'pages/FocusPage' });
        })
        this.TabItem('我的', true, $r('app.media.ic_user'))
      }
      .width('100%')
      .height(56)
      .backgroundColor('#fff')
      .justifyContent(FlexAlign.SpaceAround)
      .shadow({ radius: 2, color: '#00000010', offsetY: -2 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  StatCard(label: string, value: string, unit: string) {
    Column() {
      Text(value)
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890ff')

      Text(unit)
        .fontSize(12)
        .fontColor('#999')
        .margin({ top: 2, bottom: 8 })

      Text(label)
        .fontSize(12)
        .fontColor('#666')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('30%')
    .padding(14)
    .backgroundColor('#fff')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
  }

  @Builder
  RecentStudyRow(item: RecentStudyItem) {
    Row() {
      Column() {
        Text(item.courseName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(item.timeText)
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)

      Text(`${item.durationMinutes} 分钟`)
        .fontSize(13)
        .fontColor('#1890ff')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#e6f7ff')
        .borderRadius(12)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: 0.5, color: '#f0f0f0' })
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { courseId: item.courseId } });
    })
  }

  @Builder
  TopCourseItem(rank: number, courseName: string, minutes: number) {
    Row() {
      Text(`${rank}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(rank === 1 ? '#faad14' : rank === 2 ? '#8c8c8c' : '#d4b106')
        .width(32)

      Column() {
        Text(courseName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`学习 ${minutes} 分钟`)
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 10 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#fafafa')
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  FavoriteCourseItem(item: FavoriteCourseItem) {
    Row() {
      Column() {
        Text(item.courseName)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('详情')
        .fontSize(12)
        .fontColor('#1890ff')
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('#e6f7ff')
        .borderRadius(10)
        .onClick(() => {
          router.pushUrl({ url: 'pages/DetailPage', params: { courseId: item.courseId } });
        })

      Text('专注')
        .fontSize(12)
        .fontColor('#52c41a')
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor('#f6ffed')
        .borderRadius(10)
        .margin({ left: 8 })
        .onClick(() => {
          router.replaceUrl({ url: 'pages/FocusPage', params: { courseId: item.courseId } });
        })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#fff')
    .border({ width: 1, color: '#f0f0f0' })
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  TabItem(label: string, active: boolean, icon: Resource, onClick?: () => void) {
    Column() {
      Image(icon)
        .width(22)
        .height(22)
        .opacity(active ? 1 : 0.6)

      Text(label)
        .fontSize(14)
        .fontColor(active ? '#1890ff' : '#666')
    }
    .onClick(() => {
      if (onClick) onClick();
    })
  }
}
