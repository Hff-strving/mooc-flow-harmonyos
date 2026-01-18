import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import DatabaseHelper from '../utils/DatabaseHelper';
import CourseRepository from '../utils/CourseRepository';
import AudioDiscovery, { AudioItem } from '../utils/AudioDiscovery';
import AudioManager, { PlayState } from '../utils/AudioManager';
import FocusSessionManager, { FocusSessionState } from '../utils/FocusSessionManager';

interface FocusPageParams {
  courseId?: string;
}

@Entry
@Component
struct FocusPage {
  @State courseName: string = '专注学习';
  @State sessionSeconds: number = 25 * 60;
  @State remainingSeconds: number = 25 * 60;
  @State isRunning: boolean = false;
  @State totalStudySeconds: number = 0;

  @State audioList: AudioItem[] = [];
  @State currentAudio: AudioItem | null = null;
  @State playState: PlayState = PlayState.IDLE;
  @State showAudioSelector: boolean = false;
  @State showDurationPicker: boolean = false;
  @State errorMessage: string = '';

  @State customMinute: number = 0;
  @State customSecond: number = 0;

  private courseId: string = '';
  private effectiveCourseId: string = 'noise';
  private readonly PREF_LAST_AUDIO = 'lastAudioRawfileName';
  private sessionSubId: number = -1;
  private minuteOptions: string[] = [];
  private secondOptions: string[] = [];

  private getMinuteOptions(): string[] {
    if (this.minuteOptions.length === 0) {
      this.minuteOptions = this.buildNumberOptions(180);
    }
    return this.minuteOptions;
  }

  private getSecondOptions(): string[] {
    if (this.secondOptions.length === 0) {
      this.secondOptions = this.buildNumberOptions(59);
    }
    return this.secondOptions;
  }

  async aboutToAppear() {
    const params = router.getParams() as FocusPageParams;
    this.courseId = params?.courseId || '';
    this.effectiveCourseId = this.courseId ? this.courseId : 'noise';

    // 防止页面复用导致的“透明弹窗遮挡/按钮不可点”
    this.showAudioSelector = false;
    this.showDurationPicker = false;

    AppStorage.setOrCreate(this.PREF_LAST_AUDIO, '');

    const ctx = getContext(this) as common.Context;
    const resMgr = ctx.resourceManager;

    // 先把会话绑定起来，确保“开始”立刻可用
    this.courseName = this.courseId ? '专注学习' : '白噪音专注';
    FocusSessionManager.setContext(ctx);
    FocusSessionManager.setCourse(this.effectiveCourseId, this.courseName);
    this.bindSession();

    // 音频初始化也提前
    AudioManager.setResourceManager(resMgr);
    AudioManager.setOnStateChange((state: PlayState) => {
      this.playState = state;
    });
    AudioManager.setOnError((error: string) => {
      console.warn(`[Audio] ${error}`);
      this.errorMessage = '音频加载失败，可直接计时或稍后重试';
      promptAction.showToast({ message: '音频加载失败，可继续计时', duration: 2000 });
      setTimeout(() => {
        this.errorMessage = '';
      }, 3000);
    });

    // 后台加载数据库/课程，不阻塞倒计时
    try {
      await DatabaseHelper.init(ctx);
    } catch (err) {
      console.error('[FocusPage] Database init failed:', JSON.stringify(err));
    }

    if (this.courseId) {
      try {
        await CourseRepository.loadCourses(resMgr);
        const course = CourseRepository.getCourseById(this.courseId);
        if (course?.name) {
          this.courseName = course.name;
          FocusSessionManager.setCourse(this.effectiveCourseId, this.courseName);
        }
      } catch (err) {
        console.error('[FocusPage] Load courses failed:', JSON.stringify(err));
      }
    }

    await this.reloadAudioList(this.courseId === '');
  }

  aboutToDisappear() {
    if (this.sessionSubId >= 0) {
      FocusSessionManager.unsubscribe(this.sessionSubId);
      this.sessionSubId = -1;
    }
    if (!this.isRunning) {
      AudioManager.stop();
    }
  }

