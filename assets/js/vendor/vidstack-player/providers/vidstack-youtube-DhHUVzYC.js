import{ak as p,s as y,e as m,i as f,h as g,al as b,I as d,W as k}from"../chunks/vidstack-ClmE_LDk.js";import{T as u}from"../chunks/vidstack-BFul-1yb.js";import{p as v}from"../chunks/vidstack-DB4QmL2O.js";import{E as P}from"../chunks/vidstack-Bi_GX7qv.js";import{resolveYouTubeVideoId as w}from"../chunks/vidstack-DDBvyCKL.js";import"../chunks/vidstack-tiQh4UD3.js";const r={Unstarted:-1,Ended:0,Playing:1,Paused:2,Buffering:3,Cued:5};class T extends P{$$PROVIDER_TYPE="YOUTUBE";scope=p();#e;#a=y("");#o=-1;#d=null;#r=-1;#i=!1;#s=new Map;constructor(e,t){super(e),this.#e=t}language="en";color="red";cookies=!1;get currentSrc(){return this.#d}get type(){return"youtube"}get videoId(){return this.#a()}preconnect(){v(this.getOrigin())}setup(){super.setup(),m(this.#c.bind(this)),this.#e.notify("provider-setup",this)}destroy(){this.#l();const e="provider destroyed";for(const t of this.#s.values())for(const{reject:s}of t)s(e);this.#s.clear()}async play(){return this.#t("playVideo")}#k(e){this.#n("playVideo")?.reject(e)}async pause(){return this.#t("pauseVideo")}#v(e){this.#n("pauseVideo")?.reject(e)}setMuted(e){e?this.#t("mute"):this.#t("unMute")}setCurrentTime(e){this.#t("seekTo",e),this.#e.notify("seeking",e)}setVolume(e){this.#t("setVolume",e*100)}setPlaybackRate(e){this.#t("setPlaybackRate",e)}async loadSource(e){if(!f(e.src)){this.#d=null,this.#a.set("");return}const t=w(e.src);this.#a.set(t??""),this.#d=e}getOrigin(){return this.cookies?"https://www.youtube.com":"https://www.youtube-nocookie.com"}#c(){this.#l();const e=this.#a();if(!e){this.src.set("");return}this.src.set(`${this.getOrigin()}/embed/${e}`),this.#e.notify("load-start")}buildParams(){const{keyDisabled:e}=this.#e.$props,{muted:t,playsInline:s,nativeControls:a}=this.#e.$state,i=a();return{autoplay:0,cc_lang_pref:this.language,cc_load_policy:i?1:void 0,color:this.color,controls:i?1:0,disablekb:!i||e()?1:0,enablejsapi:1,fs:1,hl:this.language,iv_load_policy:i?1:3,mute:t()?1:0,playsinline:s()?1:0}}#t(e,t){let s=g(),a=this.#s.get(e);return a||this.#s.set(e,a=[]),a.push(s),this.postMessage({event:"command",func:e,args:t?[t]:void 0}),s.promise}onLoad(){window.setTimeout(()=>this.postMessage({event:"listening"}),100)}#p(e){this.#e.notify("loaded-metadata"),this.#e.notify("loaded-data"),this.#e.delegate.ready(void 0,e)}#y(e){this.#n("pauseVideo")?.resolve(),this.#e.notify("pause",void 0,e)}#m(e,t){const{duration:s,realCurrentTime:a}=this.#e.$state,i=this.#o===r.Ended,o=i?s():e;this.#e.notify("time-change",o,t),!i&&Math.abs(o-a())>1&&this.#e.notify("seeking",o,t)}#u(e,t,s){const a={buffered:new u(0,e),seekable:t};this.#e.notify("progress",a,s);const{seeking:i,realCurrentTime:o}=this.#e.$state;i()&&e>o()&&this.#h(s)}#h(e){const{paused:t,realCurrentTime:s}=this.#e.$state;window.clearTimeout(this.#r),this.#r=window.setTimeout(()=>{this.#e.notify("seeked",s(),e),this.#r=-1},t()?100:0)}#f(e){const{seeking:t}=this.#e.$state;t()&&this.#h(e),this.#e.notify("pause",void 0,e),this.#e.notify("end",void 0,e)}#g(e,t){const{paused:s,seeking:a}=this.#e.$state,i=e===r.Playing,o=e===r.Buffering,n=this.#b("playVideo"),h=s()&&(o||i);if(o&&this.#e.notify("waiting",void 0,t),a()&&i&&this.#h(t),this.#i&&i){this.pause(),this.#i=!1,this.setMuted(this.#e.$state.muted());return}if(!n&&h){this.#i=!0,this.setMuted(!0);return}switch(h&&(this.#n("playVideo")?.resolve(),this.#e.notify("play",void 0,t)),e){case r.Cued:this.#p(t);break;case r.Playing:this.#e.notify("playing",void 0,t);break;case r.Paused:this.#y(t);break;case r.Ended:this.#f(t);break}this.#o=e}onMessage({info:e},t){if(!e)return;const{title:s,intrinsicDuration:a,playbackRate:i}=this.#e.$state;if(b(e.videoData)&&e.videoData.title!==s()&&this.#e.notify("title-change",e.videoData.title,t),d(e.duration)&&e.duration!==a()){if(d(e.videoLoadedFraction)){const o=e.progressState?.loaded??e.videoLoadedFraction*e.duration,n=new u(0,e.duration);this.#u(o,n,t)}this.#e.notify("duration-change",e.duration,t)}if(d(e.playbackRate)&&e.playbackRate!==i()&&this.#e.notify("rate-change",e.playbackRate,t),e.progressState){const{current:o,seekableStart:n,seekableEnd:h,loaded:c,duration:l}=e.progressState;this.#m(o,t),this.#u(c,new u(n,h),t),l!==a()&&this.#e.notify("duration-change",l,t)}if(d(e.volume)&&k(e.muted)&&!this.#i){const o={muted:e.muted,volume:e.volume/100};this.#e.notify("volume-change",o,t)}d(e.playerState)&&e.playerState!==this.#o&&this.#g(e.playerState,t)}#l(){this.#o=-1,this.#r=-1,this.#i=!1}#n(e){return this.#s.get(e)?.shift()}#b(e){return!!this.#s.get(e)?.length}}export{T as YouTubeProvider};
