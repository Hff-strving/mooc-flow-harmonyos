import { Course } from './CourseRepository';

class CoverHelper {
  private courseCoverMap: Map<string, Resource> = new Map();
  private categoryCursor: Map<string, number> = new Map();

  private pickCover(categoryKey: string, list: Resource[], courseKey: string): Resource {
    if (this.courseCoverMap.has(courseKey)) {
      return this.courseCoverMap.get(courseKey) as Resource;
    }
    const idx = this.categoryCursor.get(categoryKey) ?? 0;
    const chosen = list[idx % list.length];
    this.categoryCursor.set(categoryKey, idx + 1);
    this.courseCoverMap.set(courseKey, chosen);
    return chosen;
  }

  // 针对具体课程名/ID做优先映射，其次按类别关键词轮换封面
  getCover(course: Course): Resource {
    const name = (course.name || '').toLowerCase();
    const category = (course.category || '').toLowerCase();
    const id = (course.id || '').toLowerCase();
    const courseKey = id || name || category || 'default';

    // 课程名/ID关键词优先
    if (name.includes('线性代数') || id.includes('linear') || name.includes('algebra')) {
      return this.pickCover('linear', [$r('app.media.cover_linear_algebra')], courseKey);
    }
    if (name.includes('c++') || name.includes('c＋＋')) {
      return this.pickCover('cpp', [$r('app.media.cover_cs2')], courseKey);
    }
    if (name.includes('网络技术') || name.includes('应用') || name.includes('计算机科')) {
      return this.pickCover('csnet', [$r('app.media.cover_cs'), $r('app.media.cover_cs2')], courseKey);
    }
    if (name.includes('世界历史') || category.includes('历史')) {
      return this.pickCover('history', [$r('app.media.cover_history2')], courseKey);
    }
    if (name.includes('热带') || category.includes('地理')) {
      return this.pickCover('geo', [$r('app.media.cover_geo'), $r('app.media.cover_geo2')], courseKey);
    }
    if (name.includes('免疫') || category.includes('免疫')) {
      return this.pickCover('immunology', [$r('app.media.cover_immunology'), $r('app.media.cover_immunology2')], courseKey);
    }

    // 类别关键字映射（多封面按序轮换）
    const pick = (catKey: string, list: Resource[]): Resource => this.pickCover(catKey, list, courseKey);

    if (category.includes('数学')) return pick('math', [$r('app.media.math'), $r('app.media.cover_math2')]);
    if (category.includes('物理')) return pick('physics', [$r('app.media.cover_physics'), $r('app.media.cover_physics2')]);
    if (category.includes('化学')) return pick('chem', [$r('app.media.cover_chem'), $r('app.media.cover_chem2')]);
    if (category.includes('地理')) return pick('geo', [$r('app.media.cover_geo'), $r('app.media.cover_geo2')]);
    if (category.includes('地质')) return pick('geology', [$r('app.media.cover_geology'), $r('app.media.cover_geology2')]);
    if (category.includes('农业') || category.includes('农学')) return pick('agri', [$r('app.media.cover_agri'), $r('app.media.cover_agri2')]);
    if (category.includes('教育')) return pick('edu', [$r('app.media.cover_edu'), $r('app.media.cover_edu2'), $r('app.media.cover_edu3')]);
    if (category.includes('心理')) return pick('psych', [$r('app.media.cover_psych'), $r('app.media.cover_psych2')]);
    if (category.includes('机械')) return pick('mech', [$r('app.media.cover_mech'), $r('app.media.cover_mech2'), $r('app.media.cover_mech3')]);
    if (category.includes('材料')) return pick('materials', [$r('app.media.cover_materials'), $r('app.media.cover_materials2')]);
    if (category.includes('电气')) return pick('electrical', [$r('app.media.cover_electrical')]);
    if (category.includes('电子')) return pick('electronics', [$r('app.media.cover_electronics'), $r('app.media.cover_electronics2')]);
    if (category.includes('建筑')) return pick('arch', [$r('app.media.cover_arch'), $r('app.media.cover_arch2')]);
    if (category.includes('哲学') || category.includes('辩证')) return pick('philo', [$r('app.media.cover_philo'), $r('app.media.cover_philo2')]);
    if (category.includes('通识')) return pick('general', [$r('app.media.cover_general')]);
    if (category.includes('医学')) return pick('med', [$r('app.media.cover_med'), $r('app.media.cover_med2')]);
    if (category.includes('语言') || category.includes('英语') || category.includes('外语')) return pick('language', [$r('app.media.language'), $r('app.media.cover_foreignlang'), $r('app.media.cover_linguistics2')]);
    if (category.includes('管理') || category.includes('经济')) return pick('mgmt', [$r('app.media.management'), $r('app.media.cover_mgmt2'), $r('app.media.cover_mgmt3'), $r('app.media.cover_mgmt4'), $r('app.media.cover_mgmt5'), $r('app.media.cover_mgmt6'), $r('app.media.cover_mgmt7')]);
    if (category.includes('计算机') || category.includes('编程') || category.includes('软件')) return pick('cs', [$r('app.media.cover_cs'), $r('app.media.cover_cs2')]);

    // 默认封面
    return this.pickCover('default', [$r('app.media.cover_cs')], courseKey);
  }
}

export default new CoverHelper();
