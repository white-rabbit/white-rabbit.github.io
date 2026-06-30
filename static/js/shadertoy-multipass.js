// static/js/shadertoy-multipass.js
//
// Shadertoy-style multipass WebGL2 engine, driven by a `shader.json`
// config file in the shader directory.
//
// Shaders use the standard Shadertoy entry point:
//   void mainImage(out vec4 fragColor, in vec2 fragCoord)
// The engine provides: iTime (seconds), iFrame (int), iResolution (vec3),
// iMouse (vec4) and iChannel0..3 (sampler2D).
//
// Config schema (`shader.json`):
// {
//   "passes": [
//     {
//       "name": "bufferA",                  // arbitrary identifier
//       "file": "bufferA.glsl",             // GLSL source (relative to config)
//       "channels": {
//         "iChannel0": {
//           "source": "bufferA",            // self-feedback
//           "filter": "nearest",            // "nearest" | "linear" (default "linear")
//           "wrap":   "clamp"               // "clamp" | "repeat" (default "clamp")
//         },
//         "iChannel1": { "source": "bufferB", "filter": "linear" }
//       }
//     },
//     {
//       "name": "image",                    // rendered to canvas; not bindable
//       "file": "image.glsl",
//       "channels": { "iChannel0": { "source": "bufferA", "filter": "nearest" } }
//     }
//   ]
// }
//
// Public API (ES module):
//   import { createShadertoy } from "/js/shadertoy-multipass.js";
//   const inst = await createShadertoy({
//     container,             // element id string or HTMLElement
//     path,                  // e.g. "/shaders/game-of-life"
//     paused: false,
//     showControls: true,    // play/pause + reset overlay
//     onError: (msg) => ...,
//   });
//   inst.play(); inst.pause(); inst.toggle(); inst.reset();

const VERT_SRC = `#version 300 es
precision highp float;
void main() {
  // Emits a fullscreen quad using gl_VertexID alone, no VBO needed.
  vec2 p = vec2(
    float((gl_VertexID & 1) << 2),
    float((gl_VertexID & 2) << 1)
  ) - 1.0;
  gl_Position = vec4(p, 0.0, 1.0);
}`;

// Preamble: what the engine always provides. We strip conflicting copies
// from the user's source before concatenating.
const FRAG_PREAMBLE = `#version 300 es
precision highp float;

uniform float      iTime;
uniform int        iFrame;
uniform vec3       iResolution;
uniform vec4       iMouse;
uniform vec2       iEmitter;
uniform sampler2D  iChannel0;
uniform sampler2D  iChannel1;
uniform sampler2D  iChannel2;
uniform sampler2D  iChannel3;

out vec4 outColor;
`;

const FRAG_MAIN = `void main() { mainImage(outColor, gl_FragCoord.xy); }`;

const FILTER_ENUM  = { nearest: 0x2600 /* NEAREST */, linear: 0x2601 /* LINEAR */ };
const WRAP_ENUM    = { clamp: 0x812F /* CLAMP_TO_EDGE */, repeat: 0x2901 /* REPEAT */ };

