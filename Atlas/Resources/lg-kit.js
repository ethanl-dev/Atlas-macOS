(function(){
// ═══════════════════════════════════════════════════════════════
//  LG · Liquid Glass 前端模版语言 v1
//  依赖：LiquidGlass 类（@ybouane/liquidglass）需先于本文件内联
//  用法：写声明式 HTML（见 SKILL.md 词汇表），最后 await LG.init()
// ═══════════════════════════════════════════════════════════════
const LiquidGlass = window.AtlasLiquidGlassCore;
const LG = (() => {

	// ── 组件预设（参数复刻 liquid-glass.ybouane.com 原站）──
	const PRESETS = {
		// 大玻璃面板（hero 标题牌）：强折射 + 色散
		panel:        { blurAmount: 0.3, chromAberration: 0.2, cornerRadius: 60, zRadius: 60, refraction: 1.2, brightness: -0.2 },
		// 液态按钮：纯默认参数成就厚玻璃圆顶，hover 增亮/按压压平由库内置
		button:       { button: true, cornerRadius: 24 },
		// 三种质感胶囊（floating = 库内置可拖拽）
		'pill-clear': { floating: true, cornerRadius: 40, blurAmount: 0 },
		'pill-frost': { floating: true, cornerRadius: 40, blurAmount: 0.5 },
		'pill-dark':  { floating: true, cornerRadius: 40, brightness: -0.3, blurAmount: 0.4 },
		// 贴在媒体/卡片底部的控制条
		hud:          { cornerRadius: 20, zRadius: 20, blurAmount: 0.4, brightness: -0.1 },
		// 放大镜圆顶（可拖拽）
		dome:         { bevelMode: 1, cornerRadius: 30, zRadius: 30, floating: true, blurAmount: 0, refraction: 1.2, edgeHighlight: 0.15, shadowOpacity: 0.2 },
		// dock 滑动指示条（由 LG 自动创建，不手写）
		indicator:    { cornerRadius: 16, zRadius: 16, blurAmount: 0, edgeHighlight: 0.2, shadowOpacity: 0.25 },
	};

	// ── 基础样式（自动注入，页面无需引 CSS 文件）──
	const CSS = `
[data-lg-root]{position:relative;overflow:hidden}
.lg-bg{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;z-index:0;pointer-events:none}
.lg-label{position:relative;z-index:2;pointer-events:none}
[data-lg]{z-index:2}
[data-lg=panel]{color:#fff;text-align:center;padding:40px}
[data-lg=button]{display:inline-flex;align-items:center;justify-content:center;padding:14px 28px;color:#fff;font-weight:600;font-size:16px;text-decoration:none;cursor:pointer;white-space:nowrap}
[data-lg=button] .lg-label{filter:drop-shadow(0 0 6px #000);display:flex;align-items:center;gap:8px}
[data-lg=pill-clear],[data-lg=pill-frost],[data-lg=pill-dark]{color:#fff;padding:22px 26px}
[data-lg=dome]{position:absolute;width:150px;height:150px;z-index:5;touch-action:none}
[data-lg=hud]{display:flex;align-items:center;color:#fff;padding:10px 16px}
.lg-dock{position:relative;display:flex;background:#00000033;border-radius:20px;z-index:4}
.lg-dock-item{padding:18px 30px;display:flex;align-items:center;justify-content:center;cursor:pointer;z-index:4;position:relative;transition:opacity .2s ease;filter:drop-shadow(0 2px 6px rgba(0,0,0,.3));font-size:32px;color:#fff}
.lg-dock-item:hover{opacity:.85}
.lg-dock-indicator{position:absolute;top:0;left:0;z-index:5;transform:translate(-9999px,-9999px);transition:transform .45s cubic-bezier(.65,0,.35,1);will-change:transform;pointer-events:none}
.lg-title{color:#fff;font-size:clamp(34px,5vw,52px);font-weight:800;text-shadow:0 2px 24px rgba(0,0,0,.7);letter-spacing:-1px;margin:0}
.lg-sub{color:#fff;font-size:17px;font-weight:600;text-shadow:0 1px 8px rgba(0,0,0,.7);margin:12px 0 0}
`;

	function injectCSS() {
		if (document.getElementById('lg-kit-style')) return;
		const s = document.createElement('style');
		s.id = 'lg-kit-style';
		s.textContent = CSS;
		document.head.appendChild(s);
	}

	// 玻璃元素在 CSS transition 移动期间每帧重采样背景。
	// 库默认只在标记 dirty 时渲染，不做这一步玻璃会带着旧纹理移动（错位假影）。
	function attachResampler(instance, el) {
		let raf = 0;
		el.addEventListener('transitionstart', e => {
			if (e.target !== el) return;
			cancelAnimationFrame(raf);
			const tick = () => { instance.markChanged(el); raf = requestAnimationFrame(tick); };
			tick();
		});
		const stop = e => {
			if (e.target !== el) return;
			cancelAnimationFrame(raf); raf = 0;
			instance.markChanged(el);
		};
		el.addEventListener('transitionend', stop);
		el.addEventListener('transitioncancel', stop);
	}

	// dock：底板是普通 CSS 半透明黑（原站做法），滑动指示条是叠在上面的库玻璃
	function setupDock(root, instance, dock, ind) {
		const items = [...dock.querySelectorAll('.lg-dock-item')];
		if (!items.length) return;
		let active = Math.max(0, items.findIndex(i => i.classList.contains('active')));

		function sync(animate) {
			const it = items[active];
			const r = it.getBoundingClientRect();
			const rr = root.getBoundingClientRect();
			if (!animate) ind.style.transition = 'none';
			ind.style.width = r.width + 'px';
			ind.style.height = r.height + 'px';
			ind.style.transform = `translate(${r.left - rr.left}px, ${r.top - rr.top}px)`;
			if (!animate) { ind.offsetHeight; ind.style.transition = ''; instance.markChanged(ind); }
		}

		items.forEach((it, i) => it.addEventListener('click', () => {
			active = i;
			sync(true);
			const bg = it.dataset.lgSwitchBg;             // 可选：点击切换背景层
			if (bg) {
				let shown = null;
				root.querySelectorAll('.lg-bg').forEach(im => {
					const on = im.dataset.bg === bg;
					im.style.display = on ? 'block' : 'none';
					if (on) shown = im;
				});
				if (shown) instance.markChanged(shown);   // display 翻转库看不到，必须通知
			}
		}));

		requestAnimationFrame(() => requestAnimationFrame(() => sync(false)));
		window.addEventListener('resize', () => sync(false));
	}

	// 嵌套 root 支持：元素只归属于最近的 [data-lg-root] 祖先
	function belongsTo(el, root) {
		return el.parentElement && el.parentElement.closest('[data-lg-root]') === root;
	}

	async function initRoot(root) {
		// 1. 组件收集：preset + data-lg-config 覆盖 => 库的 dataset.config
		const glasses = [...root.querySelectorAll('[data-lg]')].filter(el => belongsTo(el, root));
		for (const el of glasses) {
			const preset = PRESETS[el.dataset.lg];
			if (!preset) { console.warn('[LG] 未知组件类型:', el.dataset.lg, el); continue; }
			const override = el.dataset.lgConfig ? JSON.parse(el.dataset.lgConfig) : {};
			el.dataset.config = JSON.stringify({ ...preset, ...override });
		}

		// 2. 每个 dock 自动创建滑动指示条（也是玻璃元素）
		const docks = [...root.querySelectorAll('.lg-dock')].filter(el => belongsTo(el, root));
		const dockPairs = docks.map(dock => {
			const ind = document.createElement('div');
			ind.className = 'lg-dock-indicator';
			const override = dock.dataset.lgIndicatorConfig ? JSON.parse(dock.dataset.lgIndicatorConfig) : {};
			ind.dataset.config = JSON.stringify({ ...PRESETS.indicator, ...override });
			root.appendChild(ind);
			return { dock, ind };
		});

		// 3. 等 root 内图片就绪，避免库捕捉到空背景
		await Promise.all([...root.querySelectorAll('img')].map(img =>
			img.complete ? Promise.resolve() : new Promise(r => { img.onload = r; img.onerror = r; })
		));

		// 4. 初始化库
		const allGlass = [...glasses.filter(el => PRESETS[el.dataset.lg]), ...dockPairs.map(p => p.ind)];
		const instance = await LiquidGlass.init({ root, glassElements: allGlass });

		// 5. 兜底行为：过渡重采样 + dock 交互
		allGlass.forEach(el => attachResampler(instance, el));
		dockPairs.forEach(({ dock, ind }) => setupDock(root, instance, dock, ind));

		return instance;
	}

	// 入口：扫描所有 [data-lg-root]，返回 Map<rootEl, LiquidGlass 实例>
	async function init(scope = document) {
		injectCSS();
		const roots = [...scope.querySelectorAll('[data-lg-root]')];
		if (!roots.length) console.warn('[LG] 页面中没有 [data-lg-root] 容器');
		const map = new Map();
		for (const r of roots) map.set(r, await initRoot(r));
		return map;
	}

	return { init, PRESETS };
})();
window.AtlasLG = LG;
})();
