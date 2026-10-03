import { AUDIO_CONFIG, preloadedAudioUrls, bgm, sfx } from '../data/audio';
import type { BgmId, BgmTrack, SfxDefinition, SfxId } from '../data/audio';
import type { Settings } from '../state/MetaState';
import { SoundGate } from './AudioPolicy';

export interface AudioCueContext {
  readonly weaponId?: string;
  readonly stage?: string;
  readonly behavior?: string;
  readonly attackId?: string | number;
  readonly hopIndex?: number;
  /** Optional delay in combat seconds; advanceCombat() owns this clock. */
  readonly delay?: number;
}

interface EffectVoice {
  source: AudioBufferSourceNode; gain: GainNode; id: SfxId; priority: number;
  protected: boolean; group: 'combat' | 'ui'; startedAt: number; order: number;
}
interface ScheduledCue { id: SfxId; at: number; context: AudioCueContext; order: number }
interface AmbientVoice { source: AudioBufferSourceNode; gain: GainNode; id: SfxId }

/** Browser output adapter. The simulation only emits domain events and knows no audio APIs. */
export class AudioManager {
  onMusicStateChange: (() => void) | null = null;
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
  private readonly lastEffectUrl = new Map<SfxId, string>();
  private readonly scheduled: ScheduledCue[] = [];
  private readonly chainHops = new Map<string | number, number>();
  private combatTime = 0;
  private voiceOrder = 0;
  private desiredAmbience: SfxId | null = null;
  private ambience: AmbientVoice | null = null;
  private readonly lastMusicUrl = new Map<BgmId, string>();
  private readonly gate = new SoundGate();
  private readonly tabId = Math.random().toString(36).slice(2);
  private readonly tabChannel = typeof window === 'undefined' || typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel('seoul-hero-bgm');
  private silencedByOtherTab = false;
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

  constructor(private settings: Settings) {
    if (this.tabChannel) this.tabChannel.onmessage = (event: MessageEvent<{ type: string; sender: string }>) => {
      if (event.data?.type !== 'claim' || event.data.sender === this.tabId) return;
      this.silencedByOtherTab = true;
      window.clearTimeout(this.musicFadeTimer);
      this.musicElement?.pause();
      this.stopAmbience();
    };
  }
  get status(): string { return this.stateText; }
  get unlocked(): boolean { return this.context?.state === 'running' && this.buffers.size > 0; }
  get audible(): boolean { return !this.settings.muted && this.settings.masterVolume > 0 && this.settings.musicVolume > 0 && !this.hidden && !this.silencedByOtherTab && (!this.context || this.context.state === 'running') && !!this.musicElement && !this.musicElement.paused; }
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

  /** Try audible title music immediately where the browser permits autoplay. */
  tryAutoplayTitle(): Promise<void> {
    if (this.disposed || this.hidden || this.settings.muted || this.musicElement || this.desired !== 'menu') return Promise.resolve();
    const track = this.chooseMusic('menu');
    const element = new Audio(track.url);
    this.watchMusicElement(element);
    element.preload = 'auto';
    element.volume = Math.max(0, Math.min(1, this.settings.masterVolume * this.settings.musicVolume * bgm.menu.gain));
    element.onended = () => {
      if (this.desired === 'menu' && !this.hidden && !this.silencedByOtherTab) this.startUnroutedMenuTrack(element);
    };
    this.musicElement = element;
    this.currentGroup = 'menu';
    this.currentTrack = track;
    this.lastMusicUrl.set('menu', track.url);
    return element.play().then(() => { if (this.musicElement === element) this.claimOutput(); })
      .catch(() => { /* The first touch retries through unlock(). */ });
  }

  private startUnroutedMenuTrack(element: HTMLAudioElement): void {
    const track = this.chooseMusic('menu');
    element.src = track.url;
    this.currentTrack = track;
    this.lastMusicUrl.set('menu', track.url);
    void element.play().catch(() => {});
  }