function compile(gl, type, src, label) {
  const sh = gl.createShader(type);
  gl.shaderSource(sh, src);
  gl.compileShader(sh);
  if (!gl.getShaderParameter(sh, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(sh);
    gl.deleteShader(sh);
    throw new Error(`[shadertoy] ${label} compile error:\n${log}\n--- source ---\n${src}`);
  }
  return sh;
}

function link(gl, vs, fs, label) {
  const p = gl.createProgram();
  gl.attachShader(p, vs);
  gl.attachShader(p, fs);
  gl.linkProgram(p);
  if (!gl.getProgramParameter(p, gl.LINK_STATUS)) {
    const log = gl.getProgramInfoLog(p);
    gl.deleteProgram(p);
    throw new Error(`[shadertoy] ${label} link error:\n${log}`);
  }
  return p;
}

// Translate legacy GLSL ES 1.00 calls (texture2D) to ES 3.00 (texture),
// strip conflicting boilerplate (version/precision/uniforms/out/main()),
// and choose the right wrapper for the user's source.
function buildFrag(rawSrc) {
  let s = rawSrc
    .replace(/\btexture2D\s*\(/g, "texture(")
    .replace(/^\s*#version\s+\d+\s*es\s*$/gm, "")
    .replace(/^\s*precision\s+\w+\s+\w+\s*;?\s*$/gm, "")
    .replace(/^\s*out\s+vec4\s+\w+\s*;?\s*$/gm, "")
    .replace(
      /^\s*uniform\s+(float|int|vec2|vec3|vec4|sampler2D)\s+(iTime|iFrame|iResolution|iMouse|iEmitter|iChannel[0-3])\s*;.*$/gm,
      ""
    )
    .replace(/void\s+main\s*\(\s*\)\s*\{[\s\S]*?\}\s*/g, "")
    .replace(/^\s*void\s+mainImage\s*\([^)]*\)\s*;\s*$/gm, "");

  if (/\bvoid\s+mainImage\s*\(/.test(s)) {
    return FRAG_PREAMBLE + "\n" + s + "\n" + FRAG_MAIN + "\n";
  }
  return (
    FRAG_PREAMBLE +
    "\nvoid mainImage(out vec4 fragColor, in vec2 fragCoord) {\n" +
    s +
    "\n}\n" +
    FRAG_MAIN +
    "\n"
  );
}

async function tryFetch(url) {
  try {
    const r = await fetch(url, { cache: "no-store" });
    if (!r.ok) return null;
    return await r.text();
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
//  #include pre-processor
//
//  GLSL ES 3.00 does not understand #include; we expand it in JavaScript
//  before handing the source to gl.compileShader. Includes are resolved
//  relative to the *file that contains them*.
// ---------------------------------------------------------------------------

const includeCache   = new Map();
const includeExpanding = new Set();

function dirname(url) { return url.replace(/[^/]*$/, ""); }

function resolvePath(base, rel) {
  const out = [];
  for (const seg of (base + rel).split("/")) {
    if (seg === "" || seg === ".") continue;
    if (seg === "..") out.pop();
    else out.push(seg);
  }
  return "/" + out.join("/");
}

async function expandIncludes(src, basePath) {
  const re = /^\s*#\s*include\s+["<]([^">]+)[">]\s*$/gm;
  let out = "", last = 0, m;
  while ((m = re.exec(src)) !== null) {
    out += src.slice(last, m.index);
    const includeRel = m[1];
    const includeUrl = resolvePath(basePath, includeRel);
    const expanded = await loadWithIncludes(includeUrl);
    if (expanded == null) {
      console.warn(`[shadertoy] failed to include ${includeUrl}`);
      out += `// FAILED INCLUDE: ${includeRel}\n`;
    } else {
      out += `// >>> ${includeRel}\n` + expanded + `\n// <<< ${includeRel}\n`;
    }
    last = m.index + m[0].length;
  }
  out += src.slice(last);
  return out;
}

async function loadWithIncludes(url) {
  if (includeCache.has(url)) return includeCache.get(url);
  if (includeExpanding.has(url)) {
    console.warn(`[shadertoy] circular include: ${url}`);
    return Promise.resolve(`// CIRCULAR INCLUDE: ${url}\n`);
  }
  includeExpanding.add(url);
  const p = tryFetch(url).then(async (src) => {
    if (src == null) return null;
    return await expandIncludes(src, dirname(url));
  });
  includeCache.set(url, p);
  try { return await p; } finally { includeExpanding.delete(url); }
}

// ---------------------------------------------------------------------------
//  Render targets + samplers
// ---------------------------------------------------------------------------

function makeFBO(gl, w, h) {
  const tex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, w, h, 0, gl.RGBA, gl.FLOAT, null);
  // Use NEAREST by default; the sampler object overrides per channel.
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S,     gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T,     gl.CLAMP_TO_EDGE);

  const fbo = gl.createFramebuffer();
  gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);
  gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, tex, 0);

  const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);
  if (status !== gl.FRAMEBUFFER_COMPLETE) {
    throw new Error(`[shadertoy] FBO incomplete: 0x${status.toString(16)}`);
  }

  return {
    tex, fbo, w, h,
    setSize(nw, nh) {
      gl.bindTexture(gl.TEXTURE_2D, tex);
      gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA32F, nw, nh, 0, gl.RGBA, gl.FLOAT, null);
      this.w = nw; this.h = nh;
    },
  };
}

