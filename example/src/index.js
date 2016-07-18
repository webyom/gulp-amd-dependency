define(['require', 'exports', 'module', './mod-a'], function(require, exports, module, modA) {
	// require('./**/*');
	var $ = require('jquery');
	var modB = require('./mod-b');
	var modF = require('./mod-f');
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
