import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';

const DB_NAME = 'mooc_flow.db';
const DB_VERSION = 1;

const STATS_TOTAL_MINUTES_KEY = 'statsTotalMinutes';
const STATS_STUDY_COUNT_KEY = 'statsStudyCount';
const STATS_FAVORITE_COUNT_KEY = 'statsFavoriteCount';
const STATS_VERSION_KEY = 'statsVersion';

export interface TopCourseStat {
  courseId: string;
  totalMinutes: number;
}

export interface ProfileStats {
  totalMinutes: number;
  studyCount: number;
  favoriteCount: number;
  topCourses: TopCourseStat[];
}

export interface LatestStudyRecord {
  courseId: string;
  durationSeconds: number;
  createTime: string;
}

export interface StudyRecordItem {
  courseId: string;
  durationSeconds: number;
  createTime: string;
}

export interface UserInfo {
  id: number;
  username: string;
}

const SQL_CREATE_USER = `
  CREATE TABLE IF NOT EXISTS User (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TEXT NOT NULL
  )
`;

const SQL_CREATE_FAVORITE = `
  CREATE TABLE IF NOT EXISTS Favorite (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    course_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    UNIQUE(user_id, course_id)
  )
`;

const SQL_CREATE_STUDY_RECORD = `
  CREATE TABLE IF NOT EXISTS StudyRecord (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    course_id TEXT NOT NULL,
    duration INTEGER NOT NULL,
    create_time TEXT NOT NULL
  )
`;

class DatabaseHelper {
  private store: relationalStore.RdbStore | null = null;
  private initTask: Promise<void> | null = null;

  async init(context: common.Context): Promise<void> {
    if (this.store) return;
    if (this.initTask) {
      await this.initTask;
      return;
    }

    this.initTask = (async () => {
      const config: relationalStore.StoreConfig = {
        name: DB_NAME,
        securityLevel: relationalStore.SecurityLevel.S1
      };

      this.store = await relationalStore.getRdbStore(context, config);
      await this.createTables();

      // Ensure stats keys exist for StorageLink bindings.
      AppStorage.setOrCreate(STATS_TOTAL_MINUTES_KEY, 0);
      AppStorage.setOrCreate(STATS_STUDY_COUNT_KEY, 0);
      AppStorage.setOrCreate(STATS_FAVORITE_COUNT_KEY, 0);
      AppStorage.setOrCreate(STATS_VERSION_KEY, 0);
    })();

    try {
      await this.initTask;
    } finally {
      this.initTask = null;
    }
  }

  private async createTables(): Promise<void> {
    if (!this.store) return;
    await this.store.executeSql(SQL_CREATE_USER);
    await this.store.executeSql(SQL_CREATE_FAVORITE);
    await this.store.executeSql(SQL_CREATE_STUDY_RECORD);
  }

  async registerUser(username: string, password: string): Promise<boolean> {
    if (!this.store) return false;
    try {
      const normalizedUsername = username.trim();
      const normalizedPassword = password.trim();
      if (!normalizedUsername || !normalizedPassword) return false;

       // 先查重，避免重复插入
      const exists = await this.getUserByUsername(normalizedUsername);
      if (exists) {
        console.info(`User ${normalizedUsername} already exists`);
        return false;
      }

      const createdAt = new Date().toISOString();
      await this.store.executeSql(
        'INSERT INTO User (username, password, created_at) VALUES (?, ?, ?)',
        [normalizedUsername, normalizedPassword, createdAt]
      );
      return true;
    } catch (err) {
      console.error('Register failed:', JSON.stringify(err));
      return false;
    }
  }

