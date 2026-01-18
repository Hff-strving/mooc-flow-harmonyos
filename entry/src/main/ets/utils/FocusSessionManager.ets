import common from '@ohos.app.ability.common';
import DatabaseHelper from './DatabaseHelper';
import UserManager from './UserManager';

export interface FocusSessionState {
  courseId: string;
  courseName: string;
  sessionSeconds: number;
  remainingSeconds: number;
  totalStudySeconds: number;
  running: boolean;
}

type Listener = (state: FocusSessionState) => void;

class FocusSessionManager {
  private context: common.Context | null = null;

  private courseId: string = '-';
  private courseName: string = '专注学习';

  private sessionSeconds: number = 25 * 60;
  private remainingSeconds: number = 25 * 60;
  private totalStudySeconds: number = 0;

  private running: boolean = false;
  private tickId: number = -1;
  private startAtMs: number = 0;
  private baseRemainingSeconds: number = 0;
  private baseStudiedSeconds: number = 0;
  private committed: boolean = false;

  private nextListenerId: number = 1;
  private listeners: Map<number, Listener> = new Map();

  setContext(ctx: common.Context): void {
    this.context = ctx;
  }

  setCourse(courseId: string, courseName: string): void {
    // 计时进行中不允许切换课程，避免写入错误的课程记录
    if (this.running) {
      return;
    }
    this.courseId = courseId || '-';
    this.courseName = courseName || '专注学习';
    this.notify();
  }

  getState(): FocusSessionState {
    this.syncNow();
    return {
      courseId: this.courseId,
      courseName: this.courseName,
      sessionSeconds: this.sessionSeconds,
      remainingSeconds: this.remainingSeconds,
      totalStudySeconds: this.totalStudySeconds,
      running: this.running
    };
  }

  subscribe(listener: Listener): number {
    const id = this.nextListenerId++;
    this.listeners.set(id, listener);
    listener(this.getState());
    return id;
  }

  unsubscribe(id: number): void {
    this.listeners.delete(id);
  }

  resetDuration(seconds: number): void {
    if (this.running) return;
    const safe = Math.max(1, Math.floor(seconds));
    this.sessionSeconds = safe;
    this.remainingSeconds = safe;
    this.totalStudySeconds = 0;
    this.committed = false;
    this.notify();
  }

  start(): void {
    if (this.running) return;
    this.running = true;
    this.committed = false;
    this.startAtMs = Date.now();
    this.baseRemainingSeconds = this.remainingSeconds;
    this.baseStudiedSeconds = this.totalStudySeconds;
    this.ensureTicker();
    this.notify();
  }

  pause(): void {
    if (!this.running) return;
    this.syncNow();
    this.running = false;
    this.clearTicker();
    this.notify();
  }

  finish(): void {
    if (this.running) {
      this.syncNow();
    }
    this.running = false;
    this.clearTicker();
    const studied = Math.max(0, Math.floor(this.totalStudySeconds));
    this.commitOnce(studied);
    this.remainingSeconds = this.sessionSeconds;
    this.totalStudySeconds = 0;
    this.committed = false;
    this.notify();
  }

  async finishAndCommit(): Promise<number> {
    if (this.running) {
      this.syncNow();
    }
    this.running = false;
    this.clearTicker();

    const studied = Math.max(0, Math.floor(this.totalStudySeconds));
    await this.commit(studied);

    this.remainingSeconds = this.sessionSeconds;
    this.totalStudySeconds = 0;
    this.committed = false;
    this.notify();
    return studied;
  }

  private ensureTicker(): void {
    if (this.tickId >= 0) return;
    this.tickId = setInterval(() => {
      this.syncNow();
      if (this.running && this.remainingSeconds <= 0) {
        this.running = false;
        this.clearTicker();
        const studied = Math.max(0, Math.floor(this.totalStudySeconds));
        this.commitOnce(studied);
        this.remainingSeconds = this.sessionSeconds;
        this.totalStudySeconds = 0;
        this.committed = false;
      }
      this.notify();
    }, 1000);
  }

  private clearTicker(): void {
    if (this.tickId >= 0) {
      clearInterval(this.tickId);
      this.tickId = -1;
    }
  }

  private syncNow(): void {
    if (!this.running) return;
    const now = Date.now();
    const elapsed = Math.max(0, Math.floor((now - this.startAtMs) / 1000));
    const newRemaining = Math.max(0, this.baseRemainingSeconds - elapsed);
    const newStudied = this.baseStudiedSeconds + elapsed;
    this.remainingSeconds = newRemaining;
    this.totalStudySeconds = newStudied;
  }

  private notify(): void {
    const state = this.getStateSnapshot();
    this.listeners.forEach((listener) => {
      try {
        listener(state);
      } catch (err) {
        console.error('[FocusSession] notify failed:', JSON.stringify(err));
      }
    });
  }

  private getStateSnapshot(): FocusSessionState {
    return {
      courseId: this.courseId,
      courseName: this.courseName,
      sessionSeconds: this.sessionSeconds,
      remainingSeconds: this.remainingSeconds,
      totalStudySeconds: this.totalStudySeconds,
      running: this.running
    };
  }

  private commitOnce(studiedSeconds: number): void {
    if (this.committed) return;
    this.committed = true;
    const studied = Math.max(0, Math.floor(studiedSeconds));
    if (studied <= 0) return;

    const userId = UserManager.getCurrentUserId();
    if (userId <= 0) return;

    if (!this.context) return;

    const ctx = this.context;
    const cid = this.courseId || '-';
    (async () => {
      try {
        await DatabaseHelper.init(ctx);
        await DatabaseHelper.insertStudyRecord(userId, cid, studied);
      } catch (err) {
        console.error('[FocusSession] commit failed:', JSON.stringify(err));
      }
    })();
  }

  private async commit(studiedSeconds: number): Promise<void> {
    const studied = Math.max(0, Math.floor(studiedSeconds));
    if (studied <= 0) return;

    const userId = UserManager.getCurrentUserId();
    if (userId <= 0) return;
    if (!this.context) return;

    try {
      await DatabaseHelper.init(this.context);
      await DatabaseHelper.insertStudyRecord(userId, this.courseId || '-', studied);
    } catch (err) {
      console.error('[FocusSession] commit failed:', JSON.stringify(err));
    }
  }
}

export default new FocusSessionManager();
