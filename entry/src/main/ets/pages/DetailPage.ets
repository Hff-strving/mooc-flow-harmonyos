import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import promptAction from '@ohos.promptAction';
import CourseRepository, { Course } from '../utils/CourseRepository';
import CoverHelper from '../utils/CoverHelper';
import DatabaseHelper from '../utils/DatabaseHelper';
import UserManager from '../utils/UserManager';

interface DetailPageParams {
  courseId?: string;
}

@Entry
@Component
struct DetailPage {
  @State course: Course | null = null;
  @State isFavorite: boolean = false;
  private courseId: string = '';

  private getCourseCover(course: Course | null) {
    if (!course) return $r('app.media.cover_cs');
    return CoverHelper.getCover(course);
  }

  async aboutToAppear() {
    const params = router.getParams() as DetailPageParams;
    this.courseId = params.courseId || '';

    await DatabaseHelper.init(getContext(this) as common.Context);
    if (this.courseId) {
      const resMgr = getContext(this).resourceManager;
      await CourseRepository.loadCourses(resMgr);
      this.course = CourseRepository.getCourseById(this.courseId);
    } else {
      this.course = null;
    }

    const userId = UserManager.getCurrentUserId();
    if (userId > 0 && this.courseId) {
      this.isFavorite = await DatabaseHelper.isFavorite(userId, this.courseId);
    } else {
      this.isFavorite = false;
    }
  }

  private async toggleFavorite() {
    const userId = UserManager.getCurrentUserId();
    if (userId <= 0) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (!this.courseId) return;

    await DatabaseHelper.toggleFavorite(userId, this.courseId);
    this.isFavorite = !this.isFavorite;
    promptAction.showToast({ message: this.isFavorite ? '已加入学习计划' : '已取消收藏' });
  }

  private shareBySMS() {
    if (!this.course) return;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const want: Want = {
        action: 'ohos.want.action.sendToMsg',
        parameters: {
          'textContent': `我正在 MOOC Flow 学习《${this.course.name}》，课程ID: ${this.courseId}，来自 ${this.course.school}，快来一起学习吧！`
        }
      };
      context.startAbility(want);
    } catch (err) {
      console.error('Share SMS failed:', JSON.stringify(err));
      promptAction.showToast({ message: '分享失败，请在真机上测试' });
    }
  }

  private startFocus() {
    if (!this.courseId) return;
    router.pushUrl({
      url: 'pages/FocusPage',
      params: { courseId: this.courseId }
    });
  }

  build() {
    Column() {
      Stack() {
        Image(this.getCourseCover(this.course))
          .width('100%')
          .height(230)
          .objectFit(ImageFit.Cover)

        Row() {
          Image($r('app.media.ic_back_white'))
            .width(22)
            .height(22)
            .objectFit(ImageFit.Contain)
            .onClick(() => {
              router.back();
            })

          Blank()

          Image($r('app.media.ic_star_white'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .opacity(this.isFavorite ? 1 : 0.5)
            .margin({ right: 12 })
            .onClick(() => {
              this.toggleFavorite();
            })

          Image($r('app.media.ic_share_white'))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .onClick(() => {
              this.shareBySMS();
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(230)

      Scroll() {
        Column() {
          Column() {
            Text(this.course?.name || '')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })

            Text(this.course?.school || '')
              .fontSize(13)
              .fontColor('#666')
              .margin({ bottom: 14 })

            Row() {
              Text(this.course?.category || '')
                .fontSize(11)
                .fontColor('#1890ff')
                .backgroundColor('#e6f7ff')
                .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                .borderRadius(6)

              Blank()

              Text(this.isFavorite ? '已加入计划' : '加入计划')
                .fontSize(12)
                .fontColor(this.isFavorite ? '#999' : '#1890ff')
                .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                .backgroundColor(this.isFavorite ? '#f5f5f5' : '#ffffff')
                .border({ width: 1, color: '#1890ff' })
                .borderRadius(6)
                .onClick(() => {
                  this.toggleFavorite();
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(16)
          .shadow({ radius: 8, color: '#00000008', offsetY: 2 })

          Column() {
            Text('课程简介')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 10 })

            Text(this.course?.intro || '')
              .fontSize(14)
              .fontColor('#666')
              .lineHeight(24)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(16)
          .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
          .margin({ top: 12 })

          Column() {
            Text('快速开始')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 10 })

            Text('点击下方「开始专注」，进入番茄钟 + 白噪音伴学。')
              .fontSize(13)
              .fontColor('#999')
              .lineHeight(20)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#fff')
          .borderRadius(16)
          .shadow({ radius: 8, color: '#00000008', offsetY: 2 })
          .margin({ top: 12, bottom: 90 })
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor('#f5f8ff')
      .scrollBar(BarState.Auto)

      Row() {
        Button(this.isFavorite ? '已加入' : '加入计划')
          .height(46)
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor('#fff')
          .fontColor('#1890ff')
          .border({ width: 1, color: '#1890ff' })
          .borderRadius(14)
          .onClick(() => {
            this.toggleFavorite();
          })

        Button('开始专注')
          .height(46)
          .layoutWeight(1)
          .fontSize(16)
          .backgroundColor('#1890ff')
          .fontColor('#fff')
          .borderRadius(14)
          .margin({ left: 12 })
          .onClick(() => {
            this.startFocus();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 14 })
      .backgroundColor('#ffffffee')
      .shadow({ radius: 10, color: '#00000020', offsetY: -2 })
    }
    .width('100%')
    .height('100%')
  }
}