  async login(username: string, password: string): Promise<number> {
    if (!this.store) return -1;
    try {
      const normalizedUsername = username.trim();
      const normalizedPassword = password.trim();
      if (!normalizedUsername || !normalizedPassword) return -1;
      const predicates = new relationalStore.RdbPredicates('User');
      predicates.equalTo('username', normalizedUsername).and().equalTo('password', normalizedPassword);
      const resultSet = await this.store.query(predicates, ['id']);
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow();
        const userId = resultSet.getLong(resultSet.getColumnIndex('id'));
        resultSet.close();
        return userId;
      }
      resultSet.close();
      return -1;
    } catch (err) {
      console.error('Login failed:', JSON.stringify(err));
      return -1;
    }
  }

  async toggleFavorite(userId: number, courseId: string): Promise<void> {
    if (!this.store) return;
    try {
      const isFav = await this.isFavorite(userId, courseId);
      if (isFav) {
        const predicates = new relationalStore.RdbPredicates('Favorite');
        predicates.equalTo('user_id', userId).and().equalTo('course_id', courseId);
        await this.store.delete(predicates);
      } else {
        const createdAt = new Date().toISOString();
        await this.store.executeSql(
          'INSERT OR IGNORE INTO Favorite (user_id, course_id, created_at) VALUES (?, ?, ?)',
          [userId, courseId, createdAt]
        );
      }
      await this.refreshStatsCache(userId);
    } catch (err) {
      console.error('Toggle favorite failed:', JSON.stringify(err));
    }
  }

  async isFavorite(userId: number, courseId: string): Promise<boolean> {
    if (!this.store) return false;
    try {
      const predicates = new relationalStore.RdbPredicates('Favorite');
      predicates.equalTo('user_id', userId).and().equalTo('course_id', courseId);
      const resultSet = await this.store.query(predicates, ['id']);
      const count = resultSet.rowCount;
      resultSet.close();
      return count > 0;
    } catch (err) {
      console.error('Check favorite failed:', JSON.stringify(err));
      return false;
    }
  }

  async getUserByUsername(username: string): Promise<UserInfo | null> {
    if (!this.store) return null;
    try {
      const normalized = username.trim();
      if (!normalized) return null;
      const predicates = new relationalStore.RdbPredicates('User');
      predicates.equalTo('username', normalized);
      const resultSet = await this.store.query(predicates, ['id', 'username']);
      if (resultSet.rowCount > 0) {
        resultSet.goToFirstRow();
        const id = resultSet.getLong(resultSet.getColumnIndex('id'));
        const name = resultSet.getString(resultSet.getColumnIndex('username'));
        resultSet.close();
        return { id, username: name };
      }
      resultSet.close();
      return null;
    } catch (err) {
      console.error('Get user by username failed:', JSON.stringify(err));
      return null;
    }
  }

  async getFavoriteCourseIds(userId: number): Promise<string[]> {
    if (!this.store) return [];
    try {
      const predicates = new relationalStore.RdbPredicates('Favorite');
      predicates.equalTo('user_id', userId);
      const resultSet = await this.store.query(predicates, ['course_id']);
      const ids: string[] = [];
      while (resultSet.goToNextRow()) {
        ids.push(resultSet.getString(resultSet.getColumnIndex('course_id')));
      }
      resultSet.close();
      return ids;
    } catch (err) {
      console.error('Get favorites failed:', JSON.stringify(err));
      return [];
    }
  }

  async insertStudyRecord(userId: number, courseId: string, durationSeconds: number): Promise<void> {
    if (!this.store) return;
    try {
      const createTime = new Date().toISOString();
      await this.store.executeSql(
        'INSERT INTO StudyRecord (user_id, course_id, duration, create_time) VALUES (?, ?, ?, ?)',
        [userId, courseId, durationSeconds, createTime]
      );
      console.info(`[DB] insert StudyRecord user=${userId} course=${courseId} dur=${durationSeconds}s`);
      await this.refreshStatsCache(userId);
    } catch (err) {
      console.error('Insert study record failed:', JSON.stringify(err));
    }
  }

  async refreshStatsCache(userId: number): Promise<void> {
    // This method is intentionally safe to call frequently.
    if (!this.store) return;

    if (userId <= 0) {
      AppStorage.setOrCreate(STATS_TOTAL_MINUTES_KEY, 0);
      AppStorage.setOrCreate(STATS_STUDY_COUNT_KEY, 0);
      AppStorage.setOrCreate(STATS_FAVORITE_COUNT_KEY, 0);
      AppStorage.setOrCreate(STATS_VERSION_KEY, Date.now());
      return;
    }

    const stats = await this.getProfileStats(userId);
    let totalMinutes = stats.totalMinutes;
    let studyCount = stats.studyCount;
    let favoriteCount = stats.favoriteCount;

    // Some environments may return 0 via aggregation; fallback to full read.
    if (studyCount === 0) {
      const records = await this.getRecentStudyRecords(userId, 10000);
      if (records.length > 0) {
        let totalSeconds = 0;
        for (let i = 0; i < records.length; i++) {
          totalSeconds += records[i].durationSeconds;
        }
        studyCount = records.length;
        totalMinutes = Math.max(1, Math.ceil(totalSeconds / 60));
      }
    }

    if (favoriteCount === 0) {
      const favIds = await this.getFavoriteCourseIds(userId);
      favoriteCount = favIds.length;
    }

    AppStorage.setOrCreate(STATS_TOTAL_MINUTES_KEY, totalMinutes);
    AppStorage.setOrCreate(STATS_STUDY_COUNT_KEY, studyCount);
    AppStorage.setOrCreate(STATS_FAVORITE_COUNT_KEY, favoriteCount);
    AppStorage.setOrCreate(STATS_VERSION_KEY, Date.now());
    console.info(`[DB] stats cache updated: minutes=${totalMinutes} count=${studyCount} fav=${favoriteCount}`);
  }

  async getLatestStudyRecord(userId: number): Promise<LatestStudyRecord | null> {
    if (!this.store) return null;
    try {
      const predicates = new relationalStore.RdbPredicates('StudyRecord');
      predicates.equalTo('user_id', userId);

      const resultSet = await this.store.query(predicates, ['course_id', 'duration', 'create_time']);
      let latest: LatestStudyRecord | null = null;
      while (resultSet.goToNextRow()) {
        const courseId = resultSet.getString(resultSet.getColumnIndex('course_id'));
        const durationSeconds = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const createTime = resultSet.getString(resultSet.getColumnIndex('create_time'));
        if (!latest || createTime > latest.createTime) {
          latest = { courseId, durationSeconds, createTime };
        }
      }
      resultSet.close();
      return latest;
    } catch (err) {
      console.error('Get latest study record failed:', JSON.stringify(err));
      return null;
    }
  }

  async getRecentStudyRecords(userId: number, limit: number): Promise<StudyRecordItem[]> {
    if (!this.store) return [];
    const safeLimit = Math.max(0, Math.floor(limit));
    if (safeLimit === 0) return [];

    try {
      const predicates = new relationalStore.RdbPredicates('StudyRecord');
      predicates.equalTo('user_id', userId);

      const resultSet = await this.store.query(predicates, ['course_id', 'duration', 'create_time']);
      const list: StudyRecordItem[] = [];
      while (resultSet.goToNextRow()) {
        const courseId = resultSet.getString(resultSet.getColumnIndex('course_id'));
        const durationSeconds = resultSet.getLong(resultSet.getColumnIndex('duration'));
        const createTime = resultSet.getString(resultSet.getColumnIndex('create_time'));
        list.push({ courseId, durationSeconds, createTime });
      }
      resultSet.close();

      list.sort((a, b) => b.createTime.localeCompare(a.createTime));
      return list.slice(0, safeLimit);
    } catch (err) {
      console.error('Get recent study records failed:', JSON.stringify(err));
      return [];
    }
  }

  async getProfileStats(userId: number): Promise<ProfileStats> {
    if (!this.store) {
      const emptyStats: ProfileStats = { totalMinutes: 0, studyCount: 0, favoriteCount: 0, topCourses: [] };
      return emptyStats;
    }

    try {
      const recordPredicates = new relationalStore.RdbPredicates('StudyRecord');
      recordPredicates.equalTo('user_id', userId);
      const recordSet = await this.store.query(recordPredicates, ['course_id', 'duration']);
      let totalSeconds = 0;
      let studyCount = 0;
      const courseMap = new Map<string, number>();
      while (recordSet.goToNextRow()) {
        const cid = recordSet.getString(recordSet.getColumnIndex('course_id'));
        const dur = recordSet.getLong(recordSet.getColumnIndex('duration'));
        totalSeconds += dur;
        studyCount++;
        courseMap.set(cid, (courseMap.get(cid) || 0) + dur);
      }
      recordSet.close();

      const favPredicates = new relationalStore.RdbPredicates('Favorite');
      favPredicates.equalTo('user_id', userId);
      const favSet = await this.store.query(favPredicates, ['id']);
      let favoriteCount = 0;
      while (favSet.goToNextRow()) {
        favoriteCount++;
      }
      favSet.close();

      const entries = Array.from(courseMap.entries());
      const topCourses: TopCourseStat[] = entries
        .map((entry) => {
          const courseId = entry[0];
          const totalSec = entry[1];
          const item: TopCourseStat = { courseId: courseId, totalMinutes: Math.max(1, Math.ceil(totalSec / 60)) };
          return item;
        })
        .sort((a, b) => b.totalMinutes - a.totalMinutes)
        .slice(0, 3);

      const stats: ProfileStats = {
        totalMinutes: studyCount === 0 ? 0 : Math.max(1, Math.ceil(totalSeconds / 60)),
        studyCount,
        favoriteCount,
        topCourses
      };
      return stats;
    } catch (err) {
      console.error('Get profile stats failed:', JSON.stringify(err));
      const emptyStats: ProfileStats = { totalMinutes: 0, studyCount: 0, favoriteCount: 0, topCourses: [] };
      return emptyStats;
    }
  }
}

export default new DatabaseHelper();
