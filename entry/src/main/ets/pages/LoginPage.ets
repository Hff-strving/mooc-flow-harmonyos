import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import DatabaseHelper from '../utils/DatabaseHelper';
import UserManager from '../utils/UserManager';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State isPasswordVisible: boolean = false;
  @State isLoginMode: boolean = true;
  @State busy: boolean = false;
  @State dbReady: boolean = false;

  async aboutToAppear() {
    this.dbReady = false;
    await DatabaseHelper.init(getContext(this) as common.Context);
    this.dbReady = true;
    UserManager.init();
  }

  private async handleLogin() {
    if (this.busy) return;
    if (!this.dbReady) {
      promptAction.showToast({ message: '数据库初始化中，请稍候…' });
      return;
    }
    if (!this.username || !this.password) {
      promptAction.showToast({ message: '请输入用户名和密码' });
      return;
    }

    this.busy = true;
    const normalizedUsername = this.username.trim();
    const normalizedPassword = this.password.trim();
    const userId = await DatabaseHelper.login(normalizedUsername, normalizedPassword);
    this.busy = false;

    if (userId > 0) {
      UserManager.login(userId, normalizedUsername);
      await DatabaseHelper.refreshStatsCache(userId);
      promptAction.showToast({ message: '登录成功' });
      router.replaceUrl({ url: 'pages/HomePage' });
    } else {
      promptAction.showToast({ message: '用户名或密码错误' });
    }
  }

  private async handleRegister() {
    if (this.busy) return;
    if (!this.dbReady) {
      promptAction.showToast({ message: '数据库初始化中，请稍候…' });
      return;
    }
    if (!this.username || !this.password) {
      promptAction.showToast({ message: '请输入用户名和密码' });
      return;
    }

    this.busy = true;
    const normalizedUsername = this.username.trim();
    const normalizedPassword = this.password.trim();
    const success = await DatabaseHelper.registerUser(normalizedUsername, normalizedPassword);
    this.busy = false;

    if (success) {
      const userId = await DatabaseHelper.login(normalizedUsername, normalizedPassword);
      if (userId > 0) {
        UserManager.login(userId, normalizedUsername);
        await DatabaseHelper.refreshStatsCache(userId);
        promptAction.showToast({ message: '注册并登录成功' });
        router.replaceUrl({ url: 'pages/HomePage' });
      } else {
        const user = await DatabaseHelper.getUserByUsername(normalizedUsername);
        if (user && user.id > 0) {
          UserManager.login(user.id, user.username);
          await DatabaseHelper.refreshStatsCache(user.id);
          promptAction.showToast({ message: '注册并登录成功' });
          router.replaceUrl({ url: 'pages/HomePage' });
        } else {
          promptAction.showToast({ message: '注册成功，请登录' });
          this.isLoginMode = true;
        }
      }
    } else {
      promptAction.showToast({ message: '注册失败：用户名可能已存在' });
    }
  }

  build() {
    Column() {
      Column() {
        Text('MOOC Flow')
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fff')

        Text('智学流 · 课程发现 / 学习计划 / 白噪音专注')
          .fontSize(13)
          .fontColor('#ffffffcc')
          .margin({ top: 10 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 72, bottom: 30 })
      .linearGradient({ colors: [[0x1890ff, 0.0], [0x40a9ff, 1.0]] })

      Column() {
        Text(this.isLoginMode ? '登录' : '注册')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .margin({ bottom: 16 })

        TextInput({ placeholder: '用户名' })
          .width('100%')
          .height(48)
          .backgroundColor('#f5f5f5')
          .borderRadius(14)
          .padding({ left: 14, right: 14 })
          .margin({ bottom: 12 })
          .onChange((value: string) => {
            this.username = value;
          })

        Stack({ alignContent: Alignment.End }) {
          TextInput({ placeholder: '密码' })
            .width('100%')
            .height(48)
            .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
            .backgroundColor('#f5f5f5')
            .borderRadius(14)
            .padding({ left: 14, right: 80 })
            .onChange((value: string) => {
              this.password = value;
            })

          Text(this.isPasswordVisible ? '隐藏' : '显示')
            .fontSize(12)
            .fontColor('#1890ff')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .margin({ right: 10 })
            .backgroundColor('#ffffff')
            .borderRadius(12)
            .onClick(() => {
              this.isPasswordVisible = !this.isPasswordVisible;
            })
        }
        .width('100%')
        .margin({ bottom: 18 })

        Button(this.busy ? '请稍候…' : (this.isLoginMode ? '登录' : '注册'))
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontColor('#fff')
          .backgroundColor(this.busy ? '#91caff' : '#1890ff')
          .borderRadius(14)
          .onClick(() => {
            if (this.isLoginMode) {
              this.handleLogin();
            } else {
              this.handleRegister();
            }
          })

        Row() {
          Text(this.isLoginMode ? '没有账号？' : '已有账号？')
            .fontSize(13)
            .fontColor('#666')

          Text(this.isLoginMode ? '去注册' : '去登录')
            .fontSize(13)
            .fontColor('#1890ff')
            .margin({ left: 6 })
            .onClick(() => {
              this.isLoginMode = !this.isLoginMode;
            })
        }
        .margin({ top: 16 })

        Text('提示：所有数据本地存储，支持离线使用')
          .fontSize(12)
          .fontColor('#999')
          .margin({ top: 18 })
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#fff')
      .borderRadius(18)
      .shadow({ radius: 10, color: '#00000010', offsetY: 2 })
      .margin({ left: 16, right: 16, top: -18 })

      Column().layoutWeight(1) {}
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f8ff')
  }
}