  private watchMusicElement(element: HTMLAudioElement): void {
    element.addEventListener('playing', () => this.onMusicStateChange?.());
    element.addEventListener('pause', () => this.onMusicStateChange?.());
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
        if (!this.musicElement) {
          this.musicElement = new Audio();
          this.watchMusicElement(this.musicElement);
        }
        this.musicElement.preload = 'auto';
        this.musicElement.loop = false;
        this.musicElement.volume = 1;
        this.musicElement.onended = () => {
          if (!this.hidden && !this.silencedByOtherTab && this.desired && this.currentGroup === this.desired) {
            this.startMusic(this.desired, this.nextTrack ?? undefined);
          }
        };
        this.musicSource = this.context.createMediaElementSource(this.musicElement);
        this.musicGain = this.context.createGain();
        this.musicGain.gain.value = this.currentGroup ? bgm[this.currentGroup].gain : 1;
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
        else { this.reconcileMusic(); this.reconcileAmbience(); }
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
    if (!this.context || !this.master || !this.musicBus || !this.combatBus || !this.uiBus) {
      if (this.musicElement) this.musicElement.volume = settings.muted ? 0 : Math.max(0, Math.min(1, settings.masterVolume * settings.musicVolume * bgm[this.currentGroup ?? 'menu'].gain));
      return;
    }
    const now = this.context.currentTime;
    this.master.gain.setTargetAtTime(settings.masterVolume, now, AUDIO_CONFIG.volumeFade);
    this.musicBus.gain.setTargetAtTime((settings.muted ? 0 : settings.musicVolume) * (this.dimmed ? AUDIO_CONFIG.pausedMusicGain : 1), now, AUDIO_CONFIG.volumeFade);
    this.combatBus.gain.setTargetAtTime(settings.combatVolume, now, AUDIO_CONFIG.volumeFade);
    this.uiBus.gain.setTargetAtTime(settings.uiVolume, now, AUDIO_CONFIG.volumeFade);
    this.reconcileAmbience();
  }
  setScene(id: BgmId | null, dimmed: boolean): void {
    if (this.desired === id && this.dimmed === dimmed) return;
    this.desired = id; this.dimmed = dimmed;
    if (id !== 'combat') this.stopCombat();
    if (id === 'combat' || id === null) this.setAmbience(null);
    if (!this.context && this.musicElement && id !== this.currentGroup) this.stopMusic();
    this.applySettings(this.settings);
    this.reconcileMusic();
    this.reconcileAmbience();
  }
  /** Only the tab receiving the latest user gesture owns audible BGM. */
  claimOutput(): void {
    if (this.hidden || this.disposed) return;
    this.silencedByOtherTab = false;
    this.tabChannel?.postMessage({ type: 'claim', sender: this.tabId });
    if (!this.context && this.musicElement && this.desired === this.currentGroup && this.musicElement.paused) this.playMusic();
    this.reconcileMusic();
    this.reconcileAmbience();
  }
  private reconcileMusic(): void {
    const context = this.context, element = this.musicElement, gain = this.musicGain;
    if (!context || !element || !gain || this.hidden || this.disposed || this.silencedByOtherTab) return;
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
      if (this.hidden || this.disposed || this.silencedByOtherTab) return;
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
    if (this.silencedByOtherTab) return;
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
  private chooseEffect(id: SfxId): { url: string; buffer: AudioBuffer } | null {
    const urls = sfx[id].urls.filter(url => this.buffers.has(url));
    const previous = this.lastEffectUrl.get(id);
    const choices = urls.length > 1 ? urls.filter(url => url !== previous) : urls;
    const url = choices[Math.floor(Math.random() * choices.length)];
    const buffer = url ? this.buffers.get(url) : undefined;
    return url && buffer ? { url, buffer } : null;
  }

  private stopVoice(voice: EffectVoice): void {
    this.voices.delete(voice);
    try { voice.source.stop(); } catch { /* voice already ended */ }
  }

  /** Keeps one lobby loop on the music bus, with the existing music settings. */
  setAmbience(id: SfxId | null): void {
    if (id && (sfx[id].group !== 'ambience' || !sfx[id].loop)) return;
    this.desiredAmbience = id;
    this.reconcileAmbience();
  }

  private stopAmbience(): void {
    const voice = this.ambience;
    this.ambience = null;
    if (!voice) return;
    try { voice.source.stop(); } catch { /* loop already stopped */ }
  }

  private reconcileAmbience(): void {
    const context = this.context, output = this.musicBus, id = this.desiredAmbience;
    if (!context || !output || !id || this.disposed || this.hidden || this.silencedByOtherTab || this.settings.muted || this.settings.masterVolume <= 0 || this.settings.musicVolume <= 0 || context.state !== 'running') {
      this.stopAmbience(); return;
    }
    if (this.ambience?.id === id) return;
    this.stopAmbience();
    const variant = this.chooseEffect(id);
    if (!variant) return;
    const source = context.createBufferSource(), gain = context.createGain();
    source.buffer = variant.buffer; source.loop = true;
    gain.gain.value = sfx[id].gain;
    source.connect(gain); gain.connect(output);
    const voice: AmbientVoice = { source, gain, id };
    this.ambience = voice;
    source.onended = () => {
      if (this.ambience === voice) this.ambience = null;
      source.disconnect(); gain.disconnect();
    };
    source.start(); this.lastEffectUrl.set(id, variant.url);
  }

  /** Schedule presentation audio without adding a wall-clock timer to combat. */
  schedule(id: SfxId, delay: number, context: AudioCueContext = {}): boolean {
    if (this.disposed || this.hidden || sfx[id].group !== 'combat' || !Number.isFinite(delay)) return false;
    const payload = { ...context, delay: undefined };
    if (delay <= 0) return this.play(id, payload);
    this.scheduled.push({ id, at: this.combatTime + delay, context: payload, order: this.voiceOrder++ });
    return true;
  }

  advanceCombat(dt: number): void {
    if (this.disposed || this.hidden || !Number.isFinite(dt) || dt <= 0) return;
    this.combatTime += dt;
    const due = this.scheduled.filter(cue => cue.at <= this.combatTime).sort((a, b) => a.at - b.at || a.order - b.order);
    for (let i = this.scheduled.length - 1; i >= 0; i--) {
      if (this.scheduled[i]!.at <= this.combatTime) this.scheduled.splice(i, 1);
    }
    for (const cue of due) this.play(cue.id, cue.context);
  }

  /** Wave cleanup cancels delayed attacks and combat tails, while UI cues remain. */
  stopCombat(): void {
    this.scheduled.length = 0; this.chainHops.clear(); this.combatTime = 0;
    for (const voice of this.voices) if (voice.group === 'combat') this.stopVoice(voice);
    this.gate.clear('combat');
  }

  play = (id: SfxId, cueContext: AudioCueContext = {}): boolean => {
    const context = this.context, definition: SfxDefinition = sfx[id];
    if (definition.group === 'ambience') {
      this.setAmbience(id); return this.ambience?.id === id;
    }
    if (definition.group === 'combat' && cueContext.delay && cueContext.delay > 0) return this.schedule(id, cueContext.delay, cueContext);
    const output = definition.group === 'ui' ? this.uiBus : this.combatBus;
    const groupVolume = definition.group === 'ui' ? this.settings.uiVolume : this.settings.combatVolume;
    if (!context || !output || this.disposed || this.hidden || this.settings.masterVolume <= 0 || groupVolume <= 0 || context.state !== 'running') return false;
    if ([...this.voices].filter(voice => voice.id === id).length >= definition.concurrency) return false;
    if (id === 'chainHop') {
      if (cueContext.hopIndex !== undefined && (cueContext.hopIndex <= 0 || cueContext.hopIndex > AUDIO_CONFIG.chainHopMaxPerAttack)) return false;
      if (cueContext.attackId !== undefined && (this.chainHops.get(cueContext.attackId) ?? 0) >= AUDIO_CONFIG.chainHopMaxPerAttack) return false;
    }
    const variant = this.chooseEffect(id);
    if (!variant) return false;
    const normalCount = [...this.voices].filter(voice => !voice.protected).length;
    const constrainedNormal = !definition.protected && normalCount >= AUDIO_CONFIG.normalVoices;
    let victim: EffectVoice | undefined;
    if (constrainedNormal || this.voices.size >= AUDIO_CONFIG.maxVoices) {
      victim = [...this.voices]
        .filter(voice => !voice.protected && voice.priority < definition.priority)
        .sort((a, b) => a.priority - b.priority || a.startedAt - b.startedAt || a.order - b.order)[0];
      if (!victim) return false;
    }
    const activeCount = this.voices.size - (victim ? 1 : 0);
    const nextNormalCount = normalCount - (victim && !victim.protected ? 1 : 0);
    if (!this.gate.allow(id, context.currentTime, activeCount, nextNormalCount)) return false;
    if (victim) this.stopVoice(victim);
    const source = context.createBufferSource(), gain = context.createGain();
    const [lowPitch, highPitch] = definition.pitch;
    source.buffer = variant.buffer;
    source.playbackRate.value = lowPitch + Math.random() * (highPitch - lowPitch);
    const attenuation = definition.protected ? 1 : 1 / Math.sqrt(1 + activeCount * AUDIO_CONFIG.busyAttenuation);
    gain.gain.value = definition.gain * attenuation * (1 + (Math.random() * 2 - 1) * definition.volumeVariation);
    source.connect(gain); gain.connect(output);
    const voice: EffectVoice = { source, gain, id, priority: definition.priority, protected: definition.protected,
      group: definition.group, startedAt: context.currentTime, order: this.voiceOrder++ };
    this.voices.add(voice); this.lastEffectUrl.set(id, variant.url);
    source.onended = () => { this.voices.delete(voice); source.disconnect(); gain.disconnect(); };
    source.start(); this.playedCount++; this.lastSound = definition.label;
    if (id === 'chainHop' && cueContext.attackId !== undefined) {
      if (this.chainHops.size >= 256 && !this.chainHops.has(cueContext.attackId)) this.chainHops.delete(this.chainHops.keys().next().value!);
      this.chainHops.set(cueContext.attackId, (this.chainHops.get(cueContext.attackId) ?? 0) + 1);
    }
    return true;
  };
  setHidden(hidden: boolean): void {
    this.hidden = hidden;
    const context = this.context;
    if (hidden) {
      this.stopCombat();
      for (const voice of this.voices) this.stopVoice(voice);
      this.stopAmbience();
      this.gate.clear();
      window.clearTimeout(this.musicFadeTimer);
      this.musicElement?.pause();
      void context?.suspend().catch(() => {});
    } else {
      if (!context) {
        if (!this.settings.muted && !this.silencedByOtherTab && this.desired === this.currentGroup) this.playMusic();
        return;
      }
      void context.resume().then(() => { if (!this.hidden) { this.reconcileMusic(); this.reconcileAmbience(); } }).catch(() => {});
    }
  }
  destroy(): void {
    this.disposed = true;
    window.clearTimeout(this.musicFadeTimer);
    this.stopCombat();
    for (const voice of this.voices) this.stopVoice(voice);
    this.stopAmbience();
    this.stopMusic();
    this.tabChannel?.close();
    this.musicSource?.disconnect(); this.musicGain?.disconnect();
    this.voices.clear(); this.bytes.clear(); this.buffers.clear();
    void this.context?.close().catch(() => {});
  }
}
