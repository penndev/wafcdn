import{z as C}from"./index-271749e0.js";var v={exports:{}};(function(o,l){(function(s){o.exports=s()})(function(s){var b=["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"];function h(f,i){var r=f[0],t=f[1],n=f[2],e=f[3];r+=(t&n|~t&e)+i[0]-680876936|0,r=(r<<7|r>>>25)+t|0,e+=(r&t|~r&n)+i[1]-389564586|0,e=(e<<12|e>>>20)+r|0,n+=(e&r|~e&t)+i[2]+606105819|0,n=(n<<17|n>>>15)+e|0,t+=(n&e|~n&r)+i[3]-1044525330|0,t=(t<<22|t>>>10)+n|0,r+=(t&n|~t&e)+i[4]-176418897|0,r=(r<<7|r>>>25)+t|0,e+=(r&t|~r&n)+i[5]+1200080426|0,e=(e<<12|e>>>20)+r|0,n+=(e&r|~e&t)+i[6]-1473231341|0,n=(n<<17|n>>>15)+e|0,t+=(n&e|~n&r)+i[7]-45705983|0,t=(t<<22|t>>>10)+n|0,r+=(t&n|~t&e)+i[8]+1770035416|0,r=(r<<7|r>>>25)+t|0,e+=(r&t|~r&n)+i[9]-1958414417|0,e=(e<<12|e>>>20)+r|0,n+=(e&r|~e&t)+i[10]-42063|0,n=(n<<17|n>>>15)+e|0,t+=(n&e|~n&r)+i[11]-1990404162|0,t=(t<<22|t>>>10)+n|0,r+=(t&n|~t&e)+i[12]+1804603682|0,r=(r<<7|r>>>25)+t|0,e+=(r&t|~r&n)+i[13]-40341101|0,e=(e<<12|e>>>20)+r|0,n+=(e&r|~e&t)+i[14]-1502002290|0,n=(n<<17|n>>>15)+e|0,t+=(n&e|~n&r)+i[15]+1236535329|0,t=(t<<22|t>>>10)+n|0,r+=(t&e|n&~e)+i[1]-165796510|0,r=(r<<5|r>>>27)+t|0,e+=(r&n|t&~n)+i[6]-1069501632|0,e=(e<<9|e>>>23)+r|0,n+=(e&t|r&~t)+i[11]+643717713|0,n=(n<<14|n>>>18)+e|0,t+=(n&r|e&~r)+i[0]-373897302|0,t=(t<<20|t>>>12)+n|0,r+=(t&e|n&~e)+i[5]-701558691|0,r=(r<<5|r>>>27)+t|0,e+=(r&n|t&~n)+i[10]+38016083|0,e=(e<<9|e>>>23)+r|0,n+=(e&t|r&~t)+i[15]-660478335|0,n=(n<<14|n>>>18)+e|0,t+=(n&r|e&~r)+i[4]-405537848|0,t=(t<<20|t>>>12)+n|0,r+=(t&e|n&~e)+i[9]+568446438|0,r=(r<<5|r>>>27)+t|0,e+=(r&n|t&~n)+i[14]-1019803690|0,e=(e<<9|e>>>23)+r|0,n+=(e&t|r&~t)+i[3]-187363961|0,n=(n<<14|n>>>18)+e|0,t+=(n&r|e&~r)+i[8]+1163531501|0,t=(t<<20|t>>>12)+n|0,r+=(t&e|n&~e)+i[13]-1444681467|0,r=(r<<5|r>>>27)+t|0,e+=(r&n|t&~n)+i[2]-51403784|0,e=(e<<9|e>>>23)+r|0,n+=(e&t|r&~t)+i[7]+1735328473|0,n=(n<<14|n>>>18)+e|0,t+=(n&r|e&~r)+i[12]-1926607734|0,t=(t<<20|t>>>12)+n|0,r+=(t^n^e)+i[5]-378558|0,r=(r<<4|r>>>28)+t|0,e+=(r^t^n)+i[8]-2022574463|0,e=(e<<11|e>>>21)+r|0,n+=(e^r^t)+i[11]+1839030562|0,n=(n<<16|n>>>16)+e|0,t+=(n^e^r)+i[14]-35309556|0,t=(t<<23|t>>>9)+n|0,r+=(t^n^e)+i[1]-1530992060|0,r=(r<<4|r>>>28)+t|0,e+=(r^t^n)+i[4]+1272893353|0,e=(e<<11|e>>>21)+r|0,n+=(e^r^t)+i[7]-155497632|0,n=(n<<16|n>>>16)+e|0,t+=(n^e^r)+i[10]-1094730640|0,t=(t<<23|t>>>9)+n|0,r+=(t^n^e)+i[13]+681279174|0,r=(r<<4|r>>>28)+t|0,e+=(r^t^n)+i[0]-358537222|0,e=(e<<11|e>>>21)+r|0,n+=(e^r^t)+i[3]-722521979|0,n=(n<<16|n>>>16)+e|0,t+=(n^e^r)+i[6]+76029189|0,t=(t<<23|t>>>9)+n|0,r+=(t^n^e)+i[9]-640364487|0,r=(r<<4|r>>>28)+t|0,e+=(r^t^n)+i[12]-421815835|0,e=(e<<11|e>>>21)+r|0,n+=(e^r^t)+i[15]+530742520|0,n=(n<<16|n>>>16)+e|0,t+=(n^e^r)+i[2]-995338651|0,t=(t<<23|t>>>9)+n|0,r+=(n^(t|~e))+i[0]-198630844|0,r=(r<<6|r>>>26)+t|0,e+=(t^(r|~n))+i[7]+1126891415|0,e=(e<<10|e>>>22)+r|0,n+=(r^(e|~t))+i[14]-1416354905|0,n=(n<<15|n>>>17)+e|0,t+=(e^(n|~r))+i[5]-57434055|0,t=(t<<21|t>>>11)+n|0,r+=(n^(t|~e))+i[12]+1700485571|0,r=(r<<6|r>>>26)+t|0,e+=(t^(r|~n))+i[3]-1894986606|0,e=(e<<10|e>>>22)+r|0,n+=(r^(e|~t))+i[10]-1051523|0,n=(n<<15|n>>>17)+e|0,t+=(e^(n|~r))+i[1]-2054922799|0,t=(t<<21|t>>>11)+n|0,r+=(n^(t|~e))+i[8]+1873313359|0,r=(r<<6|r>>>26)+t|0,e+=(t^(r|~n))+i[15]-30611744|0,e=(e<<10|e>>>22)+r|0,n+=(r^(e|~t))+i[6]-1560198380|0,n=(n<<15|n>>>17)+e|0,t+=(e^(n|~r))+i[13]+1309151649|0,t=(t<<21|t>>>11)+n|0,r+=(n^(t|~e))+i[4]-145523070|0,r=(r<<6|r>>>26)+t|0,e+=(t^(r|~n))+i[11]-1120210379|0,e=(e<<10|e>>>22)+r|0,n+=(r^(e|~t))+i[2]+718787259|0,n=(n<<15|n>>>17)+e|0,t+=(e^(n|~r))+i[9]-343485551|0,t=(t<<21|t>>>11)+n|0,f[0]=r+f[0]|0,f[1]=t+f[1]|0,f[2]=n+f[2]|0,f[3]=e+f[3]|0}function B(f){var i=[],r;for(r=0;r<64;r+=4)i[r>>2]=f.charCodeAt(r)+(f.charCodeAt(r+1)<<8)+(f.charCodeAt(r+2)<<16)+(f.charCodeAt(r+3)<<24);return i}function _(f){var i=[],r;for(r=0;r<64;r+=4)i[r>>2]=f[r]+(f[r+1]<<8)+(f[r+2]<<16)+(f[r+3]<<24);return i}function A(f){var i=f.length,r=[1732584193,-271733879,-1732584194,271733878],t,n,e,u,p,d;for(t=64;t<=i;t+=64)h(r,B(f.substring(t-64,t)));for(f=f.substring(t-64),n=f.length,e=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],t=0;t<n;t+=1)e[t>>2]|=f.charCodeAt(t)<<(t%4<<3);if(e[t>>2]|=128<<(t%4<<3),t>55)for(h(r,e),t=0;t<16;t+=1)e[t]=0;return u=i*8,u=u.toString(16).match(/(.*?)(.{0,8})$/),p=parseInt(u[2],16),d=parseInt(u[1],16)||0,e[14]=p,e[15]=d,h(r,e),r}function y(f){var i=f.length,r=[1732584193,-271733879,-1732584194,271733878],t,n,e,u,p,d;for(t=64;t<=i;t+=64)h(r,_(f.subarray(t-64,t)));for(f=t-64<i?f.subarray(t-64):new Uint8Array(0),n=f.length,e=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],t=0;t<n;t+=1)e[t>>2]|=f[t]<<(t%4<<3);if(e[t>>2]|=128<<(t%4<<3),t>55)for(h(r,e),t=0;t<16;t+=1)e[t]=0;return u=i*8,u=u.toString(16).match(/(.*?)(.{0,8})$/),p=parseInt(u[2],16),d=parseInt(u[1],16)||0,e[14]=p,e[15]=d,h(r,e),r}function S(f){var i="",r;for(r=0;r<4;r+=1)i+=b[f>>r*8+4&15]+b[f>>r*8&15];return i}function g(f){var i;for(i=0;i<f.length;i+=1)f[i]=S(f[i]);return f.join("")}g(A("hello")),typeof ArrayBuffer<"u"&&!ArrayBuffer.prototype.slice&&function(){function f(i,r){return i=i|0||0,i<0?Math.max(i+r,0):Math.min(i,r)}ArrayBuffer.prototype.slice=function(i,r){var t=this.byteLength,n=f(i,t),e=t,u,p,d,F;return r!==s&&(e=f(r,t)),n>e?new ArrayBuffer(0):(u=e-n,p=new ArrayBuffer(u),d=new Uint8Array(p),F=new Uint8Array(this,n,u),d.set(F),p)}}();function c(f){return/[\u0080-\uFFFF]/.test(f)&&(f=unescape(encodeURIComponent(f))),f}function w(f,i){var r=f.length,t=new ArrayBuffer(r),n=new Uint8Array(t),e;for(e=0;e<r;e+=1)n[e]=f.charCodeAt(e);return i?n:t}function M(f){return String.fromCharCode.apply(null,new Uint8Array(f))}function U(f,i,r){var t=new Uint8Array(f.byteLength+i.byteLength);return t.set(new Uint8Array(f)),t.set(new Uint8Array(i),f.byteLength),r?t:t.buffer}function m(f){var i=[],r=f.length,t;for(t=0;t<r-1;t+=2)i.push(parseInt(f.substr(t,2),16));return String.fromCharCode.apply(String,i)}function a(){this.reset()}return a.prototype.append=function(f){return this.appendBinary(c(f)),this},a.prototype.appendBinary=function(f){this._buff+=f,this._length+=f.length;var i=this._buff.length,r;for(r=64;r<=i;r+=64)h(this._hash,B(this._buff.substring(r-64,r)));return this._buff=this._buff.substring(r-64),this},a.prototype.end=function(f){var i=this._buff,r=i.length,t,n=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],e;for(t=0;t<r;t+=1)n[t>>2]|=i.charCodeAt(t)<<(t%4<<3);return this._finish(n,r),e=g(this._hash),f&&(e=m(e)),this.reset(),e},a.prototype.reset=function(){return this._buff="",this._length=0,this._hash=[1732584193,-271733879,-1732584194,271733878],this},a.prototype.getState=function(){return{buff:this._buff,length:this._length,hash:this._hash.slice()}},a.prototype.setState=function(f){return this._buff=f.buff,this._length=f.length,this._hash=f.hash,this},a.prototype.destroy=function(){delete this._hash,delete this._buff,delete this._length},a.prototype._finish=function(f,i){var r=i,t,n,e;if(f[r>>2]|=128<<(r%4<<3),r>55)for(h(this._hash,f),r=0;r<16;r+=1)f[r]=0;t=this._length*8,t=t.toString(16).match(/(.*?)(.{0,8})$/),n=parseInt(t[2],16),e=parseInt(t[1],16)||0,f[14]=n,f[15]=e,h(this._hash,f)},a.hash=function(f,i){return a.hashBinary(c(f),i)},a.hashBinary=function(f,i){var r=A(f),t=g(r);return i?m(t):t},a.ArrayBuffer=function(){this.reset()},a.ArrayBuffer.prototype.append=function(f){var i=U(this._buff.buffer,f,!0),r=i.length,t;for(this._length+=f.byteLength,t=64;t<=r;t+=64)h(this._hash,_(i.subarray(t-64,t)));return this._buff=t-64<r?new Uint8Array(i.buffer.slice(t-64)):new Uint8Array(0),this},a.ArrayBuffer.prototype.end=function(f){var i=this._buff,r=i.length,t=[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],n,e;for(n=0;n<r;n+=1)t[n>>2]|=i[n]<<(n%4<<3);return this._finish(t,r),e=g(this._hash),f&&(e=m(e)),this.reset(),e},a.ArrayBuffer.prototype.reset=function(){return this._buff=new Uint8Array(0),this._length=0,this._hash=[1732584193,-271733879,-1732584194,271733878],this},a.ArrayBuffer.prototype.getState=function(){var f=a.prototype.getState.call(this);return f.buff=M(f.buff),f},a.ArrayBuffer.prototype.setState=function(f){return f.buff=w(f.buff,!0),a.prototype.setState.call(this,f)},a.ArrayBuffer.prototype.destroy=a.prototype.destroy,a.ArrayBuffer.prototype._finish=a.prototype._finish,a.ArrayBuffer.hash=function(f,i){var r=y(new Uint8Array(f)),t=g(r);return i?m(t):t},a})})(v);var x=v.exports;const z=C(x);function D(o,l){return new Promise((s,b)=>{const B=Math.ceil(o.size/10485760),_=File.prototype.slice,A=new z.ArrayBuffer;let y=0;const S=new FileReader;S.onload=function(c){A.append(c.target.result),y++,y<B?(typeof l=="function"&&l(y/B),g()):s(A.end())},S.onerror=function(c){b(c)};function g(){const c=y*10485760,w=c+10485760>=o.size?o.size:c+10485760;S.readAsArrayBuffer(_.call(o,c,w))}g()})}const T=o=>{if(typeof o!="number"||isNaN(o))throw new Error("Input must be a valid number");return o>=1099511627776?(o/1099511627776).toFixed(2)+"TB":o>=1073741824?(o/1073741824).toFixed(2)+"GB":o>=1048576?(o/1048576).toFixed(2)+"MB":o>=1024?(o/1024).toFixed(2)+"KB":o+"Byte"},G=o=>o>=3600?(o/3600).toFixed(2)+"小时":o>=60?(o/60).toFixed(2)+"分钟":o+"秒",K=(o,l)=>{const s=l&&l>0?new Date(l*1e3):new Date,b=s.getFullYear().toString(),h=String(s.getMonth()+1).padStart(2,"0"),B=String(s.getDate()).padStart(2,"0"),_=String(s.getHours()).padStart(2,"0"),A=String(s.getMinutes()).padStart(2,"0"),y=String(s.getSeconds()).padStart(2,"0");return o.replace("Y",b).replace("m",h).replace("d",B).replace("H",_).replace("i",A).replace("s",y)};export{D as M,K as d,T as f,G as t};