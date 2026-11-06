// Runs the actual Go-embedded native shell with a simulated native transport.
// This is DOM/RPC behavior, not a Windows WebView2 smoke test.
const {test}=require('node:test');
const assert=require('node:assert/strict');
const {readFileSync}=require('node:fs');
const {JSDOM}=require('jsdom');
const html=readFileSync(process.env.NATIVE_HTML_OUT,'utf8');
const settle=()=>new Promise(ok=>setTimeout(ok,20));
const gameA='C:\\GameA\\_forever_', gameB='D:\\GameB\\_forever_';
const idA='A#1', idB='B#2';
const saveTime='2026-01-02T03:04:05Z';
const choices=[{ID:idA,SVPath:'A source',SaveTime:saveTime},{ID:idB,SVPath:'B source',SaveTime:saveTime}];
const report=(account=idA,game=gameA)=>({HTML:account?`<p>Only ${account} character</p>`:'<p>Choose an account</p>',Game:game,InstalledVersion:'1.3.1',Account:account,Accounts:choices,SVPath:account?`${game}\\WTF\\Account\\${account}\\SavedVariables\\ForeverCoach.lua`:'',SaveTime:account?saveTime:'',Stale:false,ConfigWarning:''});
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};}
async function setup(t,handlers={}){
  const calls=[],timers=[];let listener;
  const dom=new JSDOM(html,{runScripts:'dangerously',pretendToBeVisual:true,beforeParse(w){
    w.setInterval=fn=>{timers.push(fn);return timers.length;};
    w.chrome={webview:{addEventListener(_name,fn){listener=fn;},postMessage(raw){
      const req=JSON.parse(raw);calls.push(req);
      Promise.resolve().then(async()=>{
        assert.equal(req.token,'test-token');
        try {const fn=handlers[req.method];const result=fn?await fn(...req.params):report();listener({data:{kind:'native-response',id:req.id,result}});}
        catch(err){listener({data:{kind:'native-response',id:req.id,error:err.message}});}
      });
    }}};
    w.fetch=()=>assert.fail('account UI used HTTP');
  }});
  t.after(()=>dom.window.close());await settle();
  return {dom,calls,$:id=>dom.window.document.getElementById(id),tick:()=>timers.forEach(fn=>fn()),deliver:(id,result)=>listener({data:{kind:'native-response',id,result}})};
}
function choose(dom,$,id){assert.ok($('account-select'),'accessible Account dropdown must exist');$('account-select').value=id;$('account-select').dispatchEvent(new dom.window.Event('change',{bubbles:true}));}
function assertSelected($,id,game=gameA){assert.equal($('account-select').value,id);assert.equal($('folder-label').textContent,game);assert.equal($('report-body').innerHTML,report(id,game).HTML);assert.match($('account-source').textContent,/ForeverCoach.lua/);assert.ok($('account-source').textContent.includes(id));}

test('Account control requires an explicit choice for multiple outputs',async t=>{
  const {$,calls}=await setup(t,{reportRefresh:()=>report('')});
  assert.ok($('account-select'),'accessible Account dropdown must exist');
  assert.ok($('account-select').labels.length,'native select has an associated label');
  assert.equal($('account-select').value,'');
  assert.deepEqual([...$('account-select').options].filter(o=>o.value).map(o=>o.value),[idA,idB]);
  assert.equal(calls.filter(c=>c.method==='selectAccount').length,0);
  assert.doesNotMatch($('report-body').textContent,/Only A|Only B/);
});

test('account identity and source are inert literal text; save time is exposed',async t=>{
  const literal='NAME#<img src=x onerror=alert(1)>';
  const {$}=await setup(t,{reportRefresh:()=>({...report(literal),HTML:'<p>Escaped server report</p>',Accounts:[{ID:literal,SVPath:'source'}]})});
  assert.ok($('account-select'),'Account dropdown missing');
  assert.equal($('account-select').value,literal);
  assert.equal($('account-select').querySelector('img'),null);
  assert.equal($('account-source').querySelector('img'),null);
  assert.ok($('account-source').textContent.includes(literal));
  assert.equal($('account-save-time').dateTime,saveTime);
});