// Cache one sampler per (filter, wrap) pair, so different channels can use
// different filter modes without changing the texture's own parameters.
function makeSampler(gl, filter, wrap) {
  const s = gl.createSampler();
  gl.samplerParameteri(s, gl.TEXTURE_MIN_FILTER, FILTER_ENUM[filter] || FILTER_ENUM.linear);
  gl.samplerParameteri(s, gl.TEXTURE_MAG_FILTER, FILTER_ENUM[filter] || FILTER_ENUM.linear);
  gl.samplerParameteri(s, gl.TEXTURE_WRAP_S,     WRAP_ENUM[wrap]   || WRAP_ENUM.clamp);
  gl.samplerParameteri(s, gl.TEXTURE_WRAP_T,     WRAP_ENUM[wrap]   || WRAP_ENUM.clamp);
  return s;
}

// ---------------------------------------------------------------------------
//  Config validation
// ---------------------------------------------------------------------------

function validateConfig(cfg) {
  if (!cfg || typeof cfg !== "object") throw new Error("config: must be an object");
  if (!Array.isArray(cfg.passes) || cfg.passes.length === 0) {
    throw new Error("config.passes must be a non-empty array");
  }
  const names = new Set();
  let imageIdx = -1;
  cfg.passes.forEach((p, idx) => {
    if (!p || typeof p !== "object") throw new Error(`passes[${idx}]: must be an object`);
    if (typeof p.name !== "string" || !p.name) throw new Error(`passes[${idx}].name required`);
    if (typeof p.file !== "string" || !p.file) throw new Error(`passes[${idx}].file required`);
    if (names.has(p.name)) throw new Error(`passes[${idx}].name '${p.name}' is duplicated`);
    names.add(p.name);
    if (p.name === "image") imageIdx = idx;
    if (p.channels) {
      if (typeof p.channels !== "object") {
        throw new Error(`passes[${idx}].channels must be an object`);
      }
      for (const chName of Object.keys(p.channels)) {
        if (!/^iChannel[0-3]$/.test(chName)) {
          throw new Error(`passes[${idx}].channels.${chName}: key must be iChannel0..3`);
        }
        const ch = p.channels[chName];
        if (!ch || typeof ch !== "object" || typeof ch.source !== "string") {
          throw new Error(`passes[${idx}].channels.${chName}.source required`);
        }
      }
    }
  });
  if (imageIdx === -1) throw new Error("config must include a pass named 'image'");
  if (imageIdx !== cfg.passes.length - 1) {
    throw new Error("the 'image' pass must be the last entry in config.passes");
  }
  // Channel references must point at valid earlier passes (or this buffer
  // itself, for self-feedback). Image cannot be a source.
  cfg.passes.forEach((p, idx) => {
    if (!p.channels) return;
    for (const chName of Object.keys(p.channels)) {
      const src = p.channels[chName].source;
      if (src === "image") {
        throw new Error(`passes[${idx}].channels.${chName}: cannot source from 'image'`);
      }
      const srcIdx = cfg.passes.findIndex((q) => q.name === src);
      if (srcIdx === -1) {
        throw new Error(`passes[${idx}].channels.${chName}: unknown source '${src}'`);
      }
      if (srcIdx > idx) {
        throw new Error(`passes[${idx}].channels.${chName}: source '${src}' is rendered after this pass`);
      }
    }
  });
}

// ---------------------------------------------------------------------------
//  UI helpers
// ---------------------------------------------------------------------------

