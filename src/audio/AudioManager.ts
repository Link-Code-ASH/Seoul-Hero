import { AUDIO_CONFIG, preloadedAudioUrls, bgm, sfx } from '../data/audio';
import type { BgmId, BgmTrack, SfxId } from '../data/audio';
import type { Settings } from '../state/MetaState';
import { SoundGate } from './AudioPolicy';

interface EffectVoice { source: AudioBufferSourceNode; gain: GainNode; id: SfxId; priority: number }

/** Browser output adapter. The simulation only emits domain events and knows no audio APIs. */
export class AudioManager {
  private context: AudioContext | null = null;
  private master: GainNode | null = null;
  private musicBus: GainNode | null = null;
  private combatBus: GainNode | null = null;
  private combatTone: BiquadFilterNode | null = null;
  private uiBus: GainNode | null = null;
  private analyser: AnalyserNode | null = null;
  private readonly samples = new Float32Array(256);
  private readonly bytes = new Map<string, ArrayBuffer>();
  private readonly buffers = new Map<string, AudioBuffer>();
  private readonly voices = new Set<EffectVoice>();
  private readonly variantCursor = new Map<SfxId, number>();
  private readonly lastMusicUrl = new Map<BgmId, string>();
  private readonly gate = new SoundGate();
  private musicElement: HTMLAudioElement | null = null;
  private musicSource: MediaElementAudioSourceNode | null = null;
  private musicGain: GainNode | null = null;
  private nextMusicElement: HTMLAudioElement | null = null;
  private nextTrack: BgmTrack | null = null;
  private musicFadeTimer = 0;
  private loading: Promise<void> | null = null;
  private unlocking: Promise<void> | null = null;
  private currentGroup: BgmId | null = null;
  private currentTrack: BgmTrack | null = null;
  private desired: BgmId | null = 'menu';
  private hidden = false;
  private dimmed = false;
  private disposed = false;
  private stateText = '버튼을 누르면 소리가 시작됩니다';
  playedCount = 0;
  lastSound = '—';

  constructor(private settings: Settings) {}
  get status(): string { return this.stateText; }
  get unlocked(): boolean { return this.context?.state === 'running' && this.buffers.size > 0; }
  get currentBgm(): string { return this.currentTrack?.label ?? '없음'; }
  get activeVoices(): number { return this.voices.size; }
  get loadedCount(): number { return this.buffers.size; }
  get contextState(): string { return this.context?.state ?? 'locked'; }
  get outputLevel(): number {
    if (!this.analyser || !this.unlocked || this.hidden) return 0;
    this.analyser.getFloatTimeDomainData(this.samples);
    let sum = 0;
    for (const value of this.samples) sum += value * value;
    return Math.sqrt(sum / this.samples.length);
  }

  prepare(): Promise<void> {
    if (this.loading) return this.loading;
    this.loading = Promise.all(preloadedAudioUrls().map(async (url) => {
      try {
        const response = await fetch(url);
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        this.bytes.set(url, await response.arrayBuffer());
      } catch { this.stateText = '일부 사운드를 불러오지 못했습니다. 새로고침으로 다시 시도하세요.'; }
    })).then(() => {});
    return this.loading;
  }