for(const oldReply of ['success','error']){
  test(`account transition clears report and rejects delayed Refresh ${oldReply}`,async t=>{
    const old=deferred(), selection=deferred();let n=0;
    const {dom,$,calls,tick}=await setup(t,{reportRefresh:()=>++n===2?old.promise:report(),selectAccount:()=>selection.promise});
    $('refresh').click();await settle();choose(dom,$,idB);await settle();
    assert.equal($('report-body').textContent,'','old account report is cleared before the new read settles');
    for(const id of ['account-select','refresh','check-update','apply-update','browse-folder','use-folder','game-path']) assert.equal($(id).disabled,true,id);
    tick();choose(dom,$,idA);$('browse-folder').dispatchEvent(new dom.window.Event('click'));await settle();
    assert.equal(calls.filter(c=>c.method==='selectAccount').length,1,'account changes are single-flight');
    assert.equal(calls.filter(c=>c.method==='chooseGame').length,0);
    selection.resolve(report(idB));await settle();assertSelected($,idB);
    const status=$('global-status').textContent;
    if(oldReply==='success')old.resolve(report(idA));else old.reject(Error('old failed read'));
    await settle();assertSelected($,idB);assert.equal($('global-status').textContent,status);
    assert.deepEqual(calls.find(c=>c.method==='selectAccount').params,[idB]);
    assert.equal($('refresh').disabled,false);assert.equal($('account-select').disabled,false);
  });
}

test('old Refresh completion cannot unlock an account transition still pending',async t=>{
  const old=deferred(),selection=deferred();let n=0;
  const {dom,$,tick,calls}=await setup(t,{reportRefresh:()=>++n===2?old.promise:report(),selectAccount:()=>selection.promise});
  $('refresh').click();await settle();choose(dom,$,idB);await settle();
  old.resolve(report());await settle();
  assert.equal($('report-body').textContent,'');assert.equal($('refresh').disabled,true);assert.equal($('account-select').disabled,true);
  tick();$('refresh').dispatchEvent(new dom.window.Event('click'));await settle();
  assert.equal(calls.filter(c=>c.method==='reportRefresh').length,2);
  selection.resolve(report(idB));await settle();assertSelected($,idB);
});

test('failed account selection keeps old report cleared and does not claim remembered',async t=>{
  const {dom,$}=await setup(t,{selectAccount:()=>{throw Error('could not remember the account selection: disk full');}});
  choose(dom,$,idB);await settle();
  assert.equal($('report-body').textContent,'');
  assert.match($('global-status').textContent,/could not remember.*disk full/);
  assert.doesNotMatch($('global-status').textContent,/selection remembered/i);
  assert.equal($('account-select').value,idA,'failed write did not commit a new identity');
  assert.equal($('account-select').disabled,false);
});

test('missing remembered account stays selected and stale provenance remains visible',async t=>{
  const {$}=await setup(t,{reportRefresh:()=>({...report(),Accounts:[choices[1]],Stale:true,ConfigWarning:'Could not remember selection'})});
  assert.ok($('account-select'),'Account dropdown missing');
  assert.equal($('account-select').value,idA);
  assert.match($('account-select').selectedOptions[0].textContent,/unavailable/i);
  assert.match($('account-source').textContent,/last good|stale/i);
  assert.equal($('account-save-time').dateTime,saveTime);
  assert.match($('account-status').textContent,/Could not remember selection/);
});

test('folder transitions block account calls and restore folder-specific identities',async t=>{
  const folder=deferred();
  const {dom,$,calls}=await setup(t,{setGame:()=>folder.promise});
  $('game-path').value=gameB;$('game-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await settle();
  assert.ok($('account-select'),'Account dropdown missing');assert.equal($('account-select').disabled,true);
  choose(dom,$,idB);await settle();assert.equal(calls.filter(c=>c.method==='selectAccount').length,0);
  folder.resolve(report(idB,gameB));await settle();assertSelected($,idB,gameB);
});

test('late duplicate account reply cannot replace a newer account or folder',async t=>{
  const {dom,$,calls,deliver}=await setup(t,{selectAccount:id=>report(id),setGame:game=>report(idA,game)});
  choose(dom,$,idB);await settle();assertSelected($,idB);
  const old=calls.find(c=>c.method==='selectAccount');
  choose(dom,$,idA);await settle();assertSelected($,idA);
  $('game-path').value=gameB;$('game-form').dispatchEvent(new dom.window.Event('submit',{bubbles:true,cancelable:true}));await settle();
  deliver(old.id,report(idB));await settle();assertSelected($,idA,gameB);
});

test('account selection leaves installation-scoped updater offer intact',async t=>{
  const {dom,$,calls}=await setup(t,{selectAccount:id=>report(id),checkAddon:()=>({Version:'1.4.0',Available:true,Notes:'checked',InstalledVersion:'1.3.1'})});
  $('check-update').click();await settle();assert.equal($('apply-update').disabled,false);
  choose(dom,$,idB);await settle();
  assert.equal($('apply-update').disabled,false);assert.equal($('offered-version').textContent,'1.4.0');
  assert.equal(calls.filter(c=>c.method==='applyAddon').length,0,'account changes never apply an update');
});
