// Run after NATIVE_HTML_OUT=<fixture> go test -run TestNativeShell.
// npm install --prefix <scratch> jsdom@26.1.0; NODE_PATH=<scratch>/node_modules
// NATIVE_HTML_OUT=<fixture> node --test native_ui_test.cjs
// Simulates the native transport only; this is not a Windows GUI smoke test.
const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {JSDOM} = require('jsdom');
const html = readFileSync(process.env.NATIVE_HTML_OUT,'utf8');
const settle = () => new Promise(resolve=>setTimeout(resolve,30));

async function setup(t, handlers = {}) {
  const calls=[], timers=[];
  const dom = new JSDOM(html, {runScripts:'dangerously',pretendToBeVisual:true,beforeParse(window){
    let listener;
    window.setInterval=fn=>{timers.push(fn);return timers.length;};
    window.chrome={webview:{
      addEventListener(name,fn){assert.equal(name,'message');listener=fn;},
      postMessage(raw){
        const req=JSON.parse(raw); calls.push(req);
        Promise.resolve().then(async()=>{
          assert.equal(req.token,'test-token');
          let result;
          try {
            const fn=handlers[req.method];
            result=fn ? await fn(...req.params) : {HTML:'<p>Saved report</p>',Game:'C:\\_forever_',InstalledVersion:'1.3.1'};
            listener({data:{kind:'native-response',id:req.id,result}});
          } catch(error) {listener({data:{kind:'native-response',id:req.id,error:error.message}});}
        });
      }
    }};
    window.fetch=()=>{assert.fail('native UI used HTTP')};
  }});
  t.after(()=>dom.window.close());
  await settle();
  return {dom,calls,tick:()=>timers.forEach(fn=>fn()),$:id=>dom.window.document.getElementById(id)};
}

test('report loads automatically; sidebar changes views without navigation', async t=>{
  const {$,calls}=await setup(t);
  assert.equal($('report-view').hidden,false);
  assert.match($('report-body').textContent,/Saved report/);
  assert.equal(calls[0].method,'reportRefresh');
  $('nav-update').click();assert.equal($('update-view').hidden,false);
  assert.equal($('report-view').hidden,true);
  $('nav-report').click();$('refresh').click();await settle();
  assert.equal(calls.filter(c=>c.method==='reportRefresh').length,2);
});

test('release text is inert and apply sends only the expected version',async t=>{
  const {$,calls}=await setup(t,{
    checkAddon:()=>({Version:'1.4.0',InstalledVersion:'1.3.1',Available:true,HTMLURL:'https://github.com/thegamersvibe/relax-coach/releases/tag/v1.4.0',Name:'<img src=x onerror=alert(1)>',Notes:'<script>owned</script>'}),
    applyAddon:()=>({version:'1.4.0',backupPath:'C:\\backup',updatedFiles:12,message:'Installed safely'})
  });
  $('check-update').click();await settle();
  assert.equal($('installed-version').textContent,'1.3.1');
  assert.equal($('release-notes').querySelector('script'),null);
  assert.match($('release-notes').textContent,/<script>/);
  assert.equal($('release-name').querySelector('img'),null);
  assert.equal($('apply-update').disabled,false);
  $('apply-update').click();await settle();
  assert.deepEqual(calls.find(c=>c.method==='applyAddon').params,['1.4.0']);
  assert.match($('update-status').textContent,/Installed safely/);
  assert.match($('update-status').textContent,/C:\\backup/);
  assert.equal($('apply-update').disabled,true);
});

test('guild updater describes all three trees and never offers a repository-only tag',async t=>{
  const {$}=await setup(t,{checkAddon:()=>({Version:'1.4.2',InstalledVersion:'1.4.0',Available:false,Notes:'This is an app-only release. Required RelaxCoach-Guild-1.4.2.zip is missing.'})});
  const card=$('apply-update').closest('.updatecard');
  for(const name of ['ForeverCoach','Journey','Journey-Content']) assert.ok(card.textContent.includes(name),name);
  assert.doesNotMatch(card.textContent,/Journey and private content are unchanged|Latest release/);
  $('check-update').click();await settle();
  assert.equal($('offered-version').textContent,'None');
  assert.match($('update-status').textContent,/app-only/);
  assert.match($('update-status').textContent,/RelaxCoach-Guild-1.4.2.zip/);
  assert.equal($('apply-update').disabled,true);
});

