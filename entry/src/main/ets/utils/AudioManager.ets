import media from '@ohos.multimedia.media';
import resourceManager from '@ohos.resourceManager';
import { AudioItem } from './AudioDiscovery';

export enum PlayState {
  IDLE = 'idle',
  PLAYING = 'playing',
  PAUSED = 'paused',
  STOPPED = 'stopped',
  ERROR = 'error'
}

class AudioManager {
  private avPlayer: media.AVPlayer | null = null;
  private currentAudio: AudioItem | null = null;
  private playState: PlayState = PlayState.IDLE;
  private resMgr: resourceManager.ResourceManager | null = null;
  private onStateChangeCallback: ((state: PlayState) => void) | null = null;
  private onErrorCallback: ((error: string) => void) | null = null;

  setResourceManager(resMgr: resourceManager.ResourceManager): void {
    this.resMgr = resMgr;
  }

  setOnStateChange(callback: (state: PlayState) => void): void {
    this.onStateChangeCallback = callback;
  }

  setOnError(callback: (error: string) => void): void {
    this.onErrorCallback = callback;
  }

  async loadAudio(audio: AudioItem): Promise<boolean> {
    if (!this.resMgr) {
      this.handleError('ResourceManager not initialized');
      return false;
    }
    if (!audio || !audio.rawfileName) {
      this.handleError('Invalid audio: empty filename');
      return false;
    }

    try {
      await this.stop();

      this.avPlayer = await media.createAVPlayer();
      this.setupPlayerCallbacks();

      const fd = await this.resMgr.getRawFd(audio.rawfileName);

      this.avPlayer.fdSrc = {
        fd: fd.fd,
        offset: fd.offset,
        length: fd.length
      };

      this.avPlayer.loop = true;
      await this.avPlayer.prepare();

      this.currentAudio = audio;
      this.updateState(PlayState.STOPPED);

      console.info(`Audio loaded: ${audio.title}`);
      return true;
    } catch (err) {
      this.handleError(`Failed to load audio: ${JSON.stringify(err)}`);
      return false;
    }
  }

  async play(): Promise<boolean> {
    if (!this.avPlayer) {
      this.handleError('No audio loaded');
      return false;
    }

    try {
      await this.avPlayer.play();
      this.updateState(PlayState.PLAYING);
      console.info('Audio play started');
      return true;
    } catch (err) {
      this.handleError(`Failed to play: ${JSON.stringify(err)}`);
      return false;
    }
  }

  async pause(): Promise<boolean> {
    if (!this.avPlayer) {
      return false;
    }

    try {
      await this.avPlayer.pause();
      this.updateState(PlayState.PAUSED);
      return true;
    } catch (err) {
      this.handleError(`Failed to pause: ${JSON.stringify(err)}`);
      return false;
    }
  }

  async stop(): Promise<void> {
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop();
        await this.avPlayer.release();
      } catch (err) {
        console.error('Failed to stop audio:', JSON.stringify(err));
      }
      this.avPlayer = null;
    }
    this.currentAudio = null;
    this.updateState(PlayState.STOPPED);
  }

  async switchAudio(audio: AudioItem): Promise<boolean> {
    const wasPlaying = this.playState === PlayState.PLAYING;
    const success = await this.loadAudio(audio);

    if (success && wasPlaying) {
      await this.play();
    }

    return success;
  }

  private setupPlayerCallbacks(): void {
    if (!this.avPlayer) return;

    this.avPlayer.on('stateChange', (state: string) => {
      console.info(`AVPlayer state changed: ${state}`);
    });

    this.avPlayer.on('error', (err: Error) => {
      this.handleError(`AVPlayer error: ${err.message}`);
    });
  }

  private updateState(state: PlayState): void {
    this.playState = state;
    if (this.onStateChangeCallback) {
      this.onStateChangeCallback(state);
    }
  }

  private handleError(error: string): void {
    console.error(error);
    this.updateState(PlayState.ERROR);
    if (this.onErrorCallback) {
      this.onErrorCallback(error);
    }
  }

  getCurrentAudio(): AudioItem | null {
    return this.currentAudio;
  }

  getPlayState(): PlayState {
    return this.playState;
  }

  isPlaying(): boolean {
    return this.playState === PlayState.PLAYING;
  }
}

export default new AudioManager();