  private bindSession(): void {
    if (this.sessionSubId >= 0) return;
    this.sessionSubId = FocusSessionManager.subscribe((state: FocusSessionState) => {
      this.isRunning = state.running;
      this.sessionSeconds = Math.max(1, Math.floor(state.sessionSeconds));
      this.remainingSeconds = state.remainingSeconds;
      this.totalStudySeconds = state.totalStudySeconds;
      // 同步自定义 picker 选中值
      this.customMinute = Math.floor(this.sessionSeconds / 60);
      this.customSecond = this.sessionSeconds % 60;
    });

    const snapshot = FocusSessionManager.getState();
    this.isRunning = snapshot.running;
    this.sessionSeconds = Math.max(1, Math.floor(snapshot.sessionSeconds));
    this.remainingSeconds = snapshot.remainingSeconds;
    this.totalStudySeconds = snapshot.totalStudySeconds;
    this.customMinute = Math.floor(this.sessionSeconds / 60);
    this.customSecond = this.sessionSeconds % 60;
  }

  private getNoiseAudio(): AudioItem[] {
    return this.audioList.filter(item => item.type === 'noise' && item.rawfileName !== '');
  }

  private getMusicAudio(): AudioItem[] {
    return this.audioList.filter(item => item.type === 'music' && item.rawfileName !== '');
  }

  private async reloadAudioList(force: boolean): Promise<void> {
    try {
      const ctx = getContext(this) as common.Context;
      const resMgr = ctx.resourceManager;
      this.audioList = await AudioDiscovery.discoverAudioFiles(resMgr, force);
      console.info(`[FocusPage] Audio list size=${this.audioList.length}`);
      await this.tryLoadDefaultAudio();
    } catch (err) {
      console.error('[FocusPage] Reload audio failed:', JSON.stringify(err));
      this.audioList = [];
      this.currentAudio = null;
    }
  }

  private async tryLoadDefaultAudio(): Promise<void> {
    const validAudioList = this.audioList.filter(item => item.rawfileName !== '');
    if (validAudioList.length === 0) {
      this.currentAudio = null;
      return;
    }

    const lastAudioName = AppStorage.get<string>(this.PREF_LAST_AUDIO) || '';
    let audioToLoad: AudioItem | null = null;
    if (lastAudioName) {
      audioToLoad = validAudioList.find(item => item.rawfileName === lastAudioName) || null;
    }

    if (!audioToLoad) {
      const noiseList = this.getNoiseAudio();
      audioToLoad = noiseList.length > 0 ? noiseList[0] : validAudioList[0];
    }

    await this.loadAudio(audioToLoad);
  }

  private async loadAudio(audio: AudioItem): Promise<void> {
    promptAction.showToast({ message: `正在加载：${audio.title}`, duration: 1200 });
    const ok = await AudioManager.loadAudio(audio);
    if (ok) {
      this.currentAudio = audio;
      AppStorage.setOrCreate(this.PREF_LAST_AUDIO, audio.rawfileName);
      promptAction.showToast({ message: `已选择：${audio.title}`, duration: 1200 });
    } else {
      this.currentAudio = null;
      promptAction.showToast({ message: `音频加载失败：${audio.title}`, duration: 1800 });
    }
  }

  private resetSession(minutes: number): void {
    const seconds = Math.max(60, Math.floor(minutes) * 60);
    this.sessionSeconds = seconds;
    this.remainingSeconds = seconds;
    FocusSessionManager.resetDuration(seconds);
  }

  private async handleStartPause(): Promise<void> {
    if (this.isRunning) {
      FocusSessionManager.pause();
      await AudioManager.pause();
      return;
    }

    FocusSessionManager.start();
    if (this.currentAudio) {
      await AudioManager.play();
    }
  }

  private async stopAndSave(): Promise<void> {
    const studiedSeconds = await FocusSessionManager.finishAndCommit();
    await AudioManager.stop();

    if (studiedSeconds > 0) {
      promptAction.showToast({
        message: `已保存：${Math.max(1, Math.ceil(studiedSeconds / 60))} 分钟`,
        duration: 2000
      });
    }
  }

  private getPrimaryButtonText(): string {
    if (this.isRunning) return '暂停';
    const hasProgress = this.remainingSeconds < this.sessionSeconds;
    return hasProgress ? '继续' : '开始';
  }

