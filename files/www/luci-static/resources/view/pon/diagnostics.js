'use strict';
'require fs';
'require form';
'require ui';
'require uci';
'require view';

var HELPER = '/usr/libexec/airoha-pon-debug';
var BUNDLE = '/tmp/pon-debug.tar.gz';

function downloadBundle() {
	return fs.read_direct(BUNDLE, 'blob').then(function(blob) {
		var url = window.URL.createObjectURL(blob);
		var link = document.createElement('a');
		var now = new Date();
		link.style.display = 'none';
		link.href = url;
		link.download = 'pon-debug-' + now.toISOString().replace(/[:.]/g, '-') + '.tar.gz';
		document.body.appendChild(link);
		link.click();
		link.remove();
		window.URL.revokeObjectURL(url);
	});
}

return view.extend({
	load: function() {
		return Promise.all([
			uci.load('airoha-pon-debug'),
			uci.load('pon'),
			fs.exec_direct(HELPER, ['log']).catch(function() { return ''; })
		]);
	},

	handleDownload: function() {
		var button = document.getElementById('pon-debug-download');
		button.disabled = true;
		button.classList.add('spinning');
		return fs.exec_direct(HELPER, ['collect']).then(downloadBundle).catch(function(error) {
			ui.addNotification(null, E('p', {}, _('Unable to create diagnostic package: %s').format(error.message)));
		}).finally(function() {
			button.disabled = false;
			button.classList.remove('spinning');
		});
	},

	handleRestart: function() {
		var button = document.getElementById('pon-debug-restart');
		if (!window.confirm(_('The PON line and OMCI/OAM interfaces will be stopped and restarted. Continue?')))
			return;
		button.disabled = true;
		button.classList.add('spinning');
		return fs.exec_direct(HELPER, ['restart']).then(function(output) {
			var result = JSON.parse(output);
			if (!result.ok)
				throw new Error(_('PON restart failed.'));
			ui.addNotification(null, E('p', {}, _('PON restart completed.')));
		}).catch(function(error) {
			ui.addNotification(null, E('p', {}, _('Unable to restart PON: %s').format(error.message)));
		}).finally(function() {
			button.disabled = false;
			button.classList.remove('spinning');
		});
	},

	handleRefreshLog: function() {
		var logArea = document.getElementById('pon-live-log');
		var refreshBtn = document.getElementById('pon-log-refresh');
		if (refreshBtn) {
			refreshBtn.disabled = true;
			refreshBtn.classList.add('spinning');
		}
		return fs.exec_direct(HELPER, ['log']).then(function(res) {
			if (logArea) {
				logArea.value = (res || '').trim();
				logArea.scrollTop = logArea.scrollHeight;
			}
		}).catch(function(err) {
			ui.addNotification(null, E('p', {}, _('刷新日志失败: %s').format(err.message)));
		}).finally(function() {
			if (refreshBtn) {
				refreshBtn.disabled = false;
				refreshBtn.classList.remove('spinning');
			}
		});
	},

	handleCopyLog: function() {
		var logArea = document.getElementById('pon-live-log');
		if (logArea && logArea.value) {
			navigator.clipboard.writeText(logArea.value).then(function() {
				ui.addNotification(null, E('p', {}, _('日志内容已成功复制到剪贴板！')), 'info');
			}).catch(function() {
				logArea.select();
				document.execCommand('copy');
				ui.addNotification(null, E('p', {}, _('日志内容已选中并复制！')), 'info');
			});
		}
	},

	render: function(data) {
		var initialLog = (data && data[2]) ? data[2].trim() : '';
		var m, s, o;

		m = new form.Map('airoha-pon-debug', _('PON 链路调试与网络诊断 (Debug)'),
			_('调试模式会在内存环形缓冲区持续记录原始 PON、OMCI 和 OAM 交互报文，支持在线查看实时链路日志、下载完整抓包诊断包及安全重载 PON 线路。'));
		m.chain('pon');
		m.readonly = !L.hasViewPermission();

		s = m.section(form.NamedSection, 'capture', 'capture', _('PON 线路抓包调试设置'));
		o = s.option(form.DummyValue, '_devices', _('PON 接口'));
		o.cfgvalue = function() {
			return uci.sections('pon', 'xpon').map(function(line) {
				return line.device || line['.name'];
			}).join(', ') || '-';
		};

		o = s.option(form.Flag, 'enabled', _('抓包调试模式 (Debug mode)'));
		o.default = o.disabled;
		o.rmempty = false;
		o.description = _('启用后将在重启 PON 时自动启动 tcpdump 后台全量抓包；关闭则停止抓包释放内存。');

		return m.render().then(L.bind(function(map) {
			return E([], [
				map,
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('PON 链路与 OMCI 实时运行日志 (Live Log)')),
					E('div', { 'class': 'cbi-section-descr' },
						_('实时展示 airoha-xpon 内核驱动（PLOAM 握手、O1-O5 状态跃迁）、OMCI CTC LOID 鉴权及 PPPoE 拨号日志。')),
					E('div', { 'style': 'margin-bottom: 10px; display: flex; gap: 8px; flex-wrap: wrap;' }, [
						E('button', {
							'class': 'cbi-button cbi-button-action',
							'id': 'pon-log-refresh',
							'click': ui.createHandlerFn(this, 'handleRefreshLog')
						}, _('🔄 刷新日志')),
						E('button', {
							'class': 'cbi-button cbi-button-neutral',
							'id': 'pon-log-copy',
							'click': ui.createHandlerFn(this, 'handleCopyLog')
						}, _('📋 复制日志'))
					]),
					E('textarea', {
						'id': 'pon-live-log',
						'readonly': 'readonly',
						'wrap': 'off',
						'style': 'width: 100%; min-height: 320px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 12px; line-height: 1.5; background: #111827; color: #4ade80; border: 1px solid #374151; border-radius: 8px; padding: 12px; box-sizing: border-box; resize: vertical;'
					}, [ initialLog || '暂无日志或正在加载中...' ])
				]),
				E('div', { 'class': 'cbi-section' }, [
					E('h3', {}, _('高级诊断与维护操作')),
					E('p', {}, _('收集包含原始 pcap 抓包、PON 寄存器状态、系统日志及网络拓扑的完整诊断压缩包，或软重启 PON 线路重新握手 OLT。')),
					E('div', { 'class': 'cbi-page-actions' }, [
						E('button', {
							'class': 'cbi-button cbi-button-action',
							'id': 'pon-debug-download',
							'disabled': m.readonly || null,
							'click': ui.createHandlerFn(this, 'handleDownload')
						}, _('📦 下载完整诊断包 (tar.gz)')),
						E('button', {
							'class': 'cbi-button cbi-button-negative',
							'id': 'pon-debug-restart',
							'disabled': m.readonly || null,
							'click': ui.createHandlerFn(this, 'handleRestart')
						}, _('⚠️ 重启 PON 线路'))
					])
				])
			]);
		}, this));
	}
});
