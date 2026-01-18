import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import CourseRepository, { Course } from '../utils/CourseRepository';
import DatabaseHelper, { LatestStudyRecord } from '../utils/DatabaseHelper';
import UserManager from '../utils/UserManager';
import SchoolLogoHelper from '../utils/SchoolLogoHelper';
import CoverHelper from '../utils/CoverHelper';

@Entry
@Component
struct HomePage {
  @State courses: Course[] = [];
  @State filteredCourses: Course[] = [];
  @State recommendedCourses: Course[] = [];

  @State currentUsername: string = '';
  @State searchQuery: string = '';
  @State selectedCategory: string = '全部';
  @State categories: string[] = ['全部'];
  @State favoriteCourseIds: string[] = [];

  @StorageLink('statsTotalMinutes') totalMinutes: number = 0;
  @StorageLink('statsStudyCount') studyCount: number = 0;
  @StorageLink('statsFavoriteCount') favoriteCount: number = 0;

  @State lastStudyCourseId: string = '';
  @State lastStudyCourseName: string = '';
  @State lastStudyMinutes: number = 0;

  private searchDebounceId: number = -1;

  async aboutToAppear() {
    this.currentUsername = UserManager.getCurrentUsername();

    const ctx = getContext(this) as common.Context;
    await DatabaseHelper.init(ctx);

    const resMgr = ctx.resourceManager;
    await CourseRepository.loadCourses(resMgr);
    this.courses = CourseRepository.getAllCourses();
    this.categories = this.buildCategories(this.courses);

    await this.refreshUserData();
    this.applyFilters();
  }

  private async refreshUserData() {
    const userId = UserManager.getCurrentUserId();
    if (userId > 0) {
      // 先刷新统计缓存（全局 StorageLink，保证首页/我的同步）
      await DatabaseHelper.refreshStatsCache(userId);

      const favoriteIds = await DatabaseHelper.getFavoriteCourseIds(userId);
      this.favoriteCourseIds = favoriteIds;

      const latest = await DatabaseHelper.getLatestStudyRecord(userId);
      this.applyLatestStudy(latest);
    } else {
      this.favoriteCourseIds = [];
      await DatabaseHelper.refreshStatsCache(-1);
      this.applyLatestStudy(null);
    }
  }

  private applyLatestStudy(latest: LatestStudyRecord | null) {
    if (!latest || !latest.courseId || latest.courseId === '-') {
      this.lastStudyCourseId = '';
      this.lastStudyCourseName = '';
      this.lastStudyMinutes = 0;
      return;
    }

    if (latest.courseId === 'noise') {
      this.lastStudyCourseId = 'noise';
      this.lastStudyCourseName = '白噪音专注';
      this.lastStudyMinutes = Math.max(1, Math.floor(latest.durationSeconds / 60));
      return;
    }

    const course = CourseRepository.getCourseById(latest.courseId);
    this.lastStudyCourseId = latest.courseId;
    this.lastStudyCourseName = course?.name || latest.courseId;
    this.lastStudyMinutes = Math.max(1, Math.floor(latest.durationSeconds / 60));
  }

  private buildCategories(courses: Course[]): string[] {
    const categorySet = new Set<string>();
    for (let i = 0; i < courses.length; i++) {
      const c = courses[i];
      if (c.category) categorySet.add(c.category);
    }
    const list = Array.from(categorySet.values()).sort();
    list.unshift('全部');
    return list;
  }

  private applyFilters() {
    const query = this.searchQuery.trim().toLowerCase();
    const category = this.selectedCategory;

    this.filteredCourses = this.courses.filter(course => {
      const matchCategory = category === '全部' || course.category === category;
      if (!matchCategory) return false;

      if (!query) return true;
      const name = (course.name || '').toLowerCase();
      const school = (course.school || '').toLowerCase();
      return name.includes(query) || school.includes(query);
    });

    this.recommendedCourses = this.filteredCourses.slice(0, 8);
  }

  private onSearchChange(value: string) {
    this.searchQuery = value;
    if (this.searchDebounceId >= 0) {
      clearTimeout(this.searchDebounceId);
      this.searchDebounceId = -1;
    }
    this.searchDebounceId = setTimeout(() => {
      this.applyFilters();
    }, 300);
  }

  private isFavorite(courseId: string): boolean {
    return this.favoriteCourseIds.includes(courseId);
  }

  private async toggleFavorite(courseId: string) {
    const userId = UserManager.getCurrentUserId();
    if (userId <= 0) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }

    await DatabaseHelper.toggleFavorite(userId, courseId);
    const index = this.favoriteCourseIds.indexOf(courseId);
    if (index >= 0) {
      this.favoriteCourseIds.splice(index, 1);
    } else {
      this.favoriteCourseIds.push(courseId);
    }
    this.favoriteCourseIds = [...this.favoriteCourseIds];
    this.favoriteCount = this.favoriteCourseIds.length;
  }

  private getCourseCover(course: Course) {
    return CoverHelper.getCover(course);
  }

  private getSchoolLogo(school: string): Resource | null {
    return SchoolLogoHelper.getLogoResource(school);
  }

  private goRandomCourse() {
    if (this.courses.length === 0) return;
    const randomIndex = Math.floor(Math.random() * this.courses.length);
    const course = this.courses[randomIndex];
    router.pushUrl({ url: 'pages/DetailPage', params: { courseId: course.id } });
  }

  build() {
    Column() {
      Column() {
        Row() {
          Column() {
            Text('MOOC Flow')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#ffffff')

            Text('课程发现 · 学习计划 · 白噪音专注')
              .fontSize(13)
              .fontColor('#ffffffcc')
              .margin({ top: 6 })
          }
          .layoutWeight(1)

          if (this.currentUsername) {
            Text('我的')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1890ff')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#ffffff')
              .borderRadius(16)
              .shadow({ radius: 12, color: '#00000014', offsetY: 2 })
              .onClick(() => {
                router.pushUrl({ url: 'pages/ProfilePage' });
              })
          } else {
            Text('登录')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1890ff')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#fff')
              .borderRadius(16)
              .shadow({ radius: 12, color: '#00000014', offsetY: 2 })
              .onClick(() => {
                router.replaceUrl({ url: 'pages/LoginPage' });
              })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 14 })

        Row() {
          Image($r('app.media.ic_book'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .margin({ left: 12, right: 8 })

          TextInput({ text: this.searchQuery, placeholder: '搜索课程 / 学校' })
            .layoutWeight(1)
            .height(44)
            .type(InputType.Normal)
            .backgroundColor('#ffffff')
            .borderRadius(14)
            .padding({ left: 0, right: 14 })
            .onChange((value: string) => {
              this.onSearchChange(value);
            })
        }
        .width('100%')
        .height(44)
        .backgroundColor('#ffffff')
        .borderRadius(14)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
      .linearGradient({ colors: [[0x1890ff, 0.0], [0x40a9ff, 1.0]] })

      Scroll() {
        Column() {
          Scroll() {
            Row() {
              ForEach(this.categories, (cat: string) => {
                this.CategoryChip(cat)
              })
            }
            .padding({ left: 16, right: 16 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .height(52)

          Row() {
            this.QuickAction('学习计划', $r('app.media.ic_star'), '#fff7e6', '#fa8c16', () => {
              router.pushUrl({ url: 'pages/ProfilePage' });
            })

            this.QuickAction('专注计时', $r('app.media.ic_timer'), '#f6ffed', '#52c41a', () => {
              router.pushUrl({ url: 'pages/FocusPage' });
            })

            this.QuickAction('白噪音', $r('app.media.ic_rainy'), '#e6f7ff', '#1890ff', () => {
              router.pushUrl({ url: 'pages/FocusPage' });
            })

            this.QuickAction('随机一课', $r('app.media.ic_arrow'), '#f9f0ff', '#722ed1', () => {
              this.goRandomCourse();
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 6 })

          if (this.lastStudyCourseId) {
            this.ContinueStudyCard()
          }

          Row() {
            this.StatMini('专注分钟', `${this.totalMinutes}`)
            this.StatMini('学习次数', `${this.studyCount}`)
            this.StatMini('收藏课程', `${this.favoriteCount}`)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12 })

          Row() {
            Text('今日推荐')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text(`${this.recommendedCourses.length} 项`)
              .fontSize(12)
              .fontColor('#999')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 10 })

          Scroll() {
            Row() {
              ForEach(this.recommendedCourses, (course: Course) => {
                this.RecommendCard(course)
              })
            }
            .padding({ left: 16, right: 6 })
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .height(160)

          Row() {
            Text('课程列表')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text(`${this.filteredCourses.length} 门`)
              .fontSize(12)
              .fontColor('#999')
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 10 })

          if (this.filteredCourses.length === 0) {
            Column() {
              Image($r('app.media.ic_confused'))
                .width(64)
                .height(64)
                .objectFit(ImageFit.Contain)
                .opacity(0.8)
                .margin({ bottom: 10 })

              Text('没有找到课程')
                .fontSize(14)
                .fontColor('#666')
                .margin({ bottom: 6 })

              Text('试试换个分类或关键词')
                .fontSize(12)
                .fontColor('#999')
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
          } else {
            Column() {
              ForEach(this.filteredCourses, (course: Course) => {
                this.CourseItem(course)
              })
            }
            .padding({ left: 16, right: 16, bottom: 12 })
          }
        }
      }
      .layoutWeight(1)
      .backgroundColor('#f5f8ff')
      .scrollBar(BarState.Auto)

      Row() {
        this.BottomTab('首页', true, $r('app.media.ic_home'))
        this.BottomTab('专注', false, $r('app.media.ic_timer'), () => router.pushUrl({ url: 'pages/FocusPage' }))
        this.BottomTab('我的', false, $r('app.media.ic_user'), () => router.pushUrl({ url: 'pages/ProfilePage' }))
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
  CategoryChip(cat: string) {
    Text(cat)
      .fontSize(13)
      .fontColor(this.selectedCategory === cat ? '#fff' : '#1890ff')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.selectedCategory === cat ? '#1890ff' : '#e6f7ff')
      .borderRadius(18)
      .margin({ right: 10 })
      .onClick(() => {
        this.selectedCategory = cat;
        this.applyFilters();
      })
  }

  @Builder
  QuickAction(title: string, icon: Resource, bg: string, color: string, onClick: () => void) {
    Column() {
      Image(icon)
        .width(22)
        .height(22)
        .objectFit(ImageFit.Contain)
        .margin({ bottom: 10 })

      Text(title)
        .fontSize(12)
        .fontColor('#333')
        .maxLines(1)
    }
    .width('24%')
    .height(88)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(bg)
    .borderRadius(16)
    .border({ width: 1, color: '#ffffff' })
    .onClick(() => {
      onClick();
    })
  }

  @Builder
  StatMini(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1890ff')
      Text(label)
        .fontSize(12)
        .fontColor('#666')
        .margin({ top: 4 })
    }
    .width('31%')
    .padding(12)
    .backgroundColor('#fff')
    .borderRadius(16)
    .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
  }

  @Builder
  ContinueStudyCard() {
    Row() {
      Image($r('app.media.ic_clock_blue'))
        .width(26)
        .height(26)
        .objectFit(ImageFit.Contain)
        .margin({ right: 10 })

      Column() {
        Text('继续学习')
          .fontSize(12)
          .fontColor('#666')
          .margin({ bottom: 2 })

        Text(this.lastStudyCourseName)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`上次专注 ${this.lastStudyMinutes} 分钟`)
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 4 })
      }
      .layoutWeight(1)

      Text('继续')
        .fontSize(12)
        .fontColor('#1890ff')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor('#e6f7ff')
        .borderRadius(12)
    }
    .width('100%')
    .padding(14)
    .margin({ left: 16, right: 16, top: 12 })
    .backgroundColor('#fff')
    .borderRadius(14)
    .shadow({ radius: 10, color: '#0000000f', offsetY: 4 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { courseId: this.lastStudyCourseId } });
    })
  }

  @Builder
  RecommendCard(course: Course) {
    Column() {
      Image(this.getCourseCover(course))
        .width(160)
        .height(96)
        .borderRadius(14)
        .objectFit(ImageFit.Cover)

      Text(course.name)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10 })

      Row() {
        if (this.getSchoolLogo(course.school)) {
          Image(this.getSchoolLogo(course.school) as Resource)
            .width(18)
            .height(18)
            .borderRadius(4)
            .margin({ right: 6 })
        }
        Text(course.school)
          .fontSize(11)
          .fontColor('#999')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width(160)
    .padding(10)
    .backgroundColor('#fff')
    .borderRadius(16)
    .margin({ right: 12 })
    .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { courseId: course.id } });
    })
  }

  @Builder
  CourseItem(course: Course) {
    Row() {
      Image(this.getCourseCover(course))
        .width(78)
        .height(78)
        .borderRadius(12)
        .objectFit(ImageFit.Cover)

      Column() {
        Row() {
          Text(course.name)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(2)
            .layoutWeight(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Image($r('app.media.ic_star'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .opacity(this.isFavorite(course.id) ? 1 : 0.35)
            .margin({ left: 10 })
            .onClick(() => {
              this.toggleFavorite(course.id);
            })
        }

        Row() {
          if (this.getSchoolLogo(course.school)) {
            Image(this.getSchoolLogo(course.school) as Resource)
              .width(20)
              .height(20)
              .borderRadius(5)
              .margin({ right: 6 })
          }
          Text(course.school)
            .fontSize(12)
            .fontColor('#999')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .margin({ top: 6 })

        Row() {
          Text(course.category)
            .fontSize(11)
            .fontColor('#1890ff')
            .backgroundColor('#e6f7ff')
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .borderRadius(6)

          Blank()

          Text('开始专注')
            .fontSize(12)
            .fontColor('#52c41a')
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .backgroundColor('#f6ffed')
            .borderRadius(6)
            .onClick(() => {
              router.pushUrl({ url: 'pages/FocusPage', params: { courseId: course.id } });
            })
        }
        .margin({ top: 10 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#fff')
    .borderRadius(14)
    .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
    .margin({ bottom: 12 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/DetailPage', params: { courseId: course.id } });
    })
  }

  @Builder
  BottomTab(label: string, active: boolean, icon: Resource, onClick?: () => void) {
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
