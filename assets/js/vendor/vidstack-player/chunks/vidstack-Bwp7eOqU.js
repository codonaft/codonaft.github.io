import{a as n,b as l,d as c}from"./vidstack-tiQh4UD3.js";import{l as p}from"./vidstack-DB4QmL2O.js";import{a as g,b as d,i,d as h,e as m,f as y,c as C,j as f}from"./vidstack-fD9KBeHD.js";import{p as w}from"./vidstack-ClmE_LDk.js";class E{name="google-cast";target;#e;get cast(){return g()}mediaType(){return"video"}canPlay(e){return n&&!l&&c(e)}async prompt(e){let t,a,r;try{t=await this.#r(e),this.#e||(this.#e=new cast.framework.RemotePlayer,new cast.framework.RemotePlayerController(this.#e)),a=e.player.createEvent("google-cast-prompt-open",{trigger:t}),e.player.dispatchEvent(a),this.#t(e,"connecting",a),await this.#o(w(e.$props.googleCast)),e.$state.remotePlaybackInfo.set({deviceName:d()?.getCastDevice().friendlyName}),i()&&this.#t(e,"connected",a)}catch(o){const s=o instanceof Error?o:this.#a((o+"").toUpperCase(),"Prompt failed.");throw r=e.player.createEvent("google-cast-prompt-error",{detail:s,trigger:a??t,cancelable:!0}),e.player.dispatch(r),this.#t(e,i()?"connected":"disconnected",r),s}finally{e.player.dispatch("google-cast-prompt-close",{trigger:r??a??t})}}async load(e){if(!this.#e)throw Error("[vidstack] google cast player was not initialized");return new(await import("../providers/vidstack-google-cast-DtsIF5O4.js")).GoogleCastProvider(this.#e,e)}async#r(e){if(h())return;const t=e.player.createEvent("google-cast-load-start");e.player.dispatch(t),await p(m()),await customElements.whenDefined("google-cast-launcher");const a=e.player.createEvent("google-cast-loaded",{trigger:t});if(e.player.dispatch(a),!y())throw this.#a("CAST_NOT_AVAILABLE","Google Cast not available on this platform.");return a}async#o(e){this.#s(e);const t=await this.cast.requestSession();if(t)throw this.#a(t.toUpperCase(),C(t))}#s(e){this.cast?.setOptions({...f(),...e})}#t(e,t,a){const r={type:"google-cast",state:t};e.notify("remote-playback-change",r,a)}#a(e,t){const a=Error(t);return a.code=e,a}}export{E as GoogleCastLoader};