  private isStopEnabled(): boolean {
    return this.isRunning || this.remainingSeconds < this.sessionSeconds;
  }

  private formatTime(seconds: number): string {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  private buildNumberOptions(max: number): string[] {
    const list: string[] = [];
    const safeMax = Math.max(0, Math.floor(max));
    for (let i = 0; i <= safeMax; i++) {
      list.push(i.toString().padStart(2, '0'));
    }
    return list;
  }

  build() {
    Column() {
      Row() {
        Image($r('app.media.ic_back'))
          .width(22)
          .height(22)
          .objectFit(ImageFit.Contain)
          .onClick(() => router.back())

        Column() {
          Text('当前课程')
            .fontSize(13)
            .fontColor('#666')

          Text(this.courseName)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .margin({ left: 12 })

        Image($r('app.media.ic_user'))
          .width(20)
          .height(20)
          .objectFit(ImageFit.Contain)
          .opacity(0.9)
          .onClick(() => router.replaceUrl({ url: 'pages/ProfilePage' }))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })

      Row() {
        this.DurationChip(15)
        this.DurationChip(25)
        this.DurationChip(45)
        this.CustomDurationChip()
      }
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 12 })

      Column() {
        Text(this.formatTime(this.remainingSeconds))
          .fontSize(64)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1890ff')
          .margin({ bottom: 8 })

        Text(this.isRunning ? '专注进行中' : '准备开始')
          .fontSize(14)
          .fontColor('#666')
          .margin({ bottom: 18 })

        if (this.currentAudio) {
          this.AudioCard(this.currentAudio)
        } else {
          Column() {
            Text('未选择音频（可直接计时）')
              .fontSize(14)
              .fontColor('#999')
          }
          .padding(12)
          .width('88%')
          .backgroundColor('#ffffffcc')
          .borderRadius(12)
          .margin({ bottom: 16 })
        }

        if (this.errorMessage) {
          Text(this.errorMessage)
            .fontSize(12)
            .fontColor('#d48806')
            .backgroundColor('#fffbe6')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(8)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 10 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 8 })

      Column() {
        Row() {
          Button(this.getPrimaryButtonText())
            .width(120)
            .height(56)
            .fontSize(18)
            .backgroundColor(this.isRunning ? '#ff4d4f' : '#52c41a')
            .borderRadius(14)
            .onClick(() => {
              this.handleStartPause();
            })

          Button('停止')
            .width(86)
            .height(56)
            .fontSize(16)
            .backgroundColor('#fff')
            .fontColor('#333')
            .border({ width: 1, color: '#d9d9d9' })
            .borderRadius(14)
            .margin({ left: 12 })
            .opacity(this.isStopEnabled() ? 1 : 0.45)
            .onClick(() => {
              if (!this.isStopEnabled()) return;
              this.stopAndSave();
            })
        }
        .margin({ bottom: 12 })

        Button(this.currentAudio ? '更换音频' : '选择音频')
          .width('88%')
          .height(44)
          .fontSize(14)
          .backgroundColor('#fff')
          .fontColor('#1890ff')
          .border({ width: 1, color: '#1890ff' })
          .borderRadius(12)
          .onClick(() => {
            this.showAudioSelector = true;
          })

        Row() {
          this.BottomTab('首页', false, $r('app.media.ic_home'), () => router.replaceUrl({ url: 'pages/HomePage' }))
          this.BottomTab('专注', true, $r('app.media.ic_timer'))
          this.BottomTab('我的', false, $r('app.media.ic_user'), () => router.replaceUrl({ url: 'pages/ProfilePage' }))
        }
        .width('100%')
        .height(56)
        .margin({ top: 14 })
        .backgroundColor('#fff')
        .justifyContent(FlexAlign.SpaceAround)
        .borderRadius(16)
        .shadow({ radius: 8, color: '#00000010', offsetY: 2 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f8ff')
    .bindSheet(this.showAudioSelector || this.showDurationPicker, this.UnifiedSheet(), {
      height: this.showAudioSelector ? 520 : 360,
      showClose: true,
      onDisappear: () => {
        this.showAudioSelector = false;
        this.showDurationPicker = false;
      }
    })
  }

  @Builder
  DurationChip(minutes: number) {
    Text(`${minutes} 分钟`)
      .fontSize(13)
      .fontColor(this.sessionSeconds === minutes * 60 ? '#fff' : '#1890ff')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor(this.sessionSeconds === minutes * 60 ? '#1890ff' : '#e6f7ff')
      .borderRadius(18)
      .margin({ right: 10 })
      .onClick(() => {
        if (this.isRunning) return;
        this.resetSession(minutes);
      })
  }

  @Builder
  CustomDurationChip() {
    Text('自定义')
      .fontSize(13)
      .fontColor('#1890ff')
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .backgroundColor('#ffffff')
      .borderRadius(18)
      .margin({ right: 10 })
      .border({ width: 1, color: '#bae7ff' })
      .onClick(() => {
        if (this.isRunning) {
          promptAction.showToast({ message: '请先暂停后再自定义时长', duration: 2000 });
          return;
        }
        this.customMinute = 0;
        this.customSecond = 0;
        this.showDurationPicker = true;
      })
  }

  @Builder
  UnifiedSheet() {
    if (this.showAudioSelector) {
      this.AudioSelectorSheet()
    } else if (this.showDurationPicker) {
      this.DurationPickerSheet()
    } else {
      Column() {}
    }
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

  @Builder
  AudioCard(audio: AudioItem) {
    Column() {
      Row() {
        Text(audio.title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text(audio.type === 'music' ? '音乐' : '白噪音')
          .fontSize(12)
          .fontColor(audio.type === 'music' ? '#722ed1' : '#52c41a')
          .backgroundColor(audio.type === 'music' ? '#f9f0ff' : '#f6ffed')
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .borderRadius(4)
      }
      .width('100%')
      .margin({ bottom: 8 })

      Text(this.playState === PlayState.PLAYING ? '播放中' : this.playState === PlayState.PAUSED ? '已暂停' : '已停止')
        .fontSize(12)
        .fontColor('#999')
        .margin({ bottom: 10 })

      Row() {
        Button(this.playState === PlayState.PLAYING ? '暂停音频' : '播放音频')
          .height(36)
          .fontSize(13)
          .backgroundColor('#fff')
          .fontColor('#1890ff')
          .border({ width: 1, color: '#1890ff' })
          .borderRadius(10)
          .onClick(async () => {
            if (this.playState === PlayState.PLAYING) {
              await AudioManager.pause();
            } else {
              await AudioManager.play();
            }
          })

        Button('停止')
          .height(36)
          .fontSize(13)
          .backgroundColor('#fff')
          .fontColor('#666')
          .border({ width: 1, color: '#d9d9d9' })
          .borderRadius(10)
          .margin({ left: 10 })
          .onClick(async () => {
            await AudioManager.stop();
          })
      }
    }
    .width('88%')
    .padding(14)
    .backgroundColor('#ffffffcc')
    .borderRadius(12)
    .margin({ bottom: 16 })
  }

  @Builder
  AudioSelectorSheet() {
    Column() {
      Text('选择音频')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 12 })

      Text('提示：不选音频也可以正常计时')
        .fontSize(12)
        .fontColor('#999')
        .margin({ bottom: 12 })

      Scroll() {
        Column() {
          this.AudioListItemNone()

          if (this.getNoiseAudio().length > 0) {
            Text('白噪音')
              .fontSize(14)
              .fontColor('#666')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 16, top: 10, bottom: 8 })
            ForEach(this.getNoiseAudio(), (audio: AudioItem) => {
              this.AudioListItem(audio)
            })
          }

          if (this.getMusicAudio().length > 0) {
            Text('背景音乐')
              .fontSize(14)
              .fontColor('#666')
              .alignSelf(ItemAlign.Start)
              .margin({ left: 16, top: 16, bottom: 8 })
            ForEach(this.getMusicAudio(), (audio: AudioItem) => {
              this.AudioListItem(audio)
            })
          }

          if (this.getNoiseAudio().length === 0 && this.getMusicAudio().length === 0) {
            Text('未发现音频资源：可以继续使用计时功能')
              .fontSize(14)
              .fontColor('#999')
              .margin({ top: 20 })
          }

          Button('重新加载音频')
            .width('92%')
            .height(42)
            .fontSize(14)
            .backgroundColor('#fff')
            .fontColor('#1890ff')
            .border({ width: 1, color: '#1890ff' })
            .borderRadius(12)
            .margin({ top: 18, bottom: 16 })
            .onClick(async () => {
              await this.reloadAudioList(true);
            })
        }
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12 })
  }

  @Builder
  AudioListItemNone() {
    Row() {
      Column() {
        Text('不播放音频')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text('只计时（推荐）')
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (!this.currentAudio) {
        Text('✓')
          .fontSize(18)
          .fontColor('#1890ff')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(!this.currentAudio ? '#e6f7ff' : '#fff')
    .borderRadius(12)
    .onClick(async () => {
      this.currentAudio = null;
      AppStorage.setOrCreate(this.PREF_LAST_AUDIO, '');
      await AudioManager.stop();
      this.showAudioSelector = false;
    })
  }

  @Builder
  AudioListItem(audio: AudioItem) {
    Row() {
      Column() {
        Text(audio.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(audio.type === 'music' ? '音乐' : '白噪音')
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.currentAudio?.id === audio.id) {
        Text('✓')
          .fontSize(18)
          .fontColor('#1890ff')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.currentAudio?.id === audio.id ? '#e6f7ff' : '#fff')
    .borderRadius(12)
    .margin({ top: 10 })
    .onClick(async () => {
      promptAction.showToast({ message: `正在加载：${audio.title}`, duration: 1200 });
      const ok = await AudioManager.switchAudio(audio);
      if (ok) {
        this.currentAudio = audio;
        AppStorage.setOrCreate(this.PREF_LAST_AUDIO, audio.rawfileName);
        promptAction.showToast({ message: `已选择：${audio.title}`, duration: 1200 });
      } else {
        this.currentAudio = null;
        promptAction.showToast({ message: `音频加载失败：${audio.title}`, duration: 1800 });
      }
      this.showAudioSelector = false;
    })
  }

  @Builder
  DurationPickerSheet() {
    Column() {
      Text('自定义倒计时')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 18, bottom: 10 })

      Text('上下滑动选择 mm:ss，确定后开始')
        .fontSize(12)
        .fontColor('#999')
        .margin({ bottom: 16 })

      Row() {
        Column() {
          Text('分钟')
            .fontSize(12)
            .fontColor('#666')
            .margin({ bottom: 8 })
          TextPicker({ range: this.getMinuteOptions(), selected: this.customMinute })
            .onChange((value: string | string[], index: number | number[]) => {
              this.customMinute = Array.isArray(index) ? (index.length > 0 ? index[0] : 0) : index;
            })
        }
        .layoutWeight(1)

        Column() {
          Text('秒')
            .fontSize(12)
            .fontColor('#666')
            .margin({ bottom: 8 })
          TextPicker({ range: this.getSecondOptions(), selected: this.customSecond })
            .onChange((value: string | string[], index: number | number[]) => {
              this.customSecond = Array.isArray(index) ? (index.length > 0 ? index[0] : 0) : index;
            })
        }
        .layoutWeight(1)
        .margin({ left: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .margin({ bottom: 18 })

      Row() {
        Button('取消')
          .width('42%')
          .height(44)
          .fontSize(15)
          .backgroundColor('#fff')
          .fontColor('#333')
          .border({ width: 1, color: '#d9d9d9' })
          .borderRadius(12)
          .onClick(() => {
            this.showDurationPicker = false;
          })

        Button('确定')
          .width('42%')
          .height(44)
          .fontSize(15)
          .backgroundColor('#1890ff')
          .fontColor('#fff')
          .borderRadius(12)
          .margin({ left: 12 })
          .onClick(() => {
            const seconds = this.customMinute * 60 + this.customSecond;
            if (seconds <= 0) {
              promptAction.showToast({ message: '请选择大于 00:00 的时长', duration: 2000 });
              return;
            }
            this.sessionSeconds = seconds;
            this.remainingSeconds = seconds;
            FocusSessionManager.resetDuration(seconds);
            this.showDurationPicker = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding({ bottom: 18 })
    }
    .width('100%')
    .height('100%')
  }
}