test('incompatible or older release never falsely claims up to date' ,async t=>{
  const {$}=await setup(t,{checkAddon:()=>({Version:'1.3.0',InstalledVersion:'1.3.1',Available:false,Notes:'No compatible asset'})});
  $('check-update').click();await settle();
  assert.equal($('apply-update').disabled,true);
  assert.doesNotMatch($('update-status').textContent,/up to date/i);
  assert.match($('update-status').textContent,/compatible/i);
});

test('offline check clears stale offer and allows retry',async t=>{
  let offline=false;
  const {$}=await setup(t,{checkAddon:()=>{if(offline)throw Error('rate limit');return {Version:'1.4.0',Available:true,Notes:'ok'};}});
  $('check-update').click();await settle();assert.equal($('apply-update').disabled,false);
  offline=true;$('check-update').click();await settle();
  assert.equal($('apply-update').disabled,true);
  assert.equal($('check-update').disabled,false);
  assert.match($('update-status').textContent,/rate limit/);
});

test('external link uses native binding; folder picker cancellation is inert',async t=>{
  const {$,calls,dom}=await setup(t,{chooseGame:()=>null,openExternal:()=>null});
  const link=dom.window.document.createElement('a');link.href='https://github.com/thegamersvibe/relax-coach/releases';
  link.textContent='Release';dom.window.document.body.append(link);link.click();
  $('browse-folder').click();await settle();
  assert.ok(calls.some(c=>c.method==='openExternal'));
  assert.equal(dom.window.location.href,'about:blank');
  assert.match($('report-body').textContent,/Saved report/);
});

