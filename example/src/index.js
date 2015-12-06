define(['require', 'exports', 'module', './mod-a'], function(require, exports, module, modA) {
	var $ = require('jquery');
	var modB = require('./mod-b');
	var modF = require('./mod-f');
	var modG = require('./mod-g');
	var tplA = require('./inline-tpl-a.tpl.html');
	var tplB = require('./inline-tpl-b.tpl.html');
	var riot = require('./riot');
	var riotHtml = require('./riot-html');

	return {};
});

__END__

@@ inline-tpl-a.tpl.html
<div></div>

@@ inline-tpl-b.tpl.html
<div></div>