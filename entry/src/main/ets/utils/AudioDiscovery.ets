import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';

export interface AudioItem {
  id: string;
  title: string;
  type: 'music' | 'noise';
  rawfileName: string;
}

interface AudioManifestItem {
  rawfileName: string;
  title?: string;
  type?: 'music' | 'noise';
}

class AudioDiscovery {
  private audioList: AudioItem[] = [];
  private loaded: boolean = false;
  private manifestCache: AudioItem[] = [];
  private readonly builtInFallback: AudioItem[] = [
    { id: 'audio_builtin_0', title: 'Coffee Shop', type: 'noise', rawfileName: '341540__radames__leaf-on-bold-street-coffee-liverpool.mp3' },
    { id: 'audio_builtin_1', title: 'Howling Wind', type: 'noise', rawfileName: '344174__dobroide__20160416_howlingwind02.wav' },
    { id: 'audio_builtin_2', title: 'Wind & Rain Window', type: 'noise', rawfileName: '82614__benboncan__wind-and-rain-on-window-short.wav' },
    { id: 'audio_builtin_3', title: 'Rain + Car Passing', type: 'noise', rawfileName: 'raining_car_crossing_sound.wav' },
    { id: 'audio_builtin_4', title: 'Bensound Endo', type: 'music', rawfileName: 'bensound-endo.mp3' },
    { id: 'audio_builtin_5', title: 'Bensound Estro', type: 'music', rawfileName: 'bensound-estro.mp3' },
    { id: 'audio_builtin_6', title: 'Bensound Silentmoon', type: 'music', rawfileName: 'bensound-silentmoon.mp3' },
    { id: 'audio_builtin_7', title: 'Bensound Starlit', type: 'music', rawfileName: 'bensound-starlit.mp3' }
  ];

  async discoverAudioFiles(resMgr: resourceManager.ResourceManager, force: boolean = false): Promise<AudioItem[]> {
    if (this.loaded && !force) {
      return this.audioList;
    }
    if (force) {
      this.loaded = false;
      this.audioList = [];
    }

    try {
      // 先加载 manifest，保证 Preview 下也有元数据
      this.manifestCache = await this.loadFromManifest(resMgr);
      console.info(`[AudioDiscovery] manifest items=${this.manifestCache.length}`);

      const fileList = await this.getRawFileListRobust(resMgr);
      console.info(`[AudioDiscovery] rawfile list size=${fileList.length}`);
      const audioExtensions = ['.mp3', '.wav', '.m4a', '.ogg'];

      // 先用 manifest 保底
      if (this.manifestCache.length > 0) {
        this.audioList = this.manifestCache.slice();
      }

      // 再尝试 rawfile 列表，若成功则覆盖 audioList
      if (fileList.length > 0) {
        const discovered = fileList
          .filter(fileName => {
            const lowerName = fileName.toLowerCase();
            return audioExtensions.some(ext => lowerName.endsWith(ext));
          })
          .map((fileName, index) => {
            const type = fileName.toLowerCase().startsWith('bensound') ? 'music' : 'noise';
            const title = this.formatTitle(fileName);
            const item: AudioItem = {
              id: `audio_${index}`,
              title,
              type,
              rawfileName: fileName
            };
            return item;
          })
          .map(item => {
            const manifestMeta = this.manifestCache.find(m => m.rawfileName === item.rawfileName);
            if (manifestMeta) {
              return {
                id: item.id,
                title: manifestMeta.title || item.title,
                type: manifestMeta.type || item.type,
                rawfileName: item.rawfileName
              };
            }
            return item;
          });

        if (discovered.length > 0) {
          this.audioList = discovered;
        }
      }

      if (this.audioList.length === 0) {
        this.audioList = [{
          id: 'audio_none',
          title: '未发现音频，可直接计时',
          type: 'noise',
          rawfileName: ''
        }];
      }

      this.loaded = true;
      console.info(`Discovered ${this.audioList.length} audio files`);
    } catch (err) {
      console.error('Failed to discover audio files:', JSON.stringify(err));
      if (this.manifestCache.length > 0) {
        this.audioList = this.manifestCache.slice();
      } else {
        this.audioList = [{
          id: 'audio_none',
          title: '未发现音频，可直接计时',
          type: 'noise',
          rawfileName: ''
        }];
      }
      this.loaded = true;
    }

    return this.audioList;
  }

  private async getRawFileListRobust(resMgr: resourceManager.ResourceManager): Promise<string[]> {
    const candidates = ['', '.', '/', 'rawfile'];
    const all = new Set<string>();
    for (let i = 0; i < candidates.length; i++) {
      try {
        const list = await resMgr.getRawFileList(candidates[i]);
        for (let j = 0; j < list.length; j++) {
          const name = list[j];
          if (name && !name.endsWith('/')) all.add(name);
        }
      } catch (err) {
        console.info(`getRawFileList failed for path ${candidates[i]}: ${JSON.stringify(err)}`);
      }
    }
    return Array.from(all.values());
  }

  private async loadFromManifest(resMgr: resourceManager.ResourceManager): Promise<AudioItem[]> {
    try {
      const rawFileData = await resMgr.getRawFileContent('audio_manifest.json');
      const decoder = new util.TextDecoder('utf-8');
      let jsonStr = decoder.decode(rawFileData);
      jsonStr = jsonStr.replace(/^\uFEFF/, '').replace(/\u0000/g, '').trim();

      const parsed: Object = JSON.parse(jsonStr);
      if (!Array.isArray(parsed)) return [];

      const list = parsed as AudioManifestItem[];
      const audioList: AudioItem[] = [];
      for (let i = 0; i < list.length; i++) {
        const item = list[i];
        const fileName = item.rawfileName;
        if (!fileName) continue;

        const type = item.type || (fileName.toLowerCase().startsWith('bensound') ? 'music' : 'noise');
        const title = item.title || this.formatTitle(fileName);
        audioList.push({ id: `audio_manifest_${i}`, title, type, rawfileName: fileName });
      }
      return audioList;
    } catch (err) {
      console.error('Failed to load audio manifest:', JSON.stringify(err));
      // 最后一层兜底：返回内置文件名清单（用于 Preview/部分设备 rawfile 读取受限的情况）
      return this.builtInFallback.slice();
    }
  }

  private formatTitle(fileName: string): string {
    let name = fileName;
    const lastDotIndex = name.lastIndexOf('.');
    if (lastDotIndex > 0) {
      name = name.substring(0, lastDotIndex);
    }
    name = name.replace(/bensound-/gi, '');
    name = name.replace(/[_-]/g, ' ');
    name = name.replace(/\d+__/g, '');

    const words = name.split(' ');
    const capitalizedWords = words.map(word => {
      if (word.length === 0) return word;
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    });

    return capitalizedWords.join(' ').trim();
  }

  getAllAudio(): AudioItem[] {
    return this.audioList;
  }

  getNoiseAudio(): AudioItem[] {
    return this.audioList.filter(item => item.type === 'noise');
  }

  getMusicAudio(): AudioItem[] {
    return this.audioList.filter(item => item.type === 'music');
  }

  getAudioByRawfileName(rawfileName: string): AudioItem | null {
    return this.audioList.find(item => item.rawfileName === rawfileName) || null;
  }
}

export default new AudioDiscovery();