  /** Invoke inside a pointer/key gesture; do not attempt to bypass browser autoplay rules. */
  unlock(): Promise<void> {
    if (this.disposed) return Promise.resolve();
    if (this.unlocking) return this.unlocking;
    try {
      if (!this.context) {
        this.context = new AudioContext();
        this.master = this.context.createGain();
        this.musicBus = this.context.createGain();
        this.combatBus = this.context.createGain();
        this.combatTone = this.context.createBiquadFilter();
        this.uiBus = this.context.createGain();
        this.musicElement = new Audio();
        this.musicElement.preload = 'auto';
        this.musicElement.loop = false;
        this.musicElement.onended = () => {
          if (!this.hidden && this.desired && this.currentGroup === this.desired) {
            this.startMusic(this.desired, this.nextTrack ?? undefined);
          }
        };
        this.musicSource = this.context.createMediaElementSource(this.musicElement);
        this.musicGain = this.context.createGain();
        this.musicSource.connect(this.musicGain); this.musicGain.connect(this.musicBus);
        this.combatTone.type = 'lowpass';
        this.combatTone.frequency.value = 9500;
        this.combatTone.Q.value = 0.35;
        const limiter = this.context.createDynamicsCompressor();
        limiter.threshold.value = -5; limiter.knee.value = 8; limiter.ratio.value = 6; limiter.attack.value = 0.006; limiter.release.value = 0.16;
        this.musicBus.connect(this.master);
        this.combatBus.connect(this.combatTone); this.combatTone.connect(this.master);
        this.uiBus.connect(this.master);
        this.analyser = this.context.createAnalyser(); this.analyser.fftSize = 256;
        this.master.connect(limiter); limiter.connect(this.analyser); this.analyser.connect(this.context.destination);
        this.applySettings(this.settings);
      }
      const context = this.context;
      const resume = context.resume();
      // Start the HTML media element inside the same user gesture that unlocks audio.
      this.reconcileMusic();
      this.unlocking = (async () => {
        await resume;
        await this.prepare();
        await Promise.all([...this.bytes].map(async ([url, bytes]) => {
          if (this.buffers.has(url)) return;
          try { this.buffers.set(url, await context.decodeAudioData(bytes.slice(0))); }
          catch { this.stateText = '일부 사운드 형식을 읽을 수 없습니다.'; }
        }));
        if (this.disposed) return;
        if (this.buffers.size === preloadedAudioUrls().length) this.stateText = '오디오 준비 완료';
        if (this.hidden) await context.suspend();
        else this.reconcileMusic();
      })().catch(() => { this.stateText = '소리를 켜려면 사운드 버튼을 다시 눌러주세요.'; })
        .finally(() => { this.unlocking = null; });
      return this.unlocking;
    } catch {
      this.stateText = '이 브라우저에서 오디오를 시작할 수 없습니다.';
      return Promise.resolve();
    }
  }

  applySettings(settings: Settings): void {
    this.settings = { ...settings };
    if (!this.context || !this.master || !this.musicBus || !this.combatBus || !this.uiBus) return;
    const now = this.context.currentTime;
    this.master.gain.setTargetAtTime(settings.muted ? 0 : settings.masterVolume, now, AUDIO_CONFIG.volumeFade);
    this.musicBus.gain.setTargetAtTime(settings.musicVolume * (this.dimmed ? AUDIO_CONFIG.pausedMusicGain : 1), now, AUDIO_CONFIG.volumeFade);
    this.combatBus.gain.setTargetAtTime(settings.combatVolume, now, AUDIO_CONFIG.volumeFade);
    this.uiBus.gain.setTargetAtTime(settings.uiVolume, now, AUDIO_CONFIG.volumeFade);
  }
  setScene(id: BgmId | null, dimmed: boolean): void {
    if (this.desired === id && this.dimmed === dimmed) return;
    this.desired = id; this.dimmed = dimmed;
    this.applySettings(this.settings);
    this.reconcileMusic();
  }
  private reconcileMusic(): void {
    const context = this.context, element = this.musicElement, gain = this.musicGain;
    if (!context || !element || !gain || this.hidden || this.disposed) return;
    if (this.desired === this.currentGroup) {
      if (this.desired && element.paused) this.playMusic();
      return;
    }
    window.clearTimeout(this.musicFadeTimer);
    if (!this.currentTrack || element.paused) {
      if (this.desired) this.startMusic(this.desired);
      else this.stopMusic();
      return;
    }
    const next = this.desired;
    gain.gain.cancelScheduledValues(context.currentTime);
    gain.gain.setTargetAtTime(0, context.currentTime, AUDIO_CONFIG.musicFade / 4);
    this.musicFadeTimer = window.setTimeout(() => {
      if (this.hidden || this.disposed) return;
      if (this.desired !== next) { this.reconcileMusic(); return; }
      if (next) this.startMusic(next);
      else this.stopMusic();
    }, AUDIO_CONFIG.musicFade * 1000);
  }

  private chooseMusic(id: BgmId): BgmTrack {
    const tracks: readonly BgmTrack[] = bgm[id].tracks;
    const previous = this.lastMusicUrl.get(id);
    const choices = tracks.length > 1 ? tracks.filter(track => track.url !== previous) : tracks;
    return choices[Math.floor(Math.random() * choices.length)]!;
  }

  private queueNextMusic(id: BgmId): void {
    this.nextMusicElement = null;
    this.nextTrack = null;
    if (bgm[id].tracks.length < 2) return;
    this.nextTrack = this.chooseMusic(id);
    this.nextMusicElement = new Audio(this.nextTrack.url);
    this.nextMusicElement.preload = 'auto';
    this.nextMusicElement.load();
  }

