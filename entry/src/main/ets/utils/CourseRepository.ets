import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';

export interface Course {
  id: string;
  name: string;
  school: string;
  teacher: string;
  intro: string;
  category: string;
  image: string;
}

class CourseRepository {
  private courses: Course[] = [];
  private loaded: boolean = false;
  private loadingTask: Promise<void> | null = null;
  private fallbackCourses: Course[] = [
    {
      id: 'C001',
      name: 'Python 语言程序设计',
      school: '北京理工大学',
      teacher: '嵩天',
      intro: '零基础入门 Python，覆盖语法、文件、网络、项目实战。',
      category: '计算机',
      image: 'cover_cs.jpg'
    },
    {
      id: 'C002',
      name: '大学历史与文化',
      school: '清华大学',
      teacher: '清华大学',
      intro: '走进大学起源、制度与精神，理解大学之道。',
      category: '人文',
      image: 'history.jpg'
    },
    {
      id: 'C003',
      name: '足球运动与科学',
      school: '清华大学',
      teacher: '清华大学',
      intro: '从科学视角学习足球训练、战术与体能。',
      category: '体育',
      image: 'math.jpg'
    }
  ];

  async loadCourses(resMgr: resourceManager.ResourceManager): Promise<void> {
    if (this.loaded) return;
    if (this.loadingTask) {
      await this.loadingTask;
      return;
    }

    this.loadingTask = (async () => {
      try {
        const rawFileData = await resMgr.getRawFileContent('mooc_data.json');
        const decoder = new util.TextDecoder('utf-8');
        let jsonStr = decoder.decode(rawFileData);
        jsonStr = jsonStr.replace(/^\uFEFF/, '').replace(/\u0000/g, '').trim();

        const parsed: Object = JSON.parse(jsonStr);
        if (Array.isArray(parsed) && parsed.length > 0) {
          this.courses = parsed as Course[];
        } else {
          this.courses = this.fallbackCourses.slice();
        }

        this.loaded = true;
      } catch (err) {
        console.error('Load courses failed:', JSON.stringify(err));
        this.courses = this.fallbackCourses.slice();
      } finally {
        this.loadingTask = null;
      }
    })();

    await this.loadingTask;
  }

  getAllCourses(): Course[] {
    return this.courses;
  }

  getCourseById(id: string): Course | null {
    return this.courses.find(c => c.id === id) || null;
  }
}

export default new CourseRepository();