function renderPlaceholder(container, message) {
  const msg = document.createElement("div");
  msg.className = "st-placeholder";
  msg.innerHTML = `
    <div class="st-placeholder-box">
      <div class="st-placeholder-title">Shader not loaded</div>
      <div class="st-placeholder-body">${message}</div>
    </div>
  `;
  container.appendChild(msg);
}

function makeControls(host, inst) {
  const bar = document.createElement("div");
  bar.className = "st-controls";
  bar.innerHTML = `
    <button type="button" data-act="toggle" title="Play / Pause" aria-label="Play / Pause">
      <span data-icon="pause">\u275A\u275A</span>
      <span data-icon="play" hidden>\u25B6</span>
    </button>
    <button type="button" data-act="reset" title="Restart" aria-label="Restart">
      \u21BB
    </button>
  `;
  bar.style.pointerEvents = "auto";
  host.appendChild(bar);

  const pauseIcon = bar.querySelector('[data-icon="pause"]');
  const playIcon  = bar.querySelector('[data-icon="play"]');
  const toggleBtn = bar.querySelector('[data-act="toggle"]');
  const resetBtn  = bar.querySelector('[data-act="reset"]');

  const sync = () => {
    const paused = inst.isPaused();
    pauseIcon.hidden = paused;
    playIcon.hidden = !paused;
    toggleBtn.setAttribute("aria-pressed", paused ? "false" : "true");
  };
  sync();

  toggleBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    e.preventDefault();
    inst.toggle();
    sync();
  });
  resetBtn.addEventListener("click", (e) => {
    e.stopPropagation();
    e.preventDefault();
    inst.reset();
  });
  return { sync };
}

// ---------------------------------------------------------------------------
//  Main entry point
// ---------------------------------------------------------------------------

