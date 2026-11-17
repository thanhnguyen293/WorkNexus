import { test } from 'node:test';
import assert from 'node:assert/strict';
import { messageText } from '../src/tbchat.js';

const m = (type, content) => ({ type, content: JSON.stringify(content) });

test('renders TBChat message types as text', () => {
  assert.equal(messageText(m(1, { text: 'hi' })), 'hi');
  assert.equal(messageText(m(5, { fileName: 'a.zip', fileSize: 3 })), '[file] a.zip (3 bytes)');
  assert.equal(messageText(m(6, { imageInfoArray: [{ fileName: 'x.png' }] })), '[image] x.png');
  assert.match(messageText(m(12, { text: 'yes', nick: 'Bob', quoteContent: 'ok?' })), /^yes\n> \(reply to Bob: ok\?\)$/);
  assert.equal(messageText(m(16, { msgId: '1' })), '[message recalled]');
  assert.equal(messageText(m(99, {})), '[type99]');
  assert.equal(messageText({ type: 1, content: 'not json' }), 'not json');
});

test('decodes base64 member names in group events', () => {
  assert.equal(messageText(m(13, { groupOperationTypes: 'ADD', operationMember: { nickName: 'THVuYSBOZ3V5ZW4=' } })), '[group event] ADD Luna Nguyen');
  assert.equal(messageText(m(13, { groupOperationTypes: 'ADD', operationMember: { nickName: 'Bob' } })), '[group event] ADD Bob');
});