const gameA='C:\\GameA\\_forever_', gameB='D:\\GameB\\_forever_';
const report=game=>({HTML:`<p>Report for ${game}</p>`,Game:game,InstalledVersion:game===gameA?'1.3.1':'1.4.0'});
const availableOffer={Version:'1.5.0',InstalledVersion:'1.4.0',Available:true,Notes:'Checked for this folder'};
function deferred() {
  let resolve,reject;
  const promise=new Promise((ok,fail)=>{resolve=ok;reject=fail;});
  return {promise,resolve,reject};
}
function submitFolder(dom,$,game) {
  $('game-path').value=game;
  $('game-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
}
function assertReport($,game) {
  assert.equal($('folder-label').textContent,game,'folder label must match the selected folder');
  assert.equal($('game-path').value,game,'path input must match the selected folder');
  assert.equal($('report-body').innerHTML,report(game).HTML,'report must match the selected folder');
  assert.equal($('installed-version').textContent,report(game).InstalledVersion);
}

test('a delayed report for A cannot replace selected folder B or its update target',async t=>{
  const oldRefresh=deferred();
  let selected=gameA, refreshes=0, applied;
  const {dom,$,calls}=await setup(t,{
    reportRefresh:()=>++refreshes===2?oldRefresh.promise:report(selected),
    setGame:game=>{selected=game;return report(selected);},
    checkAddon:()=>availableOffer,
    applyAddon:version=>{applied={game:selected,version};return {message:'Mock only; no files changed'};}
  });
  $('check-update').click();await settle();
  assert.equal($('apply-update').disabled,false);
  $('refresh').click();await settle();
  submitFolder(dom,$,gameB);await settle();
  assertReport($,gameB);
  assert.equal($('apply-update').disabled,true,'folder change invalidates the checked release');
  assert.equal($('offered-version').textContent,'Not checked');
  oldRefresh.resolve(report(gameA));await settle();
  assertReport($,gameB);
  assert.equal($('global-status').textContent,'Game folder saved.','old refresh must not replace the selection status');
  assert.equal(selected,gameB);
  $('check-update').click();await settle();
  $('apply-update').click();await settle();
  assert.deepEqual(applied,{game:gameB,version:'1.5.0'});
  assert.deepEqual(calls.find(c=>c.method==='applyAddon').params,['1.5.0']);
  assertReport($,gameB);
});

for (const selection of ['typed','picker']) {
  test(`${selection} folder transition hides the old label and blocks all new refreshes`,async t=>{
    const oldRefresh=deferred(), selectionReply=deferred();
    let refreshes=0, selected=gameA;
    const {dom,$,calls,tick}=await setup(t,{
      reportRefresh:()=>++refreshes===2?oldRefresh.promise:report(selected),
      setGame:game=>{selected=game;return selectionReply.promise;},
      chooseGame:()=>{selected=gameB;return selectionReply.promise;}
    });
    $('refresh').click();await settle();
    if(selection==='typed') submitFolder(dom,$,gameB);
    else $('browse-folder').click();
    await settle();
    assert.notEqual($('folder-label').textContent,gameA,'old folder label must not remain authoritative while changing folders');
    assert.equal($('refresh').disabled,true);
    for(const id of ['check-update','apply-update','browse-folder','use-folder','game-path']) assert.equal($(id).disabled,true,id);
    oldRefresh.resolve(report(gameA));await settle();
    assert.notEqual($('folder-label').textContent,gameA,'old reply must not restore the label mid-transition');
    assert.equal($('refresh').disabled,true,'old refresh completion must not unlock a pending selection');
    $('refresh').dispatchEvent(new dom.window.Event('click'));
    tick();
    $('browse-folder').dispatchEvent(new dom.window.Event('click'));
    $('game-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));
    await settle();
    assert.equal(calls.filter(c=>c.method==='reportRefresh').length,2,'manual and periodic refreshes cannot start during selection');
    assert.equal(calls.filter(c=>['setGame','chooseGame'].includes(c.method)).length,1,'selection remains single-flight');
    selectionReply.resolve(report(gameB));await settle();
    assertReport($,gameB);
    assert.equal($('refresh').disabled,false);
    assert.equal($('check-update').disabled,false);
    tick();await settle();
    assert.equal(calls.filter(c=>c.method==='reportRefresh').length,3,'periodic refresh resumes after selection');
    assertReport($,gameB);
  });
}

for (const outcome of ['success','cancel','error']) {
  for (const oldReply of ['report','error']) {
    test(`picker ${outcome} preserves the committed selection when an old refresh ${oldReply} arrives last`,async t=>{
      const oldRefresh=deferred(), picker=deferred();
      let selected=gameA, refreshes=0;
      const {$,calls}=await setup(t,{
        reportRefresh:()=>++refreshes===2?oldRefresh.promise:report(selected),
        checkAddon:()=>({...availableOffer,InstalledVersion:report(selected).InstalledVersion}),
        chooseGame:async()=>{const result=await picker.promise;if(result)selected=result.Game;return result;}
      });
      $('check-update').click();await settle();
      assert.equal($('apply-update').disabled,false);
      const priorStatus=$('update-status').textContent;
      $('refresh').click();await settle();
      $('browse-folder').click();await settle();
      assert.notEqual($('folder-label').textContent,gameA);
      assert.equal($('check-update').disabled,true);
      if(outcome==='success') picker.resolve(report(gameB));
      else if(outcome==='cancel') picker.resolve(null);
      else picker.reject(Error('Folder picker failed; paste the path instead'));
      await settle();
      assertReport($,outcome==='success'?gameB:gameA);
      assert.equal($('apply-update').disabled,outcome==='success','only successful folder changes invalidate the checked release');
      assert.equal($('offered-version').textContent,outcome==='success'?'Not checked':'1.5.0');
      if(outcome!=='success') assert.equal($('update-status').textContent,priorStatus);
      if(outcome==='error') assert.match($('global-status').textContent,/Folder picker failed/);
      const selectionStatus=$('global-status').textContent;
      if(oldReply==='report') oldRefresh.resolve({...report(gameA),HTML:'<p>Outdated report</p>',InstalledVersion:'0.1.0'});
      else oldRefresh.reject(Error('Outdated refresh failed'));
      await settle();
      assertReport($,selected);
      assert.equal($('global-status').textContent,selectionStatus,'late refresh messages must not hide the selection outcome');
      assert.equal($('refresh').disabled,false);
      for(const id of ['check-update','browse-folder','use-folder','game-path']) assert.equal($(id).disabled,false,id);
      $('refresh').click();await settle();
      assertReport($,selected);
      assert.equal(calls.filter(c=>c.method==='reportRefresh').length,3,'fresh manual reports still work');
      assert.equal(calls.filter(c=>c.method==='chooseGame').length,1);
    });
  }
}

