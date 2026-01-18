#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 MOOCCube 数据集抽取课程子集，生成 mooc_data.json
"""
import json
import re
import html
from collections import Counter, defaultdict

# 平台前缀到学校的映射
PLATFORM_TO_SCHOOL = {
    'TsinghuaX': '清华大学',
    'PekingX': '北京大学',
    'HarvardX': '哈佛大学',
    'MITx': '麻省理工学院',
    'StanfordOnline': '斯坦福大学',
    'BerkeleyX': '加州大学伯克利分校',
    'UQx': '昆士兰大学',
    'McGillX': '麦吉尔大学',
    'TokyoTechX': '东京工业大学',
    'EPFLx': '洛桑联邦理工学院',
    'TUMx': '慕尼黑工业大学',
    'ETHx': '苏黎世联邦理工学院',
    'OxfordX': '牛津大学',
    'CambridgeX': '剑桥大学',
    'ColumbiaX': '哥伦比亚大学',
    'CornellX': '康奈尔大学',
    'YaleX': '耶鲁大学',
    'PrincetonX': '普林斯顿大学',
    'UTokyoX': '东京大学',
    'KyotoUx': '京都大学',
}

# 分类到图标的映射
CATEGORY_TO_IMAGE = {
    '数学': 'cat_math.png',
    '物理': 'cat_physics.png',
    '化学': 'cat_chemistry.png',
    '生物': 'cat_biology.png',
    '计算机': 'cat_cs.png',
    '工程': 'cat_engineering.png',
    '经济': 'cat_economics.png',
    '管理': 'cat_management.png',
    '文学': 'cat_literature.png',
    '历史': 'cat_history.png',
    '哲学': 'cat_philosophy.png',
    '艺术': 'cat_art.png',
    '医学': 'cat_medicine.png',
    '法学': 'cat_law.png',
    '教育': 'cat_education.png',
}


def extract_platform_from_id(course_id):
    """从课程 ID 提取平台前缀"""
    # 格式示例: C_course-v1:TsinghuaX+...
    match = re.search(r'course-v1:([^+]+)', course_id)
    if match:
        return match.group(1)
    # 其他格式
    match = re.search(r'C_([^_]+)', course_id)
    if match:
        return match.group(1)
    return 'Unknown'


def get_school_from_platform(platform):
    """根据平台获取学校名称"""
    return PLATFORM_TO_SCHOOL.get(platform, platform)


def clean_html(html_text):
    """去除 HTML 标签并解码实体"""
    if not html_text:
        return ''
    # 去除 HTML 标签
    text = re.sub(r'<[^>]+>', '', html_text)
    # 解码 HTML 实体
    text = html.unescape(text)
    # 去除多余空白
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def load_course_concepts(filepath):
    """加载课程-概念映射，提取分类"""
    course_categories = defaultdict(list)

    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                parts = line.split('\t')
                if len(parts) >= 2:
                    course_id = parts[0].strip()
                    concept_id = parts[1].strip()

                    # 从概念 ID 提取分类（最后一个下划线后的内容）
                    if '_' in concept_id:
                        category = concept_id.split('_')[-1]
                        course_categories[course_id].append(category)
    except FileNotFoundError:
        print(f"警告: {filepath} 不存在，将使用默认分类")

    # 对每门课程，取出现最多的分类
    course_category_map = {}
    for course_id, categories in course_categories.items():
        if categories:
            most_common = Counter(categories).most_common(1)[0][0]
            course_category_map[course_id] = most_common

    return course_category_map


def load_courses(filepath, category_map, target_count=50):
    """加载课程数据并抽取子集"""
    courses = []
    category_counts = defaultdict(int)

    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue

                try:
                    course = json.loads(line)

                    # 提取字段
                    course_id = course.get('id', '')
                    name = course.get('name', '').strip()
                    about = course.get('about', '')

                    # 过滤：名称必须存在
                    if not course_id or not name:
                        continue

                    # 清理简介
                    intro = clean_html(about)
                    if len(intro) < 30:
                        intro = '本课程提供系统化的学习内容，帮助学生掌握核心知识与技能。'
                    else:
                        intro = intro[:200] + ('...' if len(intro) > 200 else '')

                    # 提取学校
                    platform = extract_platform_from_id(course_id)
                    school = get_school_from_platform(platform)

                    # 获取分类
                    category = category_map.get(course_id, '通识')

                    # 教师字段（数据集无此字段，使用学校代替）
                    teacher = school

                    # 图标
                    image = CATEGORY_TO_IMAGE.get(category, 'cat_default.png')

                    # 构造输出对象
                    course_obj = {
                        'id': course_id,
                        'name': name,
                        'school': school,
                        'teacher': teacher,
                        'intro': intro,
                        'category': category,
                        'image': image
                    }

                    courses.append(course_obj)
                    category_counts[category] += 1

                except json.JSONDecodeError:
                    continue

    except FileNotFoundError:
        print(f"错误: {filepath} 不存在")
        return []

    # 分层抽样：每个分类先取 2 门
    selected = []
    courses_by_category = defaultdict(list)
    for course in courses:
        courses_by_category[course['category']].append(course)

    # 第一轮：每类取 2 门
    for category, course_list in courses_by_category.items():
        selected.extend(course_list[:2])

    # 第二轮：从剩余课程补齐到目标数量
    remaining = [c for c in courses if c not in selected]
    selected.extend(remaining[:target_count - len(selected)])

    return selected[:target_count]


def main():
    print("开始抽取 MOOCCube 课程数据...")

    # 文件路径
    course_file = 'data/MOOCCube/entities/course.json'
    concept_file = 'data/MOOCCube/relations/course-concept.json'
    output_file = 'entry/src/main/resources/rawfile/mooc_data.json'

    # 加载分类映射
    print("1. 加载课程-概念映射...")
    category_map = load_course_concepts(concept_file)
    print(f"   已加载 {len(category_map)} 门课程的分类信息")

    # 加载并抽取课程
    print("2. 加载课程数据...")
    courses = load_courses(course_file, category_map, target_count=50)
    print(f"   已抽取 {len(courses)} 门课程")

    # 统计分类分布
    category_dist = Counter([c['category'] for c in courses])
    print("3. 分类分布:")
    for cat, count in category_dist.most_common():
        print(f"   {cat}: {count} 门")

    # 写入输出文件
    print(f"4. 写入 {output_file}...")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(courses, f, ensure_ascii=False, indent=2)

    print("✓ 完成！")
    print(f"生成的 mooc_data.json 包含 {len(courses)} 门课程")


if __name__ == '__main__':
    main()
