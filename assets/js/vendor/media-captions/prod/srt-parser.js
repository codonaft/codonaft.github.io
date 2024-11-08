/**
 * Minified by jsDelivr using Terser v5.19.2.
 * Original file: /npm/media-captions@1.0.4/dist/prod/srt-parser.js
 *
 * Do NOT use SRI with dynamically generated files! More information: https://www.jsdelivr.com/using-sri-with-dynamic-files
 */
import{V as VTTParser,a as VTTBlock,b as VTTCue}from"./index.js";const MILLISECOND_SEP_RE=/,/g,TIMESTAMP_SEP="--\x3e";class SRTParser extends VTTParser{parse(e,s){if(""===e)this.c&&(this.l.push(this.c),this.h.onCue?.(this.c),this.c=null),this.e=VTTBlock.None;else if(this.e===VTTBlock.Cue)this.c.text+=(this.c.text?"\n":"")+e;else if(e.includes("--\x3e")){const t=this.q(e,s);t&&(this.c=new VTTCue(t[0],t[1],t[2].join(" ")),this.c.id=this.n,this.e=VTTBlock.Cue)}this.n=e}q(e,s){return super.q(e.replace(MILLISECOND_SEP_RE,"."),s)}}function createSRTParser(){return new SRTParser}export{SRTParser,createSRTParser as default};
//# sourceMappingURL=/sm/0508229bae719594837aecb38c1ed19ced7083a115c33aefcd657124458dd60b.map