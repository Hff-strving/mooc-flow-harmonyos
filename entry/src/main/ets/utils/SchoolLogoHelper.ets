export default class SchoolLogoHelper {
  static getLogoResource(school: string): Resource | null {
    if (!school) return null;
    const s = school.toLowerCase();

    if (s.includes('清华')) return $r('app.media.logo_tsinghua');
    if (s.includes('北京大学') || s.includes('pku')) return $r('app.media.logo_pku');
    if (s.includes('麦吉尔') || s.includes('mcgill')) return $r('app.media.logo_mcgill');
    if (s.includes('昆士兰') || s.includes('queensland')) return $r('app.media.logo_queensland');
    if (s.includes('ricex') || s.includes('rice')) return $r('app.media.logo_ricex');
    if (s.includes('ust')) return $r('app.media.logo_hkust');
    if (s.includes('sdux')) return $r('app.media.logo_sdux');
    if (s.includes('bit')) return $r('app.media.logo_bit');
    if (s.includes('hubu')) return $r('app.media.logo_hubu');
    if (s.includes('seu')) return $r('app.media.logo_seu');
    if (s.includes('jsux')) return $r('app.media.logo_jsux');
    if (s.includes('xjtu')) return $r('app.media.logo_xjtu');
    if (s.includes('tju')) return $r('app.media.logo_tju');
    if (s.includes('fzx') || s.includes('fzxy')) return $r('app.media.logo_fzxhy');
    if (s.includes('imun')) return $r('app.media.logo_imun');
    if (s.includes('hnu')) return $r('app.media.logo_hnu');
    if (s.includes('hkust')) return $r('app.media.logo_hkust');

    return null;
  }
}