  private playMusic(): void {
    const expectedTrack = this.currentTrack;
    void this.musicElement?.play().catch((error: unknown) => {
      if (error instanceof DOMException && error.name === 'AbortError') return;
      if (!this.hidden && !this.disposed && this.currentTrack === expectedTrack) {
        this.stateText = 'BGM을 재생하려면 사운드 버튼을 다시 눌러주세요.';
      }
    });
  }

  private startMusic(id: BgmId, queued?: BgmTrack): void {
    const context = this.context, element = this.musicElement, gain = this.musicGain;
    if (!context || !element || !gain) return;
    window.clearTimeout(this.musicFadeTimer);
    const track = queued && queued.url !== this.currentTrack?.url ? queued : this.chooseMusic(id);
    this.nextMusicElement = null;
    element.pause();
    element.src = track.url;
    element.load();
    gain.gain.cancelScheduledValues(context.currentTime);
    gain.gain.setValueAtTime(0, context.currentTime);
    gain.gain.setTargetAtTime(bgm[id].gain, context.currentTime, AUDIO_CONFIG.musicFade / 4);
    this.currentGroup = id;
    this.currentTrack = track;
    this.lastMusicUrl.set(id, track.url);
    this.playMusic();
    this.queueNextMusic(id);
  }

  private stopMusic(): void {
    this.musicElement?.pause();
    this.musicElement?.removeAttribute('src');
    this.musicElement?.load();
    this.nextMusicElement = null;
    this.nextTrack = null;
    this.currentGroup = null;
    this.currentTrack = null;
  }
  play = (id: SfxId): boolean => {
    const context = this.context, definition = sfx[id];
    const output = definition.group === 'ui' ? this.uiBus : this.combatBus;
    const groupVolume = definition.group === 'ui' ? this.settings.uiVolume : this.settings.combatVolume;
    if (!context || !output || this.hidden || this.settings.muted || this.settings.masterVolume <= 0 || groupVolume <= 0 || context.state !== 'running') return false;
    if ([...this.voices].filter(voice => voice.id === id).length >= definition.concurrency) return false;
    if (this.voices.size >= AUDIO_CONFIG.maxVoices && definition.priority >= 4) {
      const victim = [...this.voices].sort((a, b) => a.priority - b.priority)[0];
      if (victim && victim.priority < definition.priority) {
        this.voices.delete(victim);
        try { victim.source.stop(); } catch { /* voice already ended */ }
      }
    }
    const cursor = this.variantCursor.get(id) ?? 0;
    const url = definition.urls[cursor % definition.urls.length];
    if (!url) return false;
    const buffer = this.buffers.get(url);
    if (!buffer || !this.gate.allow(id, context.currentTime, this.voices.size)) return false;
    const source = context.createBufferSource(), gain = context.createGain();
    const [lowPitch, highPitch] = definition.pitch;
    source.buffer = buffer;
    source.playbackRate.value = lowPitch + Math.random() * (highPitch - lowPitch);
    gain.gain.value = definition.gain * (1 + (Math.random() * 2 - 1) * definition.volumeVariation);
    source.connect(gain); gain.connect(output);
    const voice: EffectVoice = { source, gain, id, priority: definition.priority };
    this.voices.add(voice); this.variantCursor.set(id, cursor + 1);
    source.onended = () => { this.voices.delete(voice); source.disconnect(); gain.disconnect(); };
    source.start(); this.playedCount++; this.lastSound = definition.label;
    return true;
  };
  setHidden(hidden: boolean): void {
    this.hidden = hidden;
    const context = this.context;
    if (!context) return;
    if (hidden) {
      for (const voice of this.voices) voice.source.stop();
      this.gate.clear();
      window.clearTimeout(this.musicFadeTimer);
      this.musicElement?.pause();
      void context.suspend().catch(() => {});
    } else {
      void context.resume().then(() => { if (!this.hidden) this.reconcileMusic(); }).catch(() => {});
    }
  }
  destroy(): void {
    this.disposed = true;
    window.clearTimeout(this.musicFadeTimer);
    for (const voice of this.voices) voice.source.stop();
    this.stopMusic();
    this.musicSource?.disconnect(); this.musicGain?.disconnect();
    this.voices.clear(); this.bytes.clear(); this.buffers.clear();
    void this.context?.close().catch(() => {});
  }
}
