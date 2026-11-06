// CSS contract on the real embedded shell; native screenshot verifies layout.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {JSDOM} = require('jsdom');

test('sidebar emblem fills its column without distortion', t => {
  const dom = new JSDOM(readFileSync(process.env.NATIVE_HTML_OUT, 'utf8'));
  t.after(() => dom.window.close());
  const image = dom.window.document.querySelector('.sidebar .brand .crest');
  assert.ok(image, 'existing approved emblem remains');
  const css = dom.window.getComputedStyle(image);
  assert.equal(css.width, '100%', 'logo must fill sidebar content width, not stay at 68px');
  assert.equal(css.height, 'auto', 'height must follow artwork proportions');
  assert.equal(css.objectFit, 'contain', 'never crop or stretch the emblem');
  assert.equal(css.display, 'block');
  assert.equal(image.nextElementSibling.textContent, 'Relax Coach', 'keep the name beneath the emblem');
});
