class UserManager {
  private static readonly KEY_USER_ID = 'currentUserId';
  private static readonly KEY_USERNAME = 'currentUsername';
  private static readonly KEY_STATS_TOTAL_MINUTES = 'statsTotalMinutes';
  private static readonly KEY_STATS_STUDY_COUNT = 'statsStudyCount';
  private static readonly KEY_STATS_FAVORITE_COUNT = 'statsFavoriteCount';
  private static readonly KEY_STATS_VERSION = 'statsVersion';

  init(): void {
    AppStorage.setOrCreate(UserManager.KEY_USER_ID, -1);
    AppStorage.setOrCreate(UserManager.KEY_USERNAME, '');
    AppStorage.setOrCreate(UserManager.KEY_STATS_TOTAL_MINUTES, 0);
    AppStorage.setOrCreate(UserManager.KEY_STATS_STUDY_COUNT, 0);
    AppStorage.setOrCreate(UserManager.KEY_STATS_FAVORITE_COUNT, 0);
    AppStorage.setOrCreate(UserManager.KEY_STATS_VERSION, 0);
  }

  login(userId: number, username: string): void {
    AppStorage.setOrCreate(UserManager.KEY_USER_ID, userId);
    AppStorage.setOrCreate(UserManager.KEY_USERNAME, username);
  }

  logout(): void {
    AppStorage.setOrCreate(UserManager.KEY_USER_ID, -1);
    AppStorage.setOrCreate(UserManager.KEY_USERNAME, '');
    AppStorage.setOrCreate(UserManager.KEY_STATS_TOTAL_MINUTES, 0);
    AppStorage.setOrCreate(UserManager.KEY_STATS_STUDY_COUNT, 0);
    AppStorage.setOrCreate(UserManager.KEY_STATS_FAVORITE_COUNT, 0);
    AppStorage.setOrCreate(UserManager.KEY_STATS_VERSION, Date.now());
  }

  getCurrentUserId(): number {
    return AppStorage.get<number>(UserManager.KEY_USER_ID) || -1;
  }

  getCurrentUsername(): string {
    return AppStorage.get<string>(UserManager.KEY_USERNAME) || '';
  }

  isLoggedIn(): boolean {
    return this.getCurrentUserId() > 0;
  }
}

export default new UserManager();