export async function createShadertoy(opts) {
  const container = typeof opts.container === "string"
    ? document.getElementById(opts.container)
    : opts.container;
  if (!container) throw new Error("[shadertoy] container not found");

  const path = opts.path;
  const startPaused = !!opts.paused;
  const showControls = opts.showControls !== false;
  const onError = opts.onError || ((m) => console.error(m));

  if (getComputedStyle(container).position === "static") {
    container.style.position = "relative";
  }
  container.style.overflow = "hidden";

  const canvas = document.createElement("canvas");
  canvas.style.display = "block";
  canvas.style.width = "100%";
  canvas.style.height = "100%";
  container.appendChild(canvas);

  const gl = canvas.getContext("webgl2", {
    antialias: false,
    premultipliedAlpha: false,
    preserveDrawingBuffer: false,
  });
  if (!gl) { onError("WebGL2 is not available in this browser."); return null; }

  if (!gl.getExtension("EXT_color_buffer_float")) {
    onError("EXT_color_buffer_float is not available; float render targets unsupported.");
    return null;
  }

// Mouse state for the iMouse uniform.
  //   iMouse.xy  = current position (pixels, Y-up)
  //   iMouse.zw  = Shadertoy convention:
  //                 pressed  -> (clickX, clickY) so abs() gives click pos
  //                 released -> (-currentX, -currentY) so abs() gives current
  //                 This lets shaders write `iMouse.xy - abs(iMouse.zw)`
  //                 to get the mouse delta from the click position.
  //   iMouse.z > 0 still works as a "is pressed" check (since clickX is
  //   positive when the user clicks inside the visible canvas).
  const mouse = {
    px: 0, py: 0,        // current position
    clickX: 0, clickY: 0, // click position (only meaningful while down)
    down: false,
    lastClickT: -Infinity,
  };

  // Emitter position for shaders that want a "sticky" pointer — follows
  // the mouse only while the button is held, otherwise stays where it
  // last was. Starts off-canvas (-1, -1) so nothing is emitted before
  // the first click.
  const emitter = { x: -1, y: -1 };

  function setMouseFromEvent(ev) {
    const r = canvas.getBoundingClientRect();
    const dpr = canvas.width / Math.max(1, r.width);
    mouse.px = (ev.clientX - r.left) * dpr;
    mouse.py = canvas.height - (ev.clientY - r.top) * dpr; // flip Y to GL space
  }
  canvas.addEventListener("mousemove",  (ev) => {
    setMouseFromEvent(ev);
    // Emitter follows the cursor while the button is held; otherwise
    // it stays put so moving the mouse has no effect on the emitter.
    if (mouse.down) {
      emitter.x = mouse.px;
      emitter.y = mouse.py;
    }
  });
  canvas.addEventListener("mousedown",  (ev) => {
    if (ev.button !== 0) return;
    setMouseFromEvent(ev);
    mouse.down = true;
    mouse.clickX = mouse.px;
    mouse.clickY = mouse.py;
    emitter.x = mouse.px; // emitter jumps to cursor on initial press
    emitter.y = mouse.py;
    mouse.lastClickT = performance.now();
  });
  canvas.addEventListener("mouseup",    () => { mouse.down = false; });
  canvas.addEventListener("mouseleave", () => { mouse.down = false; });
  // Suppress the OS context menu so right-click doesn't disrupt interaction.
  canvas.addEventListener("contextmenu", (ev) => ev.preventDefault());

  // 1. Load and validate the config.
  const configUrl = `${path}/shader.json`;
  const configRaw = await tryFetch(configUrl);
  if (configRaw == null) {
    onError(`[shadertoy] shader.json not found at ${configUrl}`);
    renderPlaceholder(container, `Expected <code>${configUrl}</code>.`);
    return null;
  }
  let config;
  try { config = JSON.parse(configRaw); }
  catch (e) {
    onError(`[shadertoy] ${configUrl}: invalid JSON (${e.message})`);
    renderPlaceholder(container, `<code>${configUrl}</code>: invalid JSON.`);
    return null;
  }
  try { validateConfig(config); }
  catch (e) {
    onError(`[shadertoy] ${configUrl}: ${e.message}`);
    renderPlaceholder(container, `<code>${configUrl}</code>: ${e.message}`);
    return null;
  }

  // 2. Fetch each pass source (with #include expansion).
  const passes = [];
  for (const p of config.passes) {
    const url = `${path}/${p.file}`;
    const src = await loadWithIncludes(url);
    if (src == null) {
      const m = `referenced file <code>${url}</code> not found`;
      onError(`[shadertoy] ${m}`);
      renderPlaceholder(container, m);
      return null;
    }
    passes.push({ ...p, url, frag: buildFrag(src) });
  }

  // 3. Compile vertex shader once, then each fragment program.
  const vs = compile(gl, gl.VERTEX_SHADER, VERT_SRC, "vertex");
  const programs = {};
  for (const p of passes) {
    programs[p.name] = link(gl, vs, compile(gl, gl.FRAGMENT_SHADER, p.frag, p.name), p.name);
  }

  // 4. Cache uniform locations.
  const u = {};
  for (const p of passes) {
    const name = p.name;
    u[name] = {
      iTime:       gl.getUniformLocation(programs[name], "iTime"),
      iFrame:      gl.getUniformLocation(programs[name], "iFrame"),
      iResolution: gl.getUniformLocation(programs[name], "iResolution"),
      iMouse:      gl.getUniformLocation(programs[name], "iMouse"),
      iEmitter:    gl.getUniformLocation(programs[name], "iEmitter"),
      iChannels:   [0, 1, 2, 3].map((i) => gl.getUniformLocation(programs[name], "iChannel" + i)),
    };
  }

  // 5. Build sampler objects per (filter, wrap) pair actually used.
  const samplerCache = new Map();
  function samplerFor(filter, wrap) {
    const key = (filter || "linear") + "|" + (wrap || "clamp");
    if (samplerCache.has(key)) return samplerCache.get(key);
    const s = makeSampler(gl, filter, wrap);
    samplerCache.set(key, s);
    return s;
  }

  // 6. Resolve each pass's channel bindings.
  const passByName = Object.fromEntries(passes.map((p) => [p.name, p]));
  const bindings = {};
  for (const p of passes) {
    const slots = [null, null, null, null]; // index 0..3 -> { source, sampler }
    if (p.channels) {
      for (const chName of Object.keys(p.channels)) {
        const idx = +chName.slice("iChannel".length);
        const ch  = p.channels[chName];
        const src = passByName[ch.source];
        const sampler = samplerFor(ch.filter, ch.wrap);
        slots[idx] = { sourcePass: src, sampler };
      }
    }
    bindings[p.name] = slots;
  }

  // 7. Allocate ping-pong FBOs for each buffer pass. On resize we copy
  // the previous textures into the new ones with NEAREST filtering so
  // the buffer state survives a real size change pixel-perfect.
  let width = 1, height = 1;
  let bufferW = 0, bufferH = 0;
  const buffers = {};
  function allocBuffers(w, h) {
    // Skip if dimensions are unchanged. Resize events fire spuriously on
    // mobile (address bar collapse/expand, virtual keyboard, etc.) and on
    // desktop, and recreating FBOs wipes the accumulated buffer state.
    if (w === bufferW && h === bufferH && Object.keys(buffers).length > 0) {
      return;
    }
    for (const p of passes) {
      if (p.name === "image") continue;
      const old = buffers[p.name]; // [0] holds the most recent write (see drawBufferPass)
      const a = makeFBO(gl, w, h);
      const b = makeFBO(gl, w, h);
      if (old) {
        // Pixel-perfect blit: copy the old read texture into the new
        // "a" FBO at the top-left, using NEAREST so each old texel maps
        // to exactly one new texel. Pixels outside the old extent stay
        // zero. Bounded by the new size on the right/bottom.
        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, old[0].fbo);
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, a.fbo);
        gl.blitFramebuffer(
          0, 0, old[0].w, old[0].h,
          0, 0, Math.min(old[0].w, w), Math.min(old[0].h, h),
          gl.COLOR_BUFFER_BIT, gl.NEAREST
        );
        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, null);
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, null);
        gl.deleteFramebuffer(old[0].fbo); gl.deleteTexture(old[0].tex);
        gl.deleteFramebuffer(old[1].fbo); gl.deleteTexture(old[1].tex);
      }
      buffers[p.name] = [a, b];
    }
    bufferW = w;
    bufferH = h;
  }

  function resize() {
    const r = container.getBoundingClientRect();
    width  = Math.max(1, Math.floor(r.width));
    height = Math.max(1, Math.floor(r.height));
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const pw = Math.max(1, Math.floor(width * dpr));
    const ph = Math.max(1, Math.floor(height * dpr));
    if (canvas.width  !== pw) canvas.width  = pw;
    if (canvas.height !== ph) canvas.height = ph;
    canvas.style.width  = width  + "px";
    canvas.style.height = height + "px";
    allocBuffers(canvas.width, canvas.height);
  }

  let resizePending = false;
  window.addEventListener("resize", () => {
    if (resizePending) return;
    resizePending = true;
    requestAnimationFrame(() => { resizePending = false; resize(); });
  });

  resize();

  // 8. Render loop.
  let frame = 0;
  let paused = startPaused;
  let acc = 0;
  let lastT = performance.now();

  function bindChannel(slot, fallbackTex) {
    gl.activeTexture(gl.TEXTURE0 + slot.unit);
    if (slot.binding) {
      const b = slot.binding;
      gl.bindTexture(gl.TEXTURE_2D, b.tex);
      gl.bindSampler(slot.unit, b.sampler);
    } else {
      gl.bindTexture(gl.TEXTURE_2D, fallbackTex);
      gl.bindSampler(slot.unit, null);
    }
    gl.uniform1i(slot.loc, slot.unit);
  }

  function setStandardUniforms(passName, w, h) {
    const locs = u[passName];
    gl.uniform1f(locs.iTime, acc);
    gl.uniform1i(locs.iFrame, frame);
    gl.uniform3f(locs.iResolution, w, h, 1);
    if (locs.iMouse) {
      const zwX = mouse.down ? mouse.clickX : -mouse.px;
      const zwY = mouse.down ? mouse.clickY : -mouse.py;
      gl.uniform4f(locs.iMouse, mouse.px, mouse.py, zwX, zwY);
    }
    if (locs.iEmitter) {
      gl.uniform2f(locs.iEmitter, emitter.x, emitter.y);
    }
  }

  function drawBufferPass(p) {
    const [read, write] = buffers[p.name];
    gl.bindFramebuffer(gl.FRAMEBUFFER, write.fbo);
    gl.viewport(0, 0, write.w, write.h);
    gl.useProgram(programs[p.name]);
    setStandardUniforms(p.name, write.w, write.h);

    // Bind each channel declared in the config.
    const slots = bindings[p.name];
    for (let i = 0; i < 4; ++i) {
      const slot = { unit: i, loc: slots[i] && u[p.name].iChannels[i] };
      if (slots[i]) {
        const srcName = slots[i].sourcePass.name;
        let tex;
        if (srcName === p.name) {
          // Self-feedback: read from this buffer's read FBO.
          tex = read.tex;
        } else {
          // Cross-buffer: after all earlier buffers have been rendered this
          // frame, [0] holds the most recent write.
          tex = buffers[srcName][0].tex;
        }
        slot.binding = { tex, sampler: slots[i].sampler };
      }
      bindChannel(slot, read.tex); // fallback: previous frame of THIS buffer
    }
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    gl.bindSampler(0, null); gl.bindSampler(1, null);
    gl.bindSampler(2, null); gl.bindSampler(3, null);

    // Swap so the newly written texture is read next frame.
    buffers[p.name] = [write, read];
  }

  function drawImagePass() {
    gl.bindFramebuffer(gl.FRAMEBUFFER, null);
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.useProgram(programs.image);
    setStandardUniforms("image", canvas.width, canvas.height);

    const slots = bindings.image;
    for (let i = 0; i < 4; ++i) {
      const slot = { unit: i, loc: u.image.iChannels[i] };
      if (slots[i]) {
        const srcName = slots[i].sourcePass.name;
        // Image is rendered after all buffers, so buffers[srcName][0] is fresh.
        slot.binding = { tex: buffers[srcName][0].tex, sampler: slots[i].sampler };
      }
      bindChannel(slot, null);
    }
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    gl.bindSampler(0, null); gl.bindSampler(1, null);
    gl.bindSampler(2, null); gl.bindSampler(3, null);
  }

  // 8. Render loop. The rAF chain is broken when paused and resumed
  //    on play(), so no rendering happens at all while paused - frame,
  //    iTime, and the buffer all freeze. (frame, paused, acc, lastT
  //    were declared earlier in step 5.)
  let rafId = null;

  function loop() {
    rafId = null;
    if (paused) return; // Do not schedule the next frame while paused.
    const now = performance.now();
    const dt = Math.min(0.1, (now - lastT) / 1000); // clamp big jumps
    lastT = now;
    acc += dt;
    for (const p of passes) {
      if (p.name !== "image") drawBufferPass(p);
    }
    drawImagePass();
    frame++;
    rafId = requestAnimationFrame(loop);
  }
  rafId = requestAnimationFrame(loop);

  const inst = {
    play() {
      if (!paused) { controls.sync(); return; }
      paused = false;
      lastT = performance.now(); // avoid a huge dt on resume
      if (rafId === null) rafId = requestAnimationFrame(loop);
      controls.sync();
    },
    pause() {
      if (paused) { controls.sync(); return; }
      paused = true;
      if (rafId !== null) {
        cancelAnimationFrame(rafId);
        rafId = null;
      }
      controls.sync();
    },
    toggle() {
      if (paused) inst.play();
      else inst.pause();
      return paused;
    },
    reset() {
      acc = 0;
      frame = 0;
    },
    isPaused() { return paused; },
    onError,
  };

  const controls = showControls ? makeControls(container, inst) : { sync() {} };
  inst._syncControls = controls.sync;
  return inst;
